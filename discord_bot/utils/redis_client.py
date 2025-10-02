"""
Redis Client
Handles caching and session management
"""
import redis
import json
import logging
from typing import Optional, Any
from config.settings import REDIS_HOST, REDIS_PORT, REDIS_DB

logger = logging.getLogger(__name__)


class RedisClient:
    """Redis client for caching and rate limiting"""

    def __init__(self):
        self.client = redis.Redis(
            host=REDIS_HOST,
            port=REDIS_PORT,
            db=REDIS_DB,
            decode_responses=True
        )

    def get(self, key: str) -> Optional[Any]:
        """Get value from Redis"""
        try:
            value = self.client.get(key)
            if value:
                return json.loads(value)
            return None
        except (redis.RedisError, json.JSONDecodeError) as e:
            logger.error(f"Redis GET error for key {key}: {e}")
            return None

    def set(self, key: str, value: Any, ttl: Optional[int] = None) -> bool:
        """Set value in Redis with optional TTL (seconds)"""
        try:
            json_value = json.dumps(value)
            if ttl:
                self.client.setex(key, ttl, json_value)
            else:
                self.client.set(key, json_value)
            return True
        except (redis.RedisError, TypeError) as e:
            logger.error(f"Redis SET error for key {key}: {e}")
            return False

    def delete(self, key: str) -> bool:
        """Delete key from Redis"""
        try:
            self.client.delete(key)
            return True
        except redis.RedisError as e:
            logger.error(f"Redis DELETE error for key {key}: {e}")
            return False

    def exists(self, key: str) -> bool:
        """Check if key exists"""
        try:
            return bool(self.client.exists(key))
        except redis.RedisError as e:
            logger.error(f"Redis EXISTS error for key {key}: {e}")
            return False

    def increment(self, key: str, amount: int = 1) -> Optional[int]:
        """Increment counter"""
        try:
            return self.client.incrby(key, amount)
        except redis.RedisError as e:
            logger.error(f"Redis INCREMENT error for key {key}: {e}")
            return None

    def check_rate_limit(
        self,
        key: str,
        max_requests: int,
        window_seconds: int
    ) -> tuple[bool, int]:
        """
        Check rate limit using sliding window
        Returns (is_allowed, current_count)
        """
        try:
            current = self.client.get(key)
            if current is None:
                self.client.setex(key, window_seconds, 1)
                return True, 1

            count = int(current)
            if count >= max_requests:
                return False, count

            self.client.incr(key)
            return True, count + 1
        except redis.RedisError as e:
            logger.error(f"Redis rate limit error for key {key}: {e}")
            return True, 0  # Allow on error


# Global instance
redis_client = RedisClient()
