-- KEYS[1]: The Redis key for the user/connection
-- ARGV[1]: Bucket Capacity (maximum tokens allowed)
-- ARGV[2]: Refill Rate (tokens added per second)

-- Token Bucket Algo
local key = KEYS[1]
local capacity = tonumber(ARGV[1])
local refill_rate = tonumber(ARGV[2])
local now = tonumber(redis.call("TIME")[1])
local requested = 1 -- We consume 1 token per message

-- Fetch current tokens and last updated time from a Redis Hash
local tokens = tonumber(redis.call("HGET", key, "tokens"))
local last_updated = tonumber(redis.call("HGET", key, "last_updated"))

-- Initialize bucket if it doesn't exist
if tokens == nil then
    tokens = capacity
    last_updated = now
else
    -- Calculate how many tokens to add based on time passed
    local time_passed = math.max(0, now - last_updated)
    local new_tokens = math.floor(time_passed * refill_rate)
    
    -- Only update if we are actually adding tokens
    if new_tokens > 0 then
        tokens = math.min(capacity, tokens + new_tokens)
        last_updated = now
    end
end

-- Check if we have enough tokens
local allowed = 0
if tokens >= requested then
    tokens = tokens - requested
    allowed = 1
end

-- Save the updated state back to Redis
redis.call("HMSET", key, "tokens", tokens, "last_updated", last_updated)

-- Set an expiration so inactive users don't clutter Redis
-- The key can safely expire when the bucket would theoretically be completely full
-- We can safely delete the key when the bucket would be full again, which is after capacity / refill_rate seconds
local ttl = math.ceil(capacity / refill_rate)
redis.call("EXPIRE", key, ttl)

return allowed -- Returns 1 if allowed, 0 if rejected