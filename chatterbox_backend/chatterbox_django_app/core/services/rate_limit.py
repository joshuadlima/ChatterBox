import asyncio
import time

import redis
from core.redis_client import get_redis_client
from core.utils.lua_script_loader import LuaScriptLoader as lscr

class RateLimit:
    # Class-level cache for the SHA hash
    _SCRIPT_SHA = None
    _script_lock = asyncio.Lock() # For the thundering herd problem

    def __init__(self, limit: int, period: int):
        self.redis_client = None
        self.limit = limit
        self.period = period
        self.script_name = "rate_limit"

    async def _load_script(self):
            """Safely loads the script, immune to the Thundering Herd."""
            # If it's already loaded, don't even bother with the lock.
            if RateLimit._SCRIPT_SHA is not None:
                return

            # The Herd stops here. Only one task enters this block at a time.
            async with RateLimit._script_lock:
                
                # Double-Checked Locking
                # Check AGAIN, because another task might have loaded it 
                # while this task was waiting for the lock.
                if RateLimit._SCRIPT_SHA is None:
                    lua_code = lscr.load("core", self.script_name)
                    RateLimit._SCRIPT_SHA = await self.redis_client.script_load(lua_code)

    async def check_rate_limit(self, user_id: str) -> bool:
        if self.redis_client is None:
            self.redis_client = await get_redis_client()
        await self._load_script()
        
        refill_rate = self.limit / self.period

        try:
            is_allowed = await self.redis_client.evalsha(
                RateLimit._SCRIPT_SHA,
                1, # numkeys
                f"ratelimit:ws:{user_id}", # KEYS[1]
                self.limit,                # ARGV[1]
                refill_rate                # ARGV[2]
            )
        except redis.exceptions.NoScriptError:
            RateLimit._SCRIPT_SHA = None
            await self._load_script()
            is_allowed = await self.redis_client.evalsha(
                RateLimit._SCRIPT_SHA,
                1, 
                f"ratelimit:ws:{user_id}", 
                self.limit, 
                refill_rate
            )

        return is_allowed == 1