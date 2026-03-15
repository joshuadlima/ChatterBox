-- ARGV[1] : user_id

local user_id = ARGV[1]

-- 1. Check if they were in a match
local partner_id = redis.call('HGET', 'active_matches', user_id)
if partner_id then
    redis.call('HDEL', 'active_matches', user_id)
    redis.call('HDEL', 'active_matches', partner_id)
    -- We'll return partner_id so Python can notify them
end

-- 2. Clean up Interest Sets
local interests_raw = redis.call('HGET', 'user_meta:' .. user_id, 'interests')
if interests_raw then
    -- (Reuse your split function here)
    for topic in string.gmatch(interests_raw, '([^,]+)') do
        redis.call('SREM', 'interest:' .. topic, user_id)
    end
end

-- 3. Wipe the metadata
redis.call('DEL', 'user_meta:' .. user_id)

return partner_id -- nil if they weren't chatting