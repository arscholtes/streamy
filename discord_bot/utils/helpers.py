"""
Helper utilities for the Discord bot
"""
import discord
from typing import Optional
from datetime import datetime, timedelta


def format_points(points: int) -> str:
    """Format points with commas"""
    return f"{points:,}"


def format_duration(seconds: int) -> str:
    """Format duration in human-readable format"""
    if seconds < 60:
        return f"{seconds}s"
    elif seconds < 3600:
        minutes = seconds // 60
        return f"{minutes}m"
    else:
        hours = seconds // 3600
        minutes = (seconds % 3600) // 60
        return f"{hours}h {minutes}m"


def create_embed(
    title: str,
    description: Optional[str] = None,
    color: discord.Color = discord.Color.blue(),
    fields: Optional[list] = None,
    footer: Optional[str] = None,
    thumbnail: Optional[str] = None
) -> discord.Embed:
    """Create a formatted embed"""
    embed = discord.Embed(
        title=title,
        description=description,
        color=color,
        timestamp=datetime.utcnow()
    )

    if fields:
        for field in fields:
            embed.add_field(
                name=field.get('name', ''),
                value=field.get('value', ''),
                inline=field.get('inline', False)
            )

    if footer:
        embed.set_footer(text=footer)

    if thumbnail:
        embed.set_thumbnail(url=thumbnail)

    return embed


def create_success_embed(title: str, description: str) -> discord.Embed:
    """Create success embed"""
    return create_embed(
        title=f"✅ {title}",
        description=description,
        color=discord.Color.green()
    )


def create_error_embed(title: str, description: str) -> discord.Embed:
    """Create error embed"""
    return create_embed(
        title=f"❌ {title}",
        description=description,
        color=discord.Color.red()
    )


def create_info_embed(title: str, description: str) -> discord.Embed:
    """Create info embed"""
    return create_embed(
        title=f"ℹ️ {title}",
        description=description,
        color=discord.Color.blue()
    )


def calculate_level_from_points(total_earned: int) -> int:
    """Calculate level based on total points earned"""
    POINTS_PER_LEVEL_BASE = 100
    LEVEL_MULTIPLIER = 1.5

    level = 1
    points_needed = 0

    while True:
        points_for_next = int(POINTS_PER_LEVEL_BASE * (LEVEL_MULTIPLIER ** (level - 1)))
        if points_needed + points_for_next > total_earned:
            break
        points_needed += points_for_next
        level += 1

    return level


def points_to_next_level(total_earned: int, current_level: int) -> int:
    """Calculate points needed for next level"""
    POINTS_PER_LEVEL_BASE = 100
    LEVEL_MULTIPLIER = 1.5

    points_for_level = 0
    for lvl in range(1, current_level + 1):
        points_for_level += int(POINTS_PER_LEVEL_BASE * (LEVEL_MULTIPLIER ** (lvl - 1)))

    return points_for_level - total_earned
