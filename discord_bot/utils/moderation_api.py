"""
Moderation API client for Rails backend
Handles all moderation-related API calls
"""
import logging
from typing import Optional, Dict, List
from .api_client import api_client

logger = logging.getLogger(__name__)


class ModerationAPI:
    """Client for moderation API endpoints"""

    @staticmethod
    async def warn_user(discord_id: str, moderator_discord_id: str, guild_id: str, reason: str) -> Optional[Dict]:
        """
        Create a warning for a user

        Args:
            discord_id: Discord ID of user being warned
            moderator_discord_id: Discord ID of moderator
            guild_id: Discord guild/server ID
            reason: Reason for warning

        Returns:
            Warning data if successful, None otherwise
        """
        try:
            response = await api_client.post('/api/v1/moderation/warn', {
                'discord_id': discord_id,
                'moderator_discord_id': moderator_discord_id,
                'guild_id': guild_id,
                'reason': reason
            })
            return response.get('warning')
        except Exception as e:
            logger.error(f"Failed to create warning: {e}")
            return None

    @staticmethod
    async def get_warnings(discord_id: str, guild_id: str, limit: int = 10) -> Optional[Dict]:
        """
        Get warnings for a user

        Args:
            discord_id: Discord ID of user
            guild_id: Discord guild/server ID
            limit: Maximum number of warnings to return

        Returns:
            Warning data if successful, None otherwise
        """
        try:
            response = await api_client.get(
                f'/api/v1/moderation/warnings/{discord_id}',
                params={'guild_id': guild_id, 'limit': limit}
            )
            return response
        except Exception as e:
            logger.error(f"Failed to get warnings: {e}")
            return None

    @staticmethod
    async def clear_warnings(discord_id: str, moderator_discord_id: str, guild_id: str) -> bool:
        """
        Clear all warnings for a user

        Args:
            discord_id: Discord ID of user
            moderator_discord_id: Discord ID of moderator
            guild_id: Discord guild/server ID

        Returns:
            True if successful, False otherwise
        """
        try:
            await api_client.delete(
                f'/api/v1/moderation/warnings/{discord_id}',
                data={
                    'guild_id': guild_id,
                    'moderator_discord_id': moderator_discord_id
                }
            )
            return True
        except Exception as e:
            logger.error(f"Failed to clear warnings: {e}")
            return False

    @staticmethod
    async def mute_user(discord_id: str, moderator_discord_id: str, guild_id: str,
                       duration_minutes: int, reason: Optional[str] = None) -> Optional[Dict]:
        """
        Mute a user

        Args:
            discord_id: Discord ID of user to mute
            moderator_discord_id: Discord ID of moderator
            guild_id: Discord guild/server ID
            duration_minutes: Duration of mute in minutes
            reason: Reason for mute

        Returns:
            Mute data if successful, None otherwise
        """
        try:
            response = await api_client.post('/api/v1/moderation/mute', {
                'discord_id': discord_id,
                'moderator_discord_id': moderator_discord_id,
                'guild_id': guild_id,
                'duration_minutes': duration_minutes,
                'reason': reason or 'No reason provided'
            })
            return response.get('mute')
        except Exception as e:
            logger.error(f"Failed to mute user: {e}")
            return None

    @staticmethod
    async def unmute_user(discord_id: str, moderator_discord_id: str, guild_id: str,
                         reason: Optional[str] = None) -> bool:
        """
        Unmute a user

        Args:
            discord_id: Discord ID of user to unmute
            moderator_discord_id: Discord ID of moderator
            guild_id: Discord guild/server ID
            reason: Reason for unmute

        Returns:
            True if successful, False otherwise
        """
        try:
            await api_client.post('/api/v1/moderation/unmute', {
                'discord_id': discord_id,
                'moderator_discord_id': moderator_discord_id,
                'guild_id': guild_id,
                'reason': reason or 'Manual unmute'
            })
            return True
        except Exception as e:
            logger.error(f"Failed to unmute user: {e}")
            return False

    @staticmethod
    async def check_mute(discord_id: str, guild_id: str) -> Optional[Dict]:
        """
        Check if a user is muted

        Args:
            discord_id: Discord ID of user
            guild_id: Discord guild/server ID

        Returns:
            Mute data if user is muted, None otherwise
        """
        try:
            response = await api_client.get(
                f'/api/v1/moderation/mutes/{discord_id}',
                params={'guild_id': guild_id}
            )
            if response.get('is_muted'):
                return response.get('mute')
            return None
        except Exception as e:
            logger.error(f"Failed to check mute status: {e}")
            return None

    @staticmethod
    async def get_active_mutes(guild_id: str) -> List[Dict]:
        """
        Get all active mutes for a guild

        Args:
            guild_id: Discord guild/server ID

        Returns:
            List of active mutes
        """
        try:
            response = await api_client.get(
                '/api/v1/moderation/mutes/active',
                params={'guild_id': guild_id}
            )
            return response.get('active_mutes', [])
        except Exception as e:
            logger.error(f"Failed to get active mutes: {e}")
            return []

    @staticmethod
    async def log_action(action_type: str, moderator_discord_id: str, target_discord_id: str,
                        guild_id: str, reason: Optional[str] = None, metadata: Optional[Dict] = None) -> bool:
        """
        Log a moderation action

        Args:
            action_type: Type of action (kick, ban, etc.)
            moderator_discord_id: Discord ID of moderator
            target_discord_id: Discord ID of target user
            guild_id: Discord guild/server ID
            reason: Reason for action
            metadata: Additional metadata

        Returns:
            True if successful, False otherwise
        """
        try:
            await api_client.post('/api/v1/moderation/action', {
                'action_type': action_type,
                'moderator_discord_id': moderator_discord_id,
                'target_discord_id': target_discord_id,
                'guild_id': guild_id,
                'reason': reason or 'No reason provided',
                'metadata': metadata or {}
            })
            return True
        except Exception as e:
            logger.error(f"Failed to log moderation action: {e}")
            return False

    @staticmethod
    async def get_actions(guild_id: str, target_discord_id: Optional[str] = None,
                         action_type: Optional[str] = None, limit: int = 50) -> List[Dict]:
        """
        Get moderation actions log

        Args:
            guild_id: Discord guild/server ID
            target_discord_id: Filter by target user (optional)
            action_type: Filter by action type (optional)
            limit: Maximum number of actions to return

        Returns:
            List of moderation actions
        """
        try:
            params = {'guild_id': guild_id, 'limit': limit}
            if target_discord_id:
                params['target_discord_id'] = target_discord_id
            if action_type:
                params['action_type'] = action_type

            response = await api_client.get('/api/v1/moderation/actions', params=params)
            return response.get('actions', [])
        except Exception as e:
            logger.error(f"Failed to get moderation actions: {e}")
            return []


# Global instance
moderation_api = ModerationAPI()
