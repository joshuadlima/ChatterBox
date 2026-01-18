-- KEYS[1...N] : The interest set keys (e.g., "interest:rock", "interest:coding")
-- ARGV[1]     : Current User ID (e.g., "user_A")

local current_user = ARGV[1]

-- SEARCH PHASE: Try to find an existing user in any of the requested interests
for i, interest_set in ipairs(KEYS) do
    -- SPOP gets a random user and removes them from the set atomically
    local partner = redis.call('SPOP', interest_set)
    
    if partner then
        -- We found a partner! 
        -- To prevent User B (partner) from being matched again via another interest set,
        -- we must ensure they are scrubbed from all other sets they might be in.
        
        -- CLEANUP PHASE: Get partner's other interests to remove them from those sets
        local partner_interests_raw = redis.call('HGET', 'user_meta:' .. partner, 'interests')
        
        if partner_interests_raw then
            for topic in string.gmatch(partner_interests_raw, '([^,]+)') do
                -- Remove partner from every set they were waiting in
                redis.call('SREM', 'interest:' .. topic, partner)
            end
        end

        -- CREATE THE MATCH
        -- Store the relationship both ways so either side can find their partner
        redis.call('HSET', 'active_matches', current_user, partner)
        redis.call('HSET', 'active_matches', partner, current_user)
        redis.call('HSET', 'user_meta:' .. current_user, 'partner', partner)

        -- Update statuses
        redis.call('HSET', 'user_meta:' .. current_user, 'status', 'chatting')
        redis.call('HSET', 'user_meta:' .. partner, 'status', 'chatting')

        -- Return the partner ID to Django
        return partner
    end
end

-- QUEUE PHASE: No partner found in any interest set
-- Add current user to all their interest sets so the NEXT person can find them
for i, interest_set in ipairs(KEYS) do
    redis.call('SADD', interest_set, current_user)
end

-- Update status to searching
redis.call('HSET', 'user_meta:' .. current_user, 'status', 'searching')

return nil -- Signals to Django: "No match yet, keep waiting"