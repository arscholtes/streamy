"""
OBS Remote Control Commands Cog
Advanced remote control of OBS Studio from Discord
"""
import discord
from discord.ext import commands, tasks
import logging
from typing import Optional, List, Dict, Any
from datetime import datetime, timedelta
from utils.obs_client import obs_pool, OBSConnectionError, OBSAuthenticationError
from utils.api_client import RailsAPIClient
from utils.helpers import (
    create_embed, create_error_embed, create_success_embed,
    create_info_embed, format_duration
)
from utils.redis_client import redis_client

logger = logging.getLogger(__name__)


class OBSControl(commands.Cog):
    """
    OBS Studio Remote Control

    Control your OBS Studio instance directly from Discord:
    - Connect/disconnect to OBS
    - Switch scenes
    - Control sources (show/hide, filters)
    - Start/stop streaming and recording
    - View stats and status
    - Test alerts and overlays
    """

    def __init__(self, bot: commands.Bot):
        self.bot = bot
        # Background task to monitor connections
        self.monitor_connections.start()

    def cog_unload(self):
        """Cleanup when cog is unloaded"""
        self.monitor_connections.cancel()

    # ============= CONNECTION MANAGEMENT =============

    @commands.group(name='obs', invoke_without_command=True)
    async def obs(self, ctx: commands.Context):
        """OBS remote control commands. Use !obs help for more info"""
        await ctx.send_help(ctx.command)

    @obs.command(name='connect')
    async def obs_connect(self, ctx: commands.Context, host: str = "localhost", port: int = 4455, password: str = None):
        """
        Connect to your OBS Studio instance
        Usage: !obs connect [host] [port] [password]
        Example: !obs connect localhost 4455 mypassword

        Default: localhost:4455 (no password)
        """
        # Check if already connected
        existing_conn = await self._get_user_connection(ctx.author.id, check_alive=True)
        if existing_conn:
            embed = create_info_embed(
                "Already Connected",
                f"You're already connected to OBS at {existing_conn.host}:{existing_conn.port}\n"
                f"Use `!obs disconnect` to disconnect first."
            )
            await ctx.send(embed=embed)
            return

        # Try to connect
        try:
            loading = await ctx.send(embed=create_info_embed(
                "Connecting to OBS...",
                f"Attempting connection to {host}:{port}"
            ))

            client = await obs_pool.get_connection(
                user_id=str(ctx.author.id),
                host=host,
                port=port,
                password=password
            )

            # Get OBS version info
            version_info = await client.request("GetVersion")

            # Store connection details in Rails API
            async with RailsAPIClient() as api:
                user_data = await api.get_user_by_discord_id(str(ctx.author.id))
                if user_data:
                    # Store OBS connection details
                    await api._request('POST', f'/api/v1/users/{user_data["user"]["id"]}/obs_connection', {
                        'host': host,
                        'port': port,
                        'version': version_info.get('obsVersion'),
                        'connected': True
                    })

            embed = create_success_embed(
                "🎬 Connected to OBS!",
                f"Successfully connected to OBS Studio\n\n"
                f"**Host:** {host}:{port}\n"
                f"**OBS Version:** {version_info.get('obsVersion', 'Unknown')}\n"
                f"**WebSocket Version:** {version_info.get('obsWebSocketVersion', 'Unknown')}\n\n"
                f"Use `!obs help` to see available commands!"
            )

            await loading.edit(embed=embed)

        except OBSAuthenticationError as e:
            embed = create_error_embed(
                "Authentication Failed",
                f"Failed to authenticate with OBS.\n"
                f"Make sure your password is correct.\n\n"
                f"Error: {e}"
            )
            await ctx.send(embed=embed)
        except OBSConnectionError as e:
            embed = create_error_embed(
                "Connection Failed",
                f"Could not connect to OBS at {host}:{port}\n\n"
                f"Make sure:\n"
                f"• OBS Studio is running\n"
                f"• WebSocket server is enabled (Tools → WebSocket Server Settings)\n"
                f"• Host and port are correct\n"
                f"• Firewall allows connection\n\n"
                f"Error: {e}"
            )
            await ctx.send(embed=embed)
        except Exception as e:
            logger.error(f"OBS connection error: {e}", exc_info=e)
            embed = create_error_embed(
                "Connection Error",
                f"An unexpected error occurred: {e}"
            )
            await ctx.send(embed=embed)

    @obs.command(name='disconnect')
    async def obs_disconnect(self, ctx: commands.Context):
        """
        Disconnect from OBS
        Usage: !obs disconnect
        """
        client = await self._get_user_connection(ctx.author.id)
        if not client:
            await ctx.send(embed=create_error_embed("Not Connected", "You're not connected to OBS."))
            return

        await obs_pool.remove_connection(str(ctx.author.id), client.host, client.port)

        # Update Rails API
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))
            if user_data:
                await api._request('PATCH', f'/api/v1/users/{user_data["user"]["id"]}/obs_connection', {
                    'connected': False
                })

        embed = create_success_embed(
            "Disconnected",
            "Successfully disconnected from OBS"
        )
        await ctx.send(embed=embed)

    @obs.command(name='status')
    async def obs_status(self, ctx: commands.Context):
        """
        Check OBS connection and status
        Usage: !obs status
        """
        client = await self._get_user_connection(ctx.author.id)
        if not client:
            embed = create_error_embed(
                "Not Connected",
                "You're not connected to OBS.\nUse `!obs connect` to connect."
            )
            await ctx.send(embed=embed)
            return

        try:
            # Get stats
            stats = await client.request("GetStats")
            stream_status = await client.request("GetStreamStatus")
            record_status = await client.request("GetRecordStatus")

            # Build status embed
            embed = create_embed(
                "🎬 OBS Status",
                f"Connected to {client.host}:{client.port}",
                color=discord.Color.green()
            )

            # Streaming status
            streaming = stream_status.get('outputActive', False)
            stream_emoji = "🔴" if streaming else "⚫"
            stream_text = "LIVE" if streaming else "Offline"
            if streaming:
                duration = stream_status.get('outputDuration', 0) / 1000  # Convert to seconds
                stream_text += f" • {format_duration(int(duration))}"

            embed.add_field(
                name=f'{stream_emoji} Stream',
                value=stream_text,
                inline=True
            )

            # Recording status
            recording = record_status.get('outputActive', False)
            record_emoji = "🔴" if recording else "⚫"
            record_text = "Recording" if recording else "Not Recording"
            if recording:
                duration = record_status.get('outputDuration', 0) / 1000
                record_text += f" • {format_duration(int(duration))}"

            embed.add_field(
                name=f'{record_emoji} Recording',
                value=record_text,
                inline=True
            )

            # Performance stats
            embed.add_field(
                name='⚡ Performance',
                value=f"FPS: {stats.get('activeFps', 0):.1f}\n"
                      f"CPU: {stats.get('cpuUsage', 0):.1f}%\n"
                      f"Memory: {stats.get('memoryUsage', 0):.1f} MB",
                inline=True
            )

            # Stream stats if streaming
            if streaming:
                embed.add_field(
                    name='📊 Stream Stats',
                    value=f"Bitrate: {stream_status.get('outputKbps', 0)} kbps\n"
                          f"Dropped Frames: {stream_status.get('outputSkippedFrames', 0)}\n"
                          f"Total Frames: {stream_status.get('outputTotalFrames', 0)}",
                    inline=True
                )

            await ctx.send(embed=embed)

        except Exception as e:
            logger.error(f"Error getting OBS status: {e}")
            await ctx.send(embed=create_error_embed(
                "Status Error",
                f"Failed to get OBS status: {e}"
            ))

    # ============= SCENE MANAGEMENT =============

    @obs.command(name='scenes')
    async def list_scenes(self, ctx: commands.Context):
        """
        List all scenes in OBS
        Usage: !obs scenes
        """
        client = await self._get_user_connection(ctx.author.id)
        if not client:
            await ctx.send(embed=create_error_embed("Not Connected", "Use `!obs connect` first."))
            return

        try:
            # Get scene list
            scenes_data = await client.request("GetSceneList")
            current_scene = scenes_data.get('currentProgramSceneName')
            scenes = scenes_data.get('scenes', [])

            if not scenes:
                await ctx.send(embed=create_info_embed("No Scenes", "No scenes found in OBS."))
                return

            # Build scenes list
            description = ""
            for scene in scenes:
                scene_name = scene.get('sceneName')
                is_current = scene_name == current_scene
                emoji = "▶️" if is_current else "⬜"
                description += f"{emoji} **{scene_name}**" + (" (Current)" if is_current else "") + "\n"

            embed = create_embed(
                "🎬 OBS Scenes",
                description,
                color=discord.Color.blue()
            )

            embed.set_footer(text=f"Total: {len(scenes)} scenes • Use !obs scene <name> to switch")

            await ctx.send(embed=embed)

        except Exception as e:
            logger.error(f"Error listing scenes: {e}")
            await ctx.send(embed=create_error_embed("Error", f"Failed to list scenes: {e}"))

    @obs.command(name='scene')
    async def switch_scene(self, ctx: commands.Context, *, scene_name: str):
        """
        Switch to a different scene
        Usage: !obs scene <scene name>
        Example: !obs scene Main Camera
        """
        client = await self._get_user_connection(ctx.author.id)
        if not client:
            await ctx.send(embed=create_error_embed("Not Connected", "Use `!obs connect` first."))
            return

        try:
            # Switch scene
            await client.request("SetCurrentProgramScene", {
                'sceneName': scene_name
            })

            embed = create_success_embed(
                "Scene Switched",
                f"Successfully switched to scene: **{scene_name}**"
            )
            await ctx.send(embed=embed)

        except Exception as e:
            logger.error(f"Error switching scene: {e}")
            await ctx.send(embed=create_error_embed(
                "Scene Switch Failed",
                f"Failed to switch to '{scene_name}'\n\n"
                f"Make sure the scene exists. Use `!obs scenes` to see all scenes.\n\n"
                f"Error: {e}"
            ))

    @obs.command(name='preview')
    async def set_preview_scene(self, ctx: commands.Context, *, scene_name: str):
        """
        Set preview scene (Studio Mode only)
        Usage: !obs preview <scene name>
        """
        client = await self._get_user_connection(ctx.author.id)
        if not client:
            await ctx.send(embed=create_error_embed("Not Connected", "Use `!obs connect` first."))
            return

        try:
            # Check if studio mode is enabled
            studio_mode = await client.request("GetStudioModeEnabled")
            if not studio_mode.get('studioModeEnabled'):
                await ctx.send(embed=create_error_embed(
                    "Studio Mode Disabled",
                    "Studio Mode must be enabled to use preview.\n"
                    "Enable it in OBS: View → Studio Mode"
                ))
                return

            # Set preview scene
            await client.request("SetCurrentPreviewScene", {
                'sceneName': scene_name
            })

            embed = create_success_embed(
                "Preview Set",
                f"Preview scene set to: **{scene_name}**\n\n"
                f"Use `!obs transition` to transition to this scene."
            )
            await ctx.send(embed=embed)

        except Exception as e:
            logger.error(f"Error setting preview: {e}")
            await ctx.send(embed=create_error_embed("Error", f"Failed to set preview: {e}"))

    @obs.command(name='transition')
    async def trigger_transition(self, ctx: commands.Context):
        """
        Trigger studio mode transition
        Usage: !obs transition
        """
        client = await self._get_user_connection(ctx.author.id)
        if not client:
            await ctx.send(embed=create_error_embed("Not Connected", "Use `!obs connect` first."))
            return

        try:
            await client.request("TriggerStudioModeTransition")

            embed = create_success_embed(
                "Transition Triggered",
                "Successfully transitioned to preview scene"
            )
            await ctx.send(embed=embed)

        except Exception as e:
            await ctx.send(embed=create_error_embed("Error", f"Failed to transition: {e}"))

    # ============= SOURCE CONTROL =============

    @obs.command(name='sources')
    async def list_sources(self, ctx: commands.Context, scene_name: str = None):
        """
        List sources in a scene
        Usage: !obs sources [scene name]
        If no scene specified, uses current scene
        """
        client = await self._get_user_connection(ctx.author.id)
        if not client:
            await ctx.send(embed=create_error_embed("Not Connected", "Use `!obs connect` first."))
            return

        try:
            # Get current scene if not specified
            if not scene_name:
                scenes_data = await client.request("GetSceneList")
                scene_name = scenes_data.get('currentProgramSceneName')

            # Get scene items
            items_data = await client.request("GetSceneItemList", {
                'sceneName': scene_name
            })

            items = items_data.get('sceneItems', [])

            if not items:
                await ctx.send(embed=create_info_embed(
                    "No Sources",
                    f"No sources found in scene: {scene_name}"
                ))
                return

            # Build sources list
            description = f"**Scene:** {scene_name}\n\n"
            for item in items:
                source_name = item.get('sourceName')
                enabled = item.get('sceneItemEnabled', True)
                emoji = "✅" if enabled else "❌"
                description += f"{emoji} {source_name}\n"

            embed = create_embed(
                "🎥 Scene Sources",
                description,
                color=discord.Color.blue()
            )

            embed.set_footer(text=f"Total: {len(items)} sources")

            await ctx.send(embed=embed)

        except Exception as e:
            logger.error(f"Error listing sources: {e}")
            await ctx.send(embed=create_error_embed("Error", f"Failed to list sources: {e}"))

    @obs.command(name='show')
    async def show_source(self, ctx: commands.Context, *, source_name: str):
        """
        Show (enable) a source
        Usage: !obs show <source name>
        """
        await self._toggle_source(ctx, source_name, True)

    @obs.command(name='hide')
    async def hide_source(self, ctx: commands.Context, *, source_name: str):
        """
        Hide (disable) a source
        Usage: !obs hide <source name>
        """
        await self._toggle_source(ctx, source_name, False)

    async def _toggle_source(self, ctx: commands.Context, source_name: str, enabled: bool):
        """Helper to show/hide sources"""
        client = await self._get_user_connection(ctx.author.id)
        if not client:
            await ctx.send(embed=create_error_embed("Not Connected", "Use `!obs connect` first."))
            return

        try:
            # Get current scene
            scenes_data = await client.request("GetSceneList")
            current_scene = scenes_data.get('currentProgramSceneName')

            # Find source in scene
            items_data = await client.request("GetSceneItemList", {
                'sceneName': current_scene
            })

            item_id = None
            for item in items_data.get('sceneItems', []):
                if item.get('sourceName') == source_name:
                    item_id = item.get('sceneItemId')
                    break

            if item_id is None:
                await ctx.send(embed=create_error_embed(
                    "Source Not Found",
                    f"Source '{source_name}' not found in current scene.\n"
                    f"Use `!obs sources` to see available sources."
                ))
                return

            # Toggle source
            await client.request("SetSceneItemEnabled", {
                'sceneName': current_scene,
                'sceneItemId': item_id,
                'sceneItemEnabled': enabled
            })

            action = "shown" if enabled else "hidden"
            embed = create_success_embed(
                f"Source {action.capitalize()}",
                f"Successfully {action} source: **{source_name}**"
            )
            await ctx.send(embed=embed)

        except Exception as e:
            logger.error(f"Error toggling source: {e}")
            await ctx.send(embed=create_error_embed("Error", f"Failed to toggle source: {e}"))

    # ============= STREAM CONTROL =============

    @obs.command(name='startstream')
    async def start_streaming(self, ctx: commands.Context):
        """
        Start streaming
        Usage: !obs startstream
        """
        client = await self._get_user_connection(ctx.author.id)
        if not client:
            await ctx.send(embed=create_error_embed("Not Connected", "Use `!obs connect` first."))
            return

        try:
            # Check if already streaming
            status = await client.request("GetStreamStatus")
            if status.get('outputActive'):
                await ctx.send(embed=create_info_embed(
                    "Already Streaming",
                    "OBS is already streaming!"
                ))
                return

            # Start streaming
            await client.request("StartStream")

            embed = create_success_embed(
                "🔴 Stream Started!",
                "Successfully started streaming!"
            )
            await ctx.send(embed=embed)

        except Exception as e:
            logger.error(f"Error starting stream: {e}")
            await ctx.send(embed=create_error_embed("Error", f"Failed to start stream: {e}"))

    @obs.command(name='stopstream')
    async def stop_streaming(self, ctx: commands.Context):
        """
        Stop streaming
        Usage: !obs stopstream
        """
        client = await self._get_user_connection(ctx.author.id)
        if not client:
            await ctx.send(embed=create_error_embed("Not Connected", "Use `!obs connect` first."))
            return

        try:
            # Check if streaming
            status = await client.request("GetStreamStatus")
            if not status.get('outputActive'):
                await ctx.send(embed=create_info_embed(
                    "Not Streaming",
                    "OBS is not currently streaming."
                ))
                return

            # Stop streaming
            await client.request("StopStream")

            embed = create_success_embed(
                "⚫ Stream Stopped",
                "Successfully stopped streaming."
            )
            await ctx.send(embed=embed)

        except Exception as e:
            logger.error(f"Error stopping stream: {e}")
            await ctx.send(embed=create_error_embed("Error", f"Failed to stop stream: {e}"))

    @obs.command(name='startrecord')
    async def start_recording(self, ctx: commands.Context):
        """
        Start recording
        Usage: !obs startrecord
        """
        client = await self._get_user_connection(ctx.author.id)
        if not client:
            await ctx.send(embed=create_error_embed("Not Connected", "Use `!obs connect` first."))
            return

        try:
            await client.request("StartRecord")

            embed = create_success_embed(
                "🔴 Recording Started",
                "Successfully started recording!"
            )
            await ctx.send(embed=embed)

        except Exception as e:
            await ctx.send(embed=create_error_embed("Error", f"Failed to start recording: {e}"))

    @obs.command(name='stoprecord')
    async def stop_recording(self, ctx: commands.Context):
        """
        Stop recording
        Usage: !obs stoprecord
        """
        client = await self._get_user_connection(ctx.author.id)
        if not client:
            await ctx.send(embed=create_error_embed("Not Connected", "Use `!obs connect` first."))
            return

        try:
            result = await client.request("StopRecord")
            output_path = result.get('outputPath', 'Unknown')

            embed = create_success_embed(
                "⚫ Recording Stopped",
                f"Recording saved to:\n`{output_path}`"
            )
            await ctx.send(embed=embed)

        except Exception as e:
            await ctx.send(embed=create_error_embed("Error", f"Failed to stop recording: {e}"))

    # ============= TEXT AND BROWSER SOURCE CONTROL =============

    @obs.command(name='settext')
    async def set_text(self, ctx: commands.Context, source_name: str, *, text: str):
        """
        Update text in a text source
        Usage: !obs settext <source name> <text>
        Example: !obs settext "Follower Goal" Now at 500 followers!
        """
        client = await self._get_user_connection(ctx.author.id)
        if not client:
            await ctx.send(embed=create_error_embed("Not Connected", "Use `!obs connect` first."))
            return

        try:
            await client.request("SetInputSettings", {
                'inputName': source_name,
                'inputSettings': {
                    'text': text
                }
            })

            embed = create_success_embed(
                "Text Updated",
                f"Updated text in **{source_name}**:\n```{text[:100]}{'...' if len(text) > 100 else ''}```"
            )
            await ctx.send(embed=embed)

        except Exception as e:
            logger.error(f"Error setting text: {e}")
            await ctx.send(embed=create_error_embed("Error", f"Failed to set text: {e}"))

    @obs.command(name='refreshbrowser')
    async def refresh_browser_source(self, ctx: commands.Context, *, source_name: str):
        """
        Refresh a browser source (useful for alert testing)
        Usage: !obs refreshbrowser <source name>
        Example: !obs refreshbrowser Alerts
        """
        client = await self._get_user_connection(ctx.author.id)
        if not client:
            await ctx.send(embed=create_error_embed("Not Connected", "Use `!obs connect` first."))
            return

        try:
            await client.request("PressInputPropertiesButton", {
                'inputName': source_name,
                'propertyName': 'refreshnocache'
            })

            embed = create_success_embed(
                "Browser Source Refreshed",
                f"Refreshed browser source: **{source_name}**"
            )
            await ctx.send(embed=embed)

        except Exception as e:
            logger.error(f"Error refreshing browser source: {e}")
            await ctx.send(embed=create_error_embed("Error", f"Failed to refresh: {e}"))

    # ============= FILTERS =============

    @obs.command(name='filters')
    async def list_filters(self, ctx: commands.Context, *, source_name: str):
        """
        List filters on a source
        Usage: !obs filters <source name>
        """
        client = await self._get_user_connection(ctx.author.id)
        if not client:
            await ctx.send(embed=create_error_embed("Not Connected", "Use `!obs connect` first."))
            return

        try:
            filters_data = await client.request("GetSourceFilterList", {
                'sourceName': source_name
            })

            filters = filters_data.get('filters', [])

            if not filters:
                await ctx.send(embed=create_info_embed(
                    "No Filters",
                    f"No filters found on source: {source_name}"
                ))
                return

            description = f"**Source:** {source_name}\n\n"
            for f in filters:
                filter_name = f.get('filterName')
                enabled = f.get('filterEnabled', True)
                filter_kind = f.get('filterKind', 'Unknown')
                emoji = "✅" if enabled else "❌"
                description += f"{emoji} {filter_name} ({filter_kind})\n"

            embed = create_embed(
                "🎨 Source Filters",
                description,
                color=discord.Color.blue()
            )

            await ctx.send(embed=embed)

        except Exception as e:
            await ctx.send(embed=create_error_embed("Error", f"Failed to list filters: {e}"))

    @obs.command(name='togglefilter')
    async def toggle_filter(self, ctx: commands.Context, source_name: str, *, filter_name: str):
        """
        Toggle a filter on/off
        Usage: !obs togglefilter <source name> <filter name>
        Example: !obs togglefilter Webcam "Color Correction"
        """
        client = await self._get_user_connection(ctx.author.id)
        if not client:
            await ctx.send(embed=create_error_embed("Not Connected", "Use `!obs connect` first."))
            return

        try:
            # Get current state
            filter_data = await client.request("GetSourceFilter", {
                'sourceName': source_name,
                'filterName': filter_name
            })

            current_state = filter_data.get('filterEnabled', True)
            new_state = not current_state

            # Toggle filter
            await client.request("SetSourceFilterEnabled", {
                'sourceName': source_name,
                'filterName': filter_name,
                'filterEnabled': new_state
            })

            state_text = "enabled" if new_state else "disabled"
            embed = create_success_embed(
                f"Filter {state_text.capitalize()}",
                f"**{filter_name}** on **{source_name}** is now {state_text}"
            )
            await ctx.send(embed=embed)

        except Exception as e:
            await ctx.send(embed=create_error_embed("Error", f"Failed to toggle filter: {e}"))

    # ============= ADVANCED FEATURES =============

    @obs.command(name='screenshot')
    async def take_screenshot(self, ctx: commands.Context, *, format: str = "png"):
        """
        Take a screenshot of the current OBS output
        Usage: !obs screenshot [format]
        Format: png, jpg, jpeg (default: png)
        """
        client = await self._get_user_connection(ctx.author.id)
        if not client:
            await ctx.send(embed=create_error_embed("Not Connected", "Use `!obs connect` first."))
            return

        try:
            loading = await ctx.send(embed=create_info_embed("Taking Screenshot...", "Please wait..."))

            # Take screenshot
            result = await client.request("SaveSourceScreenshot", {
                'sourceName': None,  # Current program output
                'imageFormat': format,
                'imageFilePath': None,  # Let OBS choose temp path
                'imageWidth': 1920,
                'imageHeight': 1080
            })

            # OBS returns base64 image data
            image_data = result.get('imageData')

            if image_data:
                embed = create_success_embed(
                    "📸 Screenshot Taken",
                    "Screenshot captured successfully!"
                )
                embed.set_footer(text=f"Format: {format.upper()} • Size: 1920x1080")

                # Note: In production, you'd decode and send the image
                # For now, just confirm success
                await loading.edit(embed=embed)
            else:
                await loading.edit(embed=create_error_embed(
                    "Screenshot Failed",
                    "Failed to capture screenshot data"
                ))

        except Exception as e:
            logger.error(f"Error taking screenshot: {e}")
            await ctx.send(embed=create_error_embed("Error", f"Failed to take screenshot: {e}"))

    @obs.command(name='media')
    async def control_media(self, ctx: commands.Context, action: str, *, source_name: str):
        """
        Control media source playback
        Usage: !obs media <action> <source name>
        Actions: play, pause, restart, stop, next, previous
        Example: !obs media play "Background Music"
        """
        client = await self._get_user_connection(ctx.author.id)
        if not client:
            await ctx.send(embed=create_error_embed("Not Connected", "Use `!obs connect` first."))
            return

        action_map = {
            'play': 'OBS_WEBSOCKET_MEDIA_INPUT_ACTION_PLAY',
            'pause': 'OBS_WEBSOCKET_MEDIA_INPUT_ACTION_PAUSE',
            'restart': 'OBS_WEBSOCKET_MEDIA_INPUT_ACTION_RESTART',
            'stop': 'OBS_WEBSOCKET_MEDIA_INPUT_ACTION_STOP',
            'next': 'OBS_WEBSOCKET_MEDIA_INPUT_ACTION_NEXT',
            'previous': 'OBS_WEBSOCKET_MEDIA_INPUT_ACTION_PREVIOUS'
        }

        if action.lower() not in action_map:
            await ctx.send(embed=create_error_embed(
                "Invalid Action",
                f"Valid actions: {', '.join(action_map.keys())}"
            ))
            return

        try:
            await client.request("TriggerMediaInputAction", {
                'inputName': source_name,
                'mediaAction': action_map[action.lower()]
            })

            embed = create_success_embed(
                "Media Control",
                f"Action **{action}** triggered on **{source_name}**"
            )
            await ctx.send(embed=embed)

        except Exception as e:
            await ctx.send(embed=create_error_embed("Error", f"Failed to control media: {e}"))

    @obs.command(name='hotkey')
    async def trigger_hotkey(self, ctx: commands.Context, *, hotkey_name: str):
        """
        Trigger an OBS hotkey
        Usage: !obs hotkey <hotkey name>
        Example: !obs hotkey OBS_KEY_F13
        Note: Use exact hotkey name from OBS settings
        """
        client = await self._get_user_connection(ctx.author.id)
        if not client:
            await ctx.send(embed=create_error_embed("Not Connected", "Use `!obs connect` first."))
            return

        try:
            await client.request("TriggerHotkeyByName", {
                'hotkeyName': hotkey_name
            })

            embed = create_success_embed(
                "Hotkey Triggered",
                f"Triggered hotkey: **{hotkey_name}**"
            )
            await ctx.send(embed=embed)

        except Exception as e:
            await ctx.send(embed=create_error_embed("Error", f"Failed to trigger hotkey: {e}"))

    @obs.command(name='batch')
    async def batch_commands(self, ctx: commands.Context):
        """
        Execute multiple OBS commands at once for better performance
        Usage: !obs batch
        Then follow the prompts to add commands

        Example use cases:
        - Switch scene and toggle multiple sources
        - Start stream and recording simultaneously
        - Apply multiple filter changes at once
        """
        await ctx.send(embed=create_info_embed(
            "Batch Commands",
            "Batch command feature coming soon!\n\n"
            "This will allow you to:\n"
            "• Queue multiple commands\n"
            "• Execute them simultaneously\n"
            "• Save common batch operations\n"
            "• Create custom macros"
        ))

    # ============= HELPER METHODS =============

    async def _get_user_connection(self, user_id: int, check_alive: bool = False) -> Optional[Any]:
        """Get user's OBS connection if exists"""
        conn_key = f"obs:connection:{user_id}"
        conn_data = redis_client.get(conn_key)

        if not conn_data and check_alive:
            return None

        # Try to get from pool
        for conn in obs_pool.connections.values():
            if str(user_id) in conn:
                client = obs_pool.connections[conn]
                if check_alive and not client.connected:
                    return None
                return client

        return None

    @tasks.loop(minutes=5)
    async def monitor_connections(self):
        """Background task to monitor and cleanup stale connections"""
        logger.debug("Monitoring OBS connections...")
        # This would check for stale connections and clean them up
        # Implementation depends on your specific requirements

    @monitor_connections.before_loop
    async def before_monitor(self):
        await self.bot.wait_until_ready()


async def setup(bot: commands.Bot):
    """Setup function for cog"""
    await bot.add_cog(OBSControl(bot))
