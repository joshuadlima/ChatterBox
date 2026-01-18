-- ARGV[1] : The ID of the user who ended the chat (e.g., "user_A")

local user_id = ARGV[1]

-- Find who this user was talking to
local partner_id = redis.call('HGET', 'active_matches', user_id)

if partner_id then
    -- Remove the mapping for BOTH users
    redis.call('HDEL', 'active_matches', user_id)
    redis.call('HDEL', 'active_matches', partner_id)

    -- Update both users' status back to 'idle'
    -- This ensures they don't accidentally stay in 'chatting' state
    redis.call('HSET', 'user_meta:' .. user_id, 'status', 'idle')
    redis.call('HSET', 'user_meta:' .. partner_id, 'status', 'idle')

    -- Return the partner_id so Django knows who to notify
    return partner_id
end

return nil