-- KEYS[1...N] : The interest set keys (e.g., "interest:rock", "interest:coding")
-- ARGV[1] : current_user

local current_user = ARGV[1]

for i, interest_set in ipairs(KEYS) do
    redis.call('SREM', interest_set, current_user)
end

-- Update status to idle
redis.call('HSET', 'user_meta:' .. current_user, 'status', 'idle')

return nil