"""
General Commands Cog
Basic bot commands and utilities
"""
import discord
from discord.ext import commands
import logging
from utils.helpers import create_info_embed, create_embed

logger = logging.getLogger(__name__)


class General(commands.Cog):
    """General bot commands"""

    def __init__(self, bot: commands.Bot):
        self.bot = bot

    @commands.command(name='ping')
    async def ping(self, ctx: commands.Context):
        """Check bot latency"""
        latency = round(self.bot.latency * 1000)
        embed = create_info_embed(
            "Pong!",
            f"Bot latency: {latency}ms"
        )
        await ctx.send(embed=embed)

    @commands.command(name='info')
    async def info(self, ctx: commands.Context):
        """Show bot information"""
        embed = create_embed(
            "StreamHub Bot",
            "Advanced Discord bot for StreamHub streaming platform",
            color=discord.Color.purple(),
            fields=[
                {
                    'name': '📊 Servers',
                    'value': str(len(self.bot.guilds)),
                    'inline': True
                },
                {
                    'name': '👥 Users',
                    'value': str(len(self.bot.users)),
                    'inline': True
                },
                {
                    'name': '⚡ Commands',
                    'value': str(len(self.bot.commands)),
                    'inline': True
                },
                {
                    'name': '🎮 Features',
                    'value': (
                        '• Loyalty Points System\n'
                        '• Achievements\n'
                        '• Mini-Games\n'
                        '• VC Queue\n'
                        '• Stream Integration'
                    ),
                    'inline': False
                }
            ],
            footer="Use !help to see all commands"
        )
        await ctx.send(embed=embed)

    @commands.command(name='help')
    async def help_command(self, ctx: commands.Context, *, command: str = None):
        """Show help for commands"""
        if command:
            # Show help for specific command
            cmd = self.bot.get_command(command)
            if not cmd:
                await ctx.send(f"❌ Command `{command}` not found")
                return

            embed = create_embed(
                f"Command: {cmd.name}",
                cmd.help or "No description available",
                color=discord.Color.blue(),
                fields=[
                    {
                        'name': 'Usage',
                        'value': f"`!{cmd.name} {cmd.signature}`",
                        'inline': False
                    }
                ]
            )
            await ctx.send(embed=embed)
        else:
            # Show all commands grouped by cog
            embed = create_embed(
                "StreamHub Bot Commands",
                "Use `!help <command>` for more info on a specific command",
                color=discord.Color.blue()
            )

            for cog_name, cog in self.bot.cogs.items():
                commands_list = [
                    f"`{cmd.name}`" for cmd in cog.get_commands()
                    if not cmd.hidden
                ]
                if commands_list:
                    embed.add_field(
                        name=f"**{cog_name}**",
                        value=" • ".join(commands_list),
                        inline=False
                    )

            await ctx.send(embed=embed)

    @commands.command(name='stats')
    async def stats(self, ctx: commands.Context):
        """Show bot statistics"""
        embed = create_embed(
            "📊 Bot Statistics",
            color=discord.Color.gold(),
            fields=[
                {
                    'name': 'Servers',
                    'value': str(len(self.bot.guilds)),
                    'inline': True
                },
                {
                    'name': 'Users',
                    'value': str(len(self.bot.users)),
                    'inline': True
                },
                {
                    'name': 'Commands',
                    'value': str(len(self.bot.commands)),
                    'inline': True
                },
                {
                    'name': 'Latency',
                    'value': f"{round(self.bot.latency * 1000)}ms",
                    'inline': True
                }
            ]
        )
        await ctx.send(embed=embed)

    @commands.command(name='serverinfo', aliases=['server'])
    async def server_info(self, ctx: commands.Context):
        """Show information about this server"""
        guild = ctx.guild

        # Count channels
        text_channels = len(guild.text_channels)
        voice_channels = len(guild.voice_channels)

        # Count members
        total_members = guild.member_count
        online_members = sum(1 for m in guild.members if m.status != discord.Status.offline)

        # Server features
        features = ', '.join(guild.features) if guild.features else 'None'

        embed = create_embed(
            f"🏰 {guild.name}",
            color=discord.Color.blue(),
            fields=[
                {
                    'name': '👑 Owner',
                    'value': str(guild.owner),
                    'inline': True
                },
                {
                    'name': '📅 Created',
                    'value': guild.created_at.strftime('%Y-%m-%d'),
                    'inline': True
                },
                {
                    'name': '🆔 Server ID',
                    'value': str(guild.id),
                    'inline': True
                },
                {
                    'name': f'👥 Members ({total_members})',
                    'value': f'🟢 {online_members} online',
                    'inline': True
                },
                {
                    'name': f'💬 Channels ({text_channels + voice_channels})',
                    'value': f'📝 {text_channels} text\n🔊 {voice_channels} voice',
                    'inline': True
                },
                {
                    'name': '🎭 Roles',
                    'value': str(len(guild.roles)),
                    'inline': True
                },
                {
                    'name': '😀 Emojis',
                    'value': str(len(guild.emojis)),
                    'inline': True
                },
                {
                    'name': '🚀 Boost Level',
                    'value': f'Level {guild.premium_tier} ({guild.premium_subscription_count} boosts)',
                    'inline': True
                },
                {
                    'name': '📜 Verification',
                    'value': str(guild.verification_level).capitalize(),
                    'inline': True
                }
            ]
        )

        if guild.icon:
            embed.set_thumbnail(url=guild.icon.url)

        await ctx.send(embed=embed)

    @commands.command(name='invite')
    async def invite(self, ctx: commands.Context):
        """Get the bot invite link"""
        embed = create_embed(
            "🤖 Invite StreamHub Bot",
            "Add this bot to your server!",
            color=discord.Color.green(),
            fields=[
                {
                    'name': '🔗 Bot Invite',
                    'value': '[Click here to invite](https://discord.com/oauth2/authorize)',
                    'inline': False
                },
                {
                    'name': '📖 Documentation',
                    'value': 'Visit StreamHub docs for setup guide',
                    'inline': False
                },
                {
                    'name': '💬 Support',
                    'value': 'Join our support server for help',
                    'inline': False
                }
            ]
        )
        await ctx.send(embed=embed)

    @commands.command(name='uptime')
    async def uptime(self, ctx: commands.Context):
        """Show bot uptime"""
        # This would need to track start time - for now show a simple message
        embed = create_info_embed(
            "⏰ Bot Uptime",
            "Uptime tracking will be implemented in Phase 10 (Polish & Testing)"
        )
        await ctx.send(embed=embed)


async def setup(bot: commands.Bot):
    """Setup function for cog"""
    await bot.add_cog(General(bot))
