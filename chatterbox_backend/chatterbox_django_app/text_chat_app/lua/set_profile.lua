-- KEYS[1...N] : The interest set keys (e.g., "interest:rock", "interest:coding")
-- ARGV[1]     : User ID (e.g., "user123")
-- ARGV[2]     : Channel Name (from Django Channels)
-- ARGV[3]     : Comma-separated string of interests (for easy cleanup later)

local user_id = ARGV[1]
local channel_name = ARGV[2]
local interests_str = ARGV[3]

-- Save user metadata to a Hash
-- This allows the server to remember the user's "state"
redis.call('HSET', 'user_meta:' .. user_id, 
    'channel', channel_name, 
    'interests', interests_str,
    'status', 'searching'
)

return nil