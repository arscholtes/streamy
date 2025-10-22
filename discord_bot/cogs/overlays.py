"""
Overlay Control Commands Cog
Trigger OBS overlays and alerts from Discord
"""
import discord
from discord.ext import commands
import logging
from typing import Optional
from utils.api_client import RailsAPIClient
from utils.helpers import (
    create_embed, create_error_embed, create_success_embed,
    create_info_embed
)

logger = logging.getLogger(__name__)


class OverlayControl(commands.Cog):
    """
    OBS Overlay Control Commands

    Trigger overlay alerts and events from Discord:
    - Custom alerts with emoji and messages
    - Event notifications (donations, follows, subs)
    - Data refresh triggers
    """

    def __init__(self, bot: commands.Bot):
        self.bot = bot

    @commands.group(name='overlay', invoke_without_command=True)
    async def overlay(self, ctx: commands.Context):
        """Overlay control commands. Use !overlay help for more info"""
        await ctx.send_help(ctx.command)

    @overlay.command(name='alert')
    async def trigger_alert(
        self,
        ctx: commands.Context,
        emoji: str,
        title: str,
        *,
        message: str = ""
    ):
        """
        Trigger a custom alert on stream overlays
        Usage: !overlay alert <emoji> <title> [message]
        Example: !overlay alert 🎉 "Achievement Unlocked!" First 100 followers!
        """
        async with RailsAPIClient() as api:
            # Get user data
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed(
                    "Not Linked",
                    "Your Discord account is not linked to StreamHub.\n"
                    "Use the web app to link your accounts."
                ))
                return

            user_id = user_data['user']['id']

            # Split message into main message and submessage if it's long
            parts = message.split('\n', 1) if message else [""]
            main_message = parts[0]
            submessage = parts[1] if len(parts) > 1 else ""

            try:
                # Trigger the alert via API
                response = await api._request('POST', f'/api/v1/users/{user_id}/overlays/trigger_alert', {
                    'emoji': emoji,
                    'title': title,
                    'message': main_message,
                    'submessage': submessage,
                    'duration': 6000  # 6 seconds
                })

                if response.get('success'):
                    embed = create_success_embed(
                        "✨ Alert Triggered!",
                        f"**{emoji} {title}**\n\n"
                        f"{main_message}\n"
                        f"{'*' + submessage + '*' if submessage else ''}\n\n"
                        f"The alert will display on your OBS overlays!"
                    )
                    await ctx.send(embed=embed)
                else:
                    await ctx.send(embed=create_error_embed(
                        "Alert Failed",
                        "Failed to trigger alert. Check logs for details."
                    ))

            except Exception as e:
                logger.error(f"Error triggering alert: {e}", exc_info=e)
                await ctx.send(embed=create_error_embed(
                    "Error",
                    f"An error occurred: {e}"
                ))

    @overlay.command(name='donation')
    async def trigger_donation(
        self,
        ctx: commands.Context,
        username: str,
        amount: float,
        *,
        message: str = ""
    ):
        """
        Trigger a donation event alert
        Usage: !overlay donation <username> <amount> [message]
        Example: !overlay donation JohnDoe 25.50 Thanks for the stream!
        """
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed(
                    "Not Linked",
                    "Your Discord account is not linked."
                ))
                return

            user_id = user_data['user']['id']

            try:
                response = await api._request('POST', f'/api/v1/users/{user_id}/overlays/trigger_event', {
                    'event_type': 'donation',
                    'username': username,
                    'amount': amount,
                    'message': message
                })

                if response.get('success'):
                    embed = create_success_embed(
                        "💰 Donation Alert Triggered!",
                        f"**${amount:.2f} from {username}**\n\n"
                        f"{('*' + message + '*') if message else 'No message'}\n\n"
                        f"The donation alert will appear on your stream!"
                    )
                    await ctx.send(embed=embed)
                else:
                    await ctx.send(embed=create_error_embed(
                        "Failed",
                        "Failed to trigger donation event."
                    ))

            except Exception as e:
                logger.error(f"Error triggering donation: {e}")
                await ctx.send(embed=create_error_embed("Error", str(e)))

    @overlay.command(name='follow')
    async def trigger_follow(self, ctx: commands.Context, username: str):
        """
        Trigger a new follower alert
        Usage: !overlay follow <username>
        Example: !overlay follow JaneDoe
        """
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed(
                    "Not Linked",
                    "Your Discord account is not linked."
                ))
                return

            user_id = user_data['user']['id']

            try:
                response = await api._request('POST', f'/api/v1/users/{user_id}/overlays/trigger_event', {
                    'event_type': 'follow',
                    'username': username
                })

                if response.get('success'):
                    embed = create_success_embed(
                        "💜 New Follower Alert!",
                        f"**{username}** just followed!\n\n"
                        f"The follow alert will appear on your stream!"
                    )
                    await ctx.send(embed=embed)
                else:
                    await ctx.send(embed=create_error_embed(
                        "Failed",
                        "Failed to trigger follow event."
                    ))

            except Exception as e:
                logger.error(f"Error triggering follow: {e}")
                await ctx.send(embed=create_error_embed("Error", str(e)))

    @overlay.command(name='subscriber')
    async def trigger_subscriber(self, ctx: commands.Context, username: str):
        """
        Trigger a new subscriber alert
        Usage: !overlay subscriber <username>
        Example: !overlay subscriber ProGamer123
        """
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed(
                    "Not Linked",
                    "Your Discord account is not linked."
                ))
                return

            user_id = user_data['user']['id']

            try:
                response = await api._request('POST', f'/api/v1/users/{user_id}/overlays/trigger_event', {
                    'event_type': 'subscriber',
                    'username': username
                })

                if response.get('success'):
                    embed = create_success_embed(
                        "⭐ New Subscriber!",
                        f"**{username}** just subscribed!\n\n"
                        f"The subscriber alert will appear on your stream!"
                    )
                    await ctx.send(embed=embed)
                else:
                    await ctx.send(embed=create_error_embed(
                        "Failed",
                        "Failed to trigger subscriber event."
                    ))

            except Exception as e:
                logger.error(f"Error triggering subscriber: {e}")
                await ctx.send(embed=create_error_embed("Error", str(e)))

    @overlay.command(name='refresh')
    async def refresh_overlay(
        self,
        ctx: commands.Context,
        overlay_type: Optional[str] = None
    ):
        """
        Manually refresh overlay data
        Usage: !overlay refresh [overlay_type]
        Types: gaming_stats, stream_info, social_stats, now_playing

        Example: !overlay refresh gaming_stats
        """
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed(
                    "Not Linked",
                    "Your Discord account is not linked."
                ))
                return

            user_id = user_data['user']['id']

            valid_types = ['gaming_stats', 'stream_info', 'social_stats', 'now_playing', 'recent_events', 'custom_alert']

            if overlay_type and overlay_type not in valid_types:
                await ctx.send(embed=create_error_embed(
                    "Invalid Type",
                    f"Valid overlay types: {', '.join(valid_types)}"
                ))
                return

            try:
                response = await api._request('POST', f'/api/v1/users/{user_id}/overlays/update_data', {
                    'overlay_type': overlay_type
                })

                if response.get('success'):
                    type_msg = f" ({overlay_type})" if overlay_type else " (all overlays)"
                    embed = create_success_embed(
                        "🔄 Overlay Refreshed",
                        f"Overlay data refreshed{type_msg}!"
                    )
                    await ctx.send(embed=embed)
                else:
                    await ctx.send(embed=create_error_embed(
                        "Failed",
                        "Failed to refresh overlay data."
                    ))

            except Exception as e:
                logger.error(f"Error refreshing overlay: {e}")
                await ctx.send(embed=create_error_embed("Error", str(e)))

    @overlay.command(name='clear')
    async def clear_overlays(self, ctx: commands.Context, clear_type: str):
        """
        Clear overlay events or alerts
        Usage: !overlay clear <events|alerts>
        Example: !overlay clear events
        """
        if clear_type not in ['events', 'alerts']:
            await ctx.send(embed=create_error_embed(
                "Invalid Type",
                "Use 'events' or 'alerts'"
            ))
            return

        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed(
                    "Not Linked",
                    "Your Discord account is not linked."
                ))
                return

            user_id = user_data['user']['id']

            try:
                endpoint = f'/api/v1/users/{user_id}/overlays/clear_{clear_type}'
                response = await api._request('DELETE', endpoint)

                if response.get('success'):
                    embed = create_success_embed(
                        "🗑️ Cleared",
                        f"All {clear_type} have been cleared from overlays."
                    )
                    await ctx.send(embed=embed)
                else:
                    await ctx.send(embed=create_error_embed(
                        "Failed",
                        f"Failed to clear {clear_type}."
                    ))

            except Exception as e:
                logger.error(f"Error clearing {clear_type}: {e}")
                await ctx.send(embed=create_error_embed("Error", str(e)))

    @overlay.command(name='test')
    async def test_overlay(self, ctx: commands.Context):
        """
        Send a test alert to verify overlays are working
        Usage: !overlay test
        """
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed(
                    "Not Linked",
                    "Your Discord account is not linked."
                ))
                return

            user_id = user_data['user']['id']

            try:
                # Send a test alert
                response = await api._request('POST', f'/api/v1/users/{user_id}/overlays/trigger_alert', {
                    'emoji': '🧪',
                    'title': 'Test Alert',
                    'message': 'Overlays are working!',
                    'submessage': 'Triggered from Discord',
                    'duration': 5000
                })

                if response.get('success'):
                    embed = create_success_embed(
                        "🧪 Test Alert Sent!",
                        "Check your OBS overlays to see the test alert.\n\n"
                        "If you don't see it:\n"
                        "• Verify overlay URLs are correct\n"
                        "• Check browser source is visible in OBS\n"
                        "• Refresh the browser source"
                    )
                    await ctx.send(embed=embed)
                else:
                    await ctx.send(embed=create_error_embed(
                        "Failed",
                        "Failed to send test alert."
                    ))

            except Exception as e:
                logger.error(f"Error sending test alert: {e}")
                await ctx.send(embed=create_error_embed("Error", str(e)))


async def setup(bot: commands.Bot):
    """Setup function for cog"""
    await bot.add_cog(OverlayControl(bot))
