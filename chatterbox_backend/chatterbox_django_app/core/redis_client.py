import redis.asyncio as redis
from django.conf import settings
import logging
import asyncio

logger = logging.getLogger(__name__)

# Initialize pools as None at the module level
_common_pool = None
_infra_pool = None
_init_lock = asyncio.Lock() # Lock to prevent thundering herd on initialization

async def _initialize_pools():
    """Initializes the connection pools if they haven't been already."""
    global _common_pool, _infra_pool

    if _common_pool is None:
        async with _init_lock:
            if _common_pool is None:
                try:
                    logger.info("Initializing Redis connection pools...")
                    _common_pool = redis.ConnectionPool(
                        host=settings.REDIS_HOST,
                        port=settings.REDIS_PORT,
                        db=1,
                        max_connections=settings.REDIS_POOL_SIZE,
                        socket_connect_timeout=settings.REDIS_POOL_TIMEOUT,
                        decode_responses=True
                    )
                    _infra_pool = redis.ConnectionPool(
                        host=settings.REDIS_HOST,
                        port=settings.REDIS_PORT,
                        db=2,
                        max_connections=15,
                        socket_connect_timeout=2,
                        decode_responses=True
                    )
                    logger.info("Redis connection pools initialized successfully.")
                except Exception as e:
                    logger.exception(f"Failed to initialize Redis pools: {e}")
                    _common_pool = None
                    _infra_pool = None
                    raise

# This function must now be async to use the async lock
async def get_redis_client(pool_name: str = "common") -> redis.Redis:
    """
    Lazily initializes and returns a Redis client from the specified pool.
    """
    if _common_pool is None or _infra_pool is None:
        await _initialize_pools()

    if pool_name == "common":
        if _common_pool is None:
            raise ConnectionError("Common Redis pool is not available.")
        return redis.Redis(connection_pool=_common_pool)
    elif pool_name == "infra":
        if _infra_pool is None:
            raise ConnectionError("Infra Redis pool is not available.")
        return redis.Redis(connection_pool=_infra_pool)
    else:
        raise ValueError(f"Unknown Redis pool name: {pool_name}")