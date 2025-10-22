"""
Rails API Client
Handles all communication with the Rails backend
"""
import aiohttp
import logging
from typing import Optional, Dict, Any
from config.settings import RAILS_API_URL, RAILS_API_KEY

logger = logging.getLogger(__name__)


class RailsAPIClient:
    """Client for communicating with Rails API"""

    def __init__(self):
        self.base_url = RAILS_API_URL
        self.api_key = RAILS_API_KEY
        self.session: Optional[aiohttp.ClientSession] = None

    async def __aenter__(self):
        self.session = aiohttp.ClientSession(
            headers={'Authorization': f'Bearer {self.api_key}'}
        )
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()

    async def _request(self, method: str, endpoint: str, **kwargs) -> Dict[Any, Any]:
        """Make HTTP request to Rails API"""
        if not self.session:
            self.session = aiohttp.ClientSession(
                headers={'Authorization': f'Bearer {self.api_key}'}
            )

        url = f"{self.base_url}{endpoint}"

        try:
            async with self.session.request(method, url, **kwargs) as response:
                response.raise_for_status()
                return await response.json()
        except aiohttp.ClientError as e:
            logger.error(f"API request failed: {method} {url} - {e}")
            raise

    async def get(self, endpoint: str, params: Optional[Dict] = None) -> Dict:
        """Make GET request"""
        return await self._request('GET', endpoint, params=params)

    async def post(self, endpoint: str, data: Optional[Dict] = None) -> Dict:
        """Make POST request"""
        return await self._request('POST', endpoint, json=data)

    async def delete(self, endpoint: str, data: Optional[Dict] = None) -> Dict:
        """Make DELETE request"""
        return await self._request('DELETE', endpoint, json=data)

    # User endpoints
    async def get_user_by_discord_id(self, discord_id: str) -> Optional[Dict]:
        """Get user by Discord ID"""
        try:
            return await self._request('GET', f'/api/v1/users/discord/{discord_id}')
        except aiohttp.ClientError:
            return None

    async def create_user(self, discord_id: str, username: str, email: str) -> Dict:
        """Create new user"""
        return await self._request('POST', '/api/v1/users', json={
            'discord_id': discord_id,
            'username': username,
            'email': email
        })

    # Loyalty points endpoints
    async def get_loyalty_points(self, user_id: int) -> Optional[Dict]:
        """Get user's loyalty points"""
        try:
            return await self._request('GET', f'/api/v1/users/{user_id}/loyalty_points')
        except aiohttp.ClientError:
            return None

    async def add_loyalty_points(
        self,
        user_id: int,
        amount: int,
        description: str,
        transaction_type: str = 'earned_custom',
        metadata: Optional[Dict] = None
    ) -> Dict:
        """Add loyalty points to user"""
        return await self._request('POST', f'/api/v1/users/{user_id}/loyalty_points/add', json={
            'amount': amount,
            'description': description,
            'transaction_type': transaction_type,
            'metadata': metadata or {}
        })

    async def spend_loyalty_points(
        self,
        user_id: int,
        amount: int,
        description: str,
        transaction_type: str = 'spent_custom',
        metadata: Optional[Dict] = None
    ) -> Dict:
        """Spend loyalty points"""
        return await self._request('POST', f'/api/v1/users/{user_id}/loyalty_points/spend', json={
            'amount': amount,
            'description': description,
            'transaction_type': transaction_type,
            'metadata': metadata or {}
        })

    # Achievement endpoints
    async def get_achievements(self) -> list:
        """Get all achievements"""
        return await self._request('GET', '/api/v1/achievements')

    async def get_user_achievements(self, user_id: int) -> list:
        """Get user's achievements"""
        return await self._request('GET', f'/api/v1/users/{user_id}/achievements')

    async def award_achievement(self, user_id: int, achievement_id: int) -> Dict:
        """Award achievement to user"""
        return await self._request('POST', f'/api/v1/users/{user_id}/achievements', json={
            'achievement_id': achievement_id
        })

    # VC Queue endpoints
    async def join_vc_queue(
        self,
        user_id: int,
        discord_user_id: str,
        priority: int = 0
    ) -> Dict:
        """Add user to VC queue"""
        return await self._request('POST', '/api/v1/vc_queue/join', json={
            'user_id': user_id,
            'discord_user_id': discord_user_id,
            'priority': priority
        })

    async def leave_vc_queue(self, user_id: int) -> Dict:
        """Remove user from VC queue"""
        return await self._request('POST', f'/api/v1/vc_queue/leave/{user_id}')

    async def get_vc_queue(self) -> list:
        """Get current VC queue"""
        return await self._request('GET', '/api/v1/vc_queue')

    # Mini-game endpoints
    async def record_game_session(
        self,
        user_id: int,
        game_type: str,
        bet_amount: int,
        result: str,
        winnings: int,
        metadata: Optional[Dict] = None
    ) -> Dict:
        """Record mini-game session"""
        return await self._request('POST', '/api/v1/mini_games/record', json={
            'user_id': user_id,
            'game_type': game_type,
            'bet_amount': bet_amount,
            'result': result,
            'winnings': winnings,
            'metadata': metadata or {}
        })

    async def get_game_stats(self, user_id: int, game_type: Optional[str] = None) -> Dict:
        """Get user's game statistics"""
        endpoint = f'/api/v1/users/{user_id}/mini_games/stats'
        if game_type:
            endpoint += f'?game_type={game_type}'
        return await self._request('GET', endpoint)

    # Goal endpoints
    async def get_goals(self, user_id: int, status: Optional[str] = None, goal_type: Optional[str] = None) -> Dict:
        """Get user's goals"""
        endpoint = f'/api/v1/users/{user_id}/goals'
        params = {}
        if status:
            params['status'] = status
        if goal_type:
            params['goal_type'] = goal_type

        if params:
            query_string = '&'.join([f'{k}={v}' for k, v in params.items()])
            endpoint += f'?{query_string}'

        return await self._request('GET', endpoint)

    async def get_goal(self, goal_id: int) -> Dict:
        """Get specific goal details"""
        return await self._request('GET', f'/api/v1/goals/{goal_id}')

    async def create_goal(
        self,
        user_id: int,
        title: str,
        description: str = None,
        goal_type: str = 'growth',
        status: str = 'active',
        progress_type: str = 'percentage',
        target_value: float = None,
        deadline: str = None,
        visibility: str = 'private_goal',
        metadata: Optional[Dict] = None
    ) -> Dict:
        """Create a new goal"""
        data = {
            'goal': {
                'title': title,
                'description': description,
                'goal_type': goal_type,
                'status': status,
                'progress_type': progress_type,
                'target_value': target_value,
                'deadline': deadline,
                'visibility': visibility,
                'metadata': metadata or {}
            }
        }
        return await self._request('POST', f'/api/v1/users/{user_id}/goals', json=data)

    async def update_goal(self, goal_id: int, **kwargs) -> Dict:
        """Update a goal"""
        data = {'goal': kwargs}
        return await self._request('PATCH', f'/api/v1/goals/{goal_id}', json=data)

    async def delete_goal(self, goal_id: int) -> Dict:
        """Delete a goal"""
        return await self._request('DELETE', f'/api/v1/goals/{goal_id}')

    async def update_goal_progress(self, goal_id: int, value: float, note: str = None) -> Dict:
        """Update goal progress"""
        data = {'value': value}
        if note:
            data['note'] = note
        return await self._request('POST', f'/api/v1/goals/{goal_id}/progress', json=data)

    async def complete_goal(self, goal_id: int) -> Dict:
        """Mark goal as completed"""
        return await self._request('POST', f'/api/v1/goals/{goal_id}/complete')

    async def pause_goal(self, goal_id: int) -> Dict:
        """Pause a goal"""
        return await self._request('POST', f'/api/v1/goals/{goal_id}/pause')

    async def resume_goal(self, goal_id: int) -> Dict:
        """Resume a paused goal"""
        return await self._request('POST', f'/api/v1/goals/{goal_id}/resume')

    async def abandon_goal(self, goal_id: int) -> Dict:
        """Abandon a goal"""
        return await self._request('POST', f'/api/v1/goals/{goal_id}/abandon')

    async def get_goal_stats(self, user_id: int) -> Dict:
        """Get goal statistics for user"""
        return await self._request('GET', f'/api/v1/users/{user_id}/goals/stats')

    # Analytics endpoints
    async def get_analytics_overview(self, user_id: int, period_start: str = None, period_end: str = None) -> Dict:
        """Get analytics overview for user"""
        endpoint = f'/api/v1/users/{user_id}/analytics/overview'
        params = {}
        if period_start:
            params['period_start'] = period_start
        if period_end:
            params['period_end'] = period_end

        if params:
            query_string = '&'.join([f'{k}={v}' for k, v in params.items()])
            endpoint += f'?{query_string}'

        return await self._request('GET', endpoint)

    async def get_analytics_growth(self, user_id: int, period_start: str = None, period_end: str = None) -> Dict:
        """Get growth analytics for user"""
        endpoint = f'/api/v1/users/{user_id}/analytics/growth'
        params = {}
        if period_start:
            params['period_start'] = period_start
        if period_end:
            params['period_end'] = period_end

        if params:
            query_string = '&'.join([f'{k}={v}' for k, v in params.items()])
            endpoint += f'?{query_string}'

        return await self._request('GET', endpoint)

    async def get_analytics_insights(self, user_id: int, period_start: str = None, period_end: str = None) -> Dict:
        """Get insights with context for user"""
        endpoint = f'/api/v1/users/{user_id}/analytics/insights'
        params = {}
        if period_start:
            params['period_start'] = period_start
        if period_end:
            params['period_end'] = period_end

        if params:
            query_string = '&'.join([f'{k}={v}' for k, v in params.items()])
            endpoint += f'?{query_string}'

        return await self._request('GET', endpoint)

    async def get_analytics_content(self, user_id: int, period_start: str = None, period_end: str = None) -> Dict:
        """Get content performance analytics for user"""
        endpoint = f'/api/v1/users/{user_id}/analytics/content'
        params = {}
        if period_start:
            params['period_start'] = period_start
        if period_end:
            params['period_end'] = period_end

        if params:
            query_string = '&'.join([f'{k}={v}' for k, v in params.items()])
            endpoint += f'?{query_string}'

        return await self._request('GET', endpoint)

    async def get_analytics_audience(self, user_id: int, period_start: str = None, period_end: str = None) -> Dict:
        """Get audience analytics for user"""
        endpoint = f'/api/v1/users/{user_id}/analytics/audience'
        params = {}
        if period_start:
            params['period_start'] = period_start
        if period_end:
            params['period_end'] = period_end

        if params:
            query_string = '&'.join([f'{k}={v}' for k, v in params.items()])
            endpoint += f'?{query_string}'

        return await self._request('GET', endpoint)

    async def get_analytics_compare(self, user_id: int, period_start: str = None, period_end: str = None) -> Dict:
        """Compare analytics between periods"""
        endpoint = f'/api/v1/users/{user_id}/analytics/compare'
        params = {}
        if period_start:
            params['period_start'] = period_start
        if period_end:
            params['period_end'] = period_end

        if params:
            query_string = '&'.join([f'{k}={v}' for k, v in params.items()])
            endpoint += f'?{query_string}'

        return await self._request('GET', endpoint)


# Global instance
api_client = RailsAPIClient()
