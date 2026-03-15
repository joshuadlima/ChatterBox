import functools
from core.services.rate_limit import RateLimit

def websocket_rate_limit(limit: int, period: int):
    """
    Decorator to rate-limit WebSocket events.
    Sends an error JSON back to the client if the limit is exceeded.
    """
    def decorator(func):
        @functools.wraps(func)
        async def wrapper(self, *args, **kwargs):
            # 'self' is the AsyncWebsocketConsumer instance.
            # For anonymous Omegle-style routing, channel_name is a great unique ID.
            identifier = self.user_id 
            
            # Initialize our rate limiter
            limiter = RateLimit(limit=limit, period=period)
            
            # Check if the action is allowed
            is_allowed = await limiter.check_rate_limit(identifier)
            
            if not is_allowed:
                # If blocked, notify the client and halt execution
                await self.send_response("error", "Rate limit exceeded")
                return  # Crucial: Drop the request, do not execute the function
            
            # If allowed, proceed to the actual handler function
            return await func(self, *args, **kwargs)
            
        return wrapper
    return decorator