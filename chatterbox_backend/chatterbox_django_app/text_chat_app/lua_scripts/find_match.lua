-- Atomic matching script 
-- DESCRIPTION: makes the user visible for matching, looks for one with common interests, and if found, removes both from visibility and waiting sets

-- ARGV[1]: user_id
-- ARGV[2]: channel_name
-- ARGV[3]: interests (JSON array)
-- Returns: {matched_user_id, partner_channel} or nil

local user_id = ARGV[1]
local channel_name = ARGV[2]
local interests_json = ARGV[3]

local interests = cjson.decode(interests_json)

-- Make user visible for matching
redis.call('HSET', 'user:' .. user_id, 'channel_name', channel_name)

-- Find probable matches across all interests
local probable_matches = {}
local seen = {}

for _, interest in ipairs(interests) do
    local waiting_users = redis.call('SMEMBERS', 'waiting_users:' .. interest)
    
    for _, other_user in ipairs(waiting_users) do
        if other_user ~= user_id and redis.call('EXISTS', 'user:' .. other_user) == 1 then
            if not seen[other_user] then
                table.insert(probable_matches, other_user)
                seen[other_user] = true
            end
        end
    end
end

if #probable_matches == 0 then
    return nil
end

-- Pick a random match
math.randomseed(tonumber(redis.call('TIME')[1]) + tonumber(redis.call('TIME')[2]))
local matched_user = probable_matches[math.random(#probable_matches)]

-- Get partner's channel
local partner_channel = redis.call('HGET', 'user:' .. matched_user, 'channel_name')

if not partner_channel then
    return nil
end

-- Atomically remove both users from visibility and waiting sets
redis.call('DEL', 'user:' .. user_id)
redis.call('DEL', 'user:' .. matched_user)

for _, interest in ipairs(interests) do
    redis.call('SREM', 'waiting_users:' .. interest, user_id)
    redis.call('SREM', 'waiting_users:' .. interest, matched_user)
end

return {matched_user, partner_channel}