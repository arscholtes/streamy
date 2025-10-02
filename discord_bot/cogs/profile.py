"""
Profile Commands Cog
User profile and information commands
"""
import discord
from discord.ext import commands
import logging
from utils.api_client import RailsAPIClient
from utils.helpers import create_embed, create_error_embed, create_info_embed, format_points

logger = logging.getLogger(__name__)


class Profile(commands.Cog):
    """User profile commands"""

    def __init__(self, bot: commands.Bot):
        self.bot = bot
        self.api = RailsAPIClient()

    @commands.command(name='profile', aliases=['me', 'userinfo'])
    async def profile(self, ctx: commands.Context, member: discord.Member = None):
        """View your or another user's profile"""
        target = member or ctx.author

        # Get user data from API
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(target.id))

            if not user_data:
                # User not registered
                if target == ctx.author:
                    embed = create_error_embed(
                        "Profile Not Found",
                        "You haven't registered yet! Link your Discord account on StreamHub to get started."
                    )
                else:
                    embed = create_error_embed(
                        "Profile Not Found",
                        f"{target.name} hasn't registered their StreamHub account yet."
                    )
                await ctx.send(embed=embed)
                return

            # Get loyalty points
            loyalty_data = await api.get_loyalty_points(user_data['user']['id'])

            # Build profile embed
            user_info = user_data['user']

            fields = [
                {
                    'name': '🆔 User ID',
                    'value': str(user_info['id']),
                    'inline': True
                },
                {
                    'name': '📧 Email',
                    'value': user_info['email'] if target == ctx.author else '🔒 Hidden',
                    'inline': True
                },
                {
                    'name': '👑 Subscription',
                    'value': user_info['subscription_tier'].upper(),
                    'inline': True
                }
            ]

            if loyalty_data:
                lp = loyalty_data['loyalty_points']
                fields.extend([
                    {
                        'name': '⭐ Level',
                        'value': str(lp['level']),
                        'inline': True
                    },
                    {
                        'name': '💎 Points',
                        'value': format_points(lp['points']),
                        'inline': True
                    },
                    {
                        'name': '📊 Total Earned',
                        'value': format_points(lp['total_earned']),
                        'inline': True
                    }
                ])

            embed = create_embed(
                f"👤 {target.name}'s Profile",
                f"StreamHub account for {target.mention}",
                color=target.color if hasattr(target, 'color') else discord.Color.blue(),
                fields=fields
            )

            embed.set_thumbnail(url=target.display_avatar.url)
            await ctx.send(embed=embed)

    @commands.command(name='whois', aliases=['user'])
    async def whois(self, ctx: commands.Context, member: discord.Member = None):
        """Get detailed information about a Discord user"""
        target = member or ctx.author

        # Discord-specific info
        created_days = (discord.utils.utcnow() - target.created_at).days
        joined_days = (discord.utils.utcnow() - target.joined_at).days if target.joined_at else 0

        # Roles
        roles = [role.mention for role in target.roles[1:]]  # Exclude @everyone
        roles_str = ' '.join(roles[:10]) if roles else 'No roles'
        if len(roles) > 10:
            roles_str += f" +{len(roles) - 10} more"

        # Status
        status_emoji = {
            discord.Status.online: '🟢',
            discord.Status.idle: '🟡',
            discord.Status.dnd: '🔴',
            discord.Status.offline: '⚫'
        }

        fields = [
            {
                'name': '🆔 Discord ID',
                'value': str(target.id),
                'inline': True
            },
            {
                'name': '📅 Account Created',
                'value': f"{target.created_at.strftime('%Y-%m-%d')}\n({created_days} days ago)",
                'inline': True
            },
            {
                'name': '📥 Joined Server',
                'value': f"{target.joined_at.strftime('%Y-%m-%d') if target.joined_at else 'Unknown'}\n({joined_days} days ago)",
                'inline': True
            },
            {
                'name': f'{status_emoji.get(target.status, "⚫")} Status',
                'value': str(target.status).capitalize(),
                'inline': True
            },
            {
                'name': '🎭 Roles',
                'value': roles_str,
                'inline': False
            }
        ]

        # Add activity if present
        if target.activity:
            activity_type = {
                discord.ActivityType.playing: '🎮 Playing',
                discord.ActivityType.streaming: '📺 Streaming',
                discord.ActivityType.listening: '🎵 Listening to',
                discord.ActivityType.watching: '👀 Watching'
            }.get(target.activity.type, '🔹 Activity')

            fields.append({
                'name': activity_type,
                'value': target.activity.name,
                'inline': True
            })

        embed = create_embed(
            f"ℹ️ {target.name}#{target.discriminator}",
            color=target.color,
            fields=fields
        )

        embed.set_thumbnail(url=target.display_avatar.url)

        # Add badges
        badges = []
        if target.premium_since:
            badges.append('💎 Server Booster')
        if target.bot:
            badges.append('🤖 Bot')
        if badges:
            embed.set_footer(text=' • '.join(badges))

        await ctx.send(embed=embed)

    @commands.command(name='avatar', aliases=['av', 'pfp'])
    async def avatar(self, ctx: commands.Context, member: discord.Member = None):
        """Get a user's avatar"""
        target = member or ctx.author

        embed = create_embed(
            f"🖼️ {target.name}'s Avatar",
            color=target.color if hasattr(target, 'color') else discord.Color.blue()
        )

        embed.set_image(url=target.display_avatar.url)
        embed.add_field(
            name='Links',
            value=f'[PNG]({target.display_avatar.with_format("png").url}) | '
                  f'[JPG]({target.display_avatar.with_format("jpg").url}) | '
                  f'[WEBP]({target.display_avatar.with_format("webp").url})',
            inline=False
        )

        await ctx.send(embed=embed)

    @commands.command(name='register')
    async def register(self, ctx: commands.Context):
        """Register your StreamHub account"""
        embed = create_info_embed(
            "🔗 Register Your Account",
            "To register your StreamHub account:\n\n"
            "1. Visit [streamhub.com/register](https://streamhub.com/register)\n"
            "2. Click 'Sign in with Discord'\n"
            "3. Authorize the connection\n\n"
            "Your Discord account will be automatically linked!"
        )
        await ctx.send(embed=embed)


async def setup(bot: commands.Bot):
    """Setup function for cog"""
    await bot.add_cog(Profile(bot))
