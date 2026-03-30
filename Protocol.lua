local P = {}
WowPoker.Protocol = P

local PREFIX = "WowPoker"
local VERSION = "1"
local SEPARATOR = ":"

-- Message types
P.MSG = {
    INV   = "INV",    -- Invite: VERSION:INV
    ACC   = "ACC",    -- Accept: VERSION:ACC
    DEC   = "DEC",    -- Decline: VERSION:DEC
    NH    = "NH",     -- New Hand: VERSION:NH:handNum:dealerSeat:card1:card2
    DEAL  = "DEAL",   -- Deal community: VERSION:DEAL:phase:card1[:card2:card3]
    COM   = "COM",    -- Community cards (for sync): VERSION:COM:card1:card2:...
    ACT   = "ACT",    -- Action: VERSION:ACT:action:amount
    SD    = "SD",     -- Showdown (reveal cards): VERSION:SD:card1:card2
    RES   = "RES",    -- Result: VERSION:RES:winnerSeat:handRank:pot
    QUIT  = "QUIT",   -- Quit: VERSION:QUIT
    PING  = "PING",   -- Heartbeat ping: VERSION:PING
    PONG  = "PONG",   -- Heartbeat pong: VERSION:PONG
    SYNC  = "SYNC",   -- State sync: VERSION:SYNC:data
}

-- Action codes (short for network)
P.ACTIONS = {
    F = "F",  -- Fold
    K = "K",  -- Check
    C = "C",  -- Call
    B = "B",  -- Bet
    R = "R",  -- Raise
    A = "A",  -- All-in
}

---Encode a message from parts
---@param msgType string
---@param ... string|number
---@return string
function P.Encode(msgType, ...)
    local parts = {VERSION, msgType}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        parts[#parts + 1] = tostring(v)
    end
    return table.concat(parts, SEPARATOR)
end

---Decode a raw message string into parts
---@param raw string
---@return string|nil version
---@return string|nil msgType
---@return table fields (remaining fields)
function P.Decode(raw)
    if not raw or raw == "" then return nil, nil, {} end

    local parts = {}
    for part in raw:gmatch("[^" .. SEPARATOR .. "]+") do
        parts[#parts + 1] = part
    end

    if #parts < 2 then return nil, nil, {} end

    local version = parts[1]
    local msgType = parts[2]
    local fields = {}
    for i = 3, #parts do
        fields[#fields + 1] = parts[i]
    end

    return version, msgType, fields
end

---Send a message to a specific player via addon whisper
---@param target string Player name
---@param msgType string Message type from P.MSG
---@param ... string|number Additional fields
function P.Send(target, msgType, ...)
    if not target or target == "" then return end
    local encoded = P.Encode(msgType, ...)
    C_ChatInfo.SendAddonMessage(PREFIX, encoded, "WHISPER", target)
end

---Register the addon prefix (call once at init)
function P.RegisterPrefix()
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
end

---Get the addon prefix
---@return string
function P.GetPrefix()
    return PREFIX
end

-- Dispatch table: msgType -> handler function
local handlers = {}

---Register a handler for a message type
---@param msgType string
---@param handler function(sender, fields)
function P.RegisterHandler(msgType, handler)
    handlers[msgType] = handler
end

---Process an incoming addon message
---@param prefix string
---@param message string
---@param channel string
---@param sender string
function P.OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= PREFIX then return end
    if channel ~= "WHISPER" then return end

    -- Strip realm name if present for comparison
    local shortSender = sender:match("^([^-]+)") or sender

    -- Don't process our own messages
    local playerName = UnitName("player")
    if shortSender == playerName then return end

    local version, msgType, fields = P.Decode(message)
    if not version or not msgType then return end

    -- Version check (allow same major version)
    if version ~= VERSION then return end

    local handler = handlers[msgType]
    if handler then
        handler(sender, fields)
    end
end
