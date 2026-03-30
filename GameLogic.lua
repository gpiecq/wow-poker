local G = {}
WowPoker.Game = G

local P = WowPoker.Protocol
local D = WowPoker.Deck
local L = WowPoker.L

-- Constants
local STARTING_CHIPS = 1000
local SMALL_BLIND = 10
local BIG_BLIND = 20

-- States
G.STATE = {
    IDLE            = "IDLE",
    WAITING_ACCEPT  = "WAITING_ACCEPT",
    PREFLOP         = "PREFLOP",
    FLOP            = "FLOP",
    TURN            = "TURN",
    RIVER           = "RIVER",
    SHOWDOWN        = "SHOWDOWN",
    HAND_OVER       = "HAND_OVER",
}

-- Seats
G.SEAT_1 = 1  -- Host (inviter)
G.SEAT_2 = 2  -- Guest (invitee)

-- Game state
local game = {
    state = G.STATE.IDLE,
    opponent = nil,
    isHost = false,
    mySeat = 0,

    -- Hand state
    handNumber = 0,
    dealerSeat = 0,
    deck = nil,
    holeCards = {{}, {}},      -- [seat] = {card1, card2}
    community = {},
    pot = 0,
    bets = {0, 0},            -- current round bets [seat]
    chips = {0, 0},           -- [seat]
    folded = {false, false},
    allIn = {false, false},
    actedThisRound = {false, false},
    currentActor = 0,         -- seat whose turn it is
    lastRaiser = 0,           -- who made the last raise

    -- Invitation
    pendingInviteFrom = nil,
    inviteTimer = nil,
    actionTimer = nil,

    -- Heartbeat
    pingTimer = nil,
    missedPongs = 0,
}

G.game = game

---Get current game state
function G.GetState()
    return game.state
end

---Get opponent name
function G.GetOpponent()
    return game.opponent
end

---Check if player is host
function G.IsHost()
    return game.isHost
end

---Get my seat number
function G.GetMySeat()
    return game.mySeat
end

---Get opponent's seat number
function G.GetOpponentSeat()
    return game.mySeat == G.SEAT_1 and G.SEAT_2 or G.SEAT_1
end

---Get chips for a seat
function G.GetChips(seat)
    return game.chips[seat] or 0
end

---Get current pot
function G.GetPot()
    return game.pot
end

---Get bet for a seat
function G.GetBet(seat)
    return game.bets[seat] or 0
end

---Get hole cards for a seat
function G.GetHoleCards(seat)
    return game.holeCards[seat] or {}
end

---Get community cards
function G.GetCommunity()
    return game.community
end

---Get current hand number
function G.GetHandNumber()
    return game.handNumber
end

---Get dealer seat
function G.GetDealerSeat()
    return game.dealerSeat
end

---Is it my turn?
function G.IsMyTurn()
    return game.currentActor == game.mySeat
end

---Get current actor seat
function G.GetCurrentActor()
    return game.currentActor
end

---Has a seat folded?
function G.HasFolded(seat)
    return game.folded[seat]
end

---Is a seat all-in?
function G.IsAllIn(seat)
    return game.allIn[seat]
end

-- ==========================================
-- INVITATION FLOW
-- ==========================================

---Send an invitation to a player
function G.SendInvite(targetName)
    if game.state ~= G.STATE.IDLE then
        G.PrintMessage(L["INVITE_ALREADY_IN_GAME"])
        return
    end

    game.opponent = targetName
    game.isHost = true
    game.mySeat = G.SEAT_1
    game.state = G.STATE.WAITING_ACCEPT

    P.Send(targetName, P.MSG.INV)
    G.PrintMessage(string.format(L["INVITE_SENT"], targetName))

    -- Start 30s timeout
    G.StartInviteTimeout()
end

---Accept a pending invitation
function G.AcceptInvite()
    if not game.pendingInviteFrom then
        G.PrintMessage(L["INVITE_NO_PENDING"])
        return
    end

    game.opponent = game.pendingInviteFrom
    game.isHost = false
    game.mySeat = G.SEAT_2
    game.state = G.STATE.IDLE
    game.pendingInviteFrom = nil

    P.Send(game.opponent, P.MSG.ACC)

    -- Initialize chips
    game.chips = {STARTING_CHIPS, STARTING_CHIPS}

    G.CancelInviteTimeout()

    -- Wait for host to start the hand
    if WowPoker.UI and WowPoker.UI.Show then
        WowPoker.UI.Show()
        WowPoker.UI.UpdateAll()
    end

    G.StartHeartbeat()
end

---Decline a pending invitation
function G.DeclineInvite()
    if not game.pendingInviteFrom then
        G.PrintMessage(L["INVITE_NO_PENDING"])
        return
    end

    P.Send(game.pendingInviteFrom, P.MSG.DEC)
    game.pendingInviteFrom = nil
    G.CancelInviteTimeout()
end

-- ==========================================
-- HAND FLOW (Host manages)
-- ==========================================

---Start a new hand (host only)
function G.StartNewHand()
    if not game.isHost then return end

    game.handNumber = game.handNumber + 1

    -- Alternate dealer (seat 1 starts as dealer on hand 1)
    if game.handNumber == 1 then
        game.dealerSeat = G.SEAT_1
    else
        game.dealerSeat = (game.dealerSeat == G.SEAT_1) and G.SEAT_2 or G.SEAT_1
    end

    -- Reset hand state
    game.community = {}
    game.pot = 0
    game.bets = {0, 0}
    game.folded = {false, false}
    game.allIn = {false, false}
    game.actedThisRound = {false, false}
    game.lastRaiser = 0

    -- Create and shuffle deck
    game.deck = D.New()
    D.Shuffle(game.deck)

    -- Deal hole cards
    local cards1 = D.Deal(game.deck, 2)
    local cards2 = D.Deal(game.deck, 2)
    game.holeCards[G.SEAT_1] = cards1
    game.holeCards[G.SEAT_2] = cards2

    -- Post blinds: dealer = small blind, non-dealer = big blind (heads-up rules)
    local sbSeat = game.dealerSeat
    local bbSeat = (sbSeat == G.SEAT_1) and G.SEAT_2 or G.SEAT_1

    local sbAmount = math.min(SMALL_BLIND, game.chips[sbSeat])
    local bbAmount = math.min(BIG_BLIND, game.chips[bbSeat])

    game.chips[sbSeat] = game.chips[sbSeat] - sbAmount
    game.chips[bbSeat] = game.chips[bbSeat] - bbAmount
    game.bets[sbSeat] = sbAmount
    game.bets[bbSeat] = bbAmount

    if game.chips[sbSeat] == 0 then game.allIn[sbSeat] = true end
    if game.chips[bbSeat] == 0 then game.allIn[bbSeat] = true end

    -- Preflop: dealer (small blind) acts first in heads-up
    game.currentActor = game.dealerSeat
    game.state = G.STATE.PREFLOP

    -- Send NH message to opponent with their cards
    local c2str1 = D.CardToString(cards2[1])
    local c2str2 = D.CardToString(cards2[2])
    P.Send(game.opponent, P.MSG.NH, game.handNumber, game.dealerSeat, c2str1, c2str2)

    G.PrintMessage(string.format(L["GAME_NEW_HAND"], game.handNumber))

    if game.dealerSeat == game.mySeat then
        G.PrintMessage(L["GAME_YOU_ARE_DEALER"])
    else
        G.PrintMessage(string.format(L["GAME_OPPONENT_DEALER"], game.opponent))
    end

    if WowPoker.UI and WowPoker.UI.UpdateAll then
        WowPoker.UI.UpdateAll()
    end

    -- Start action timer if it's our turn
    if game.currentActor == game.mySeat then
        G.StartActionTimeout()
    end

    -- If both are all-in from blinds, run the board
    if game.allIn[G.SEAT_1] and game.allIn[G.SEAT_2] then
        G.RunOutBoard()
    end
end

---Handle receiving a new hand (guest)
function G.OnReceiveNewHand(handNum, dealerSeat, card1str, card2str)
    game.handNumber = tonumber(handNum) or game.handNumber + 1
    game.dealerSeat = tonumber(dealerSeat) or G.SEAT_1

    -- Reset hand state
    game.community = {}
    game.pot = 0
    game.bets = {0, 0}
    game.folded = {false, false}
    game.allIn = {false, false}
    game.actedThisRound = {false, false}
    game.lastRaiser = 0

    -- Set my hole cards
    game.holeCards[game.mySeat] = {
        D.StringToCard(card1str),
        D.StringToCard(card2str),
    }
    -- Opponent cards are unknown
    game.holeCards[G.GetOpponentSeat()] = {}

    -- Post blinds
    local sbSeat = game.dealerSeat
    local bbSeat = (sbSeat == G.SEAT_1) and G.SEAT_2 or G.SEAT_1

    local sbAmount = math.min(SMALL_BLIND, game.chips[sbSeat])
    local bbAmount = math.min(BIG_BLIND, game.chips[bbSeat])

    game.chips[sbSeat] = game.chips[sbSeat] - sbAmount
    game.chips[bbSeat] = game.chips[bbSeat] - bbAmount
    game.bets[sbSeat] = sbAmount
    game.bets[bbSeat] = bbAmount

    if game.chips[sbSeat] == 0 then game.allIn[sbSeat] = true end
    if game.chips[bbSeat] == 0 then game.allIn[bbSeat] = true end

    -- Preflop: dealer acts first in heads-up
    game.currentActor = game.dealerSeat
    game.state = G.STATE.PREFLOP

    G.PrintMessage(string.format(L["GAME_NEW_HAND"], game.handNumber))

    if game.dealerSeat == game.mySeat then
        G.PrintMessage(L["GAME_YOU_ARE_DEALER"])
    else
        G.PrintMessage(string.format(L["GAME_OPPONENT_DEALER"], game.opponent))
    end

    if WowPoker.UI and WowPoker.UI.UpdateAll then
        WowPoker.UI.UpdateAll()
    end

    if game.currentActor == game.mySeat then
        G.StartActionTimeout()
    end
end

-- ==========================================
-- BETTING
-- ==========================================

---Get the valid actions for the current actor
---@return table actions {fold=bool, check=bool, call=bool|amount, bet=bool|{min,max}, raise=bool|{min,max}, allin=bool|amount}
function G.GetValidActions()
    local seat = game.currentActor
    if seat == 0 then return {} end
    if game.folded[seat] or game.allIn[seat] then return {} end

    local myBet = game.bets[seat]
    local oppSeat = (seat == G.SEAT_1) and G.SEAT_2 or G.SEAT_1
    local oppBet = game.bets[oppSeat]
    local myChips = game.chips[seat]
    local toCall = oppBet - myBet

    local actions = {}

    -- Fold is always available
    actions.fold = true

    if toCall <= 0 then
        -- No bet to match
        actions.check = true
        if myChips > 0 then
            local minBet = BIG_BLIND
            if myChips <= minBet then
                actions.allin = myChips
            else
                actions.bet = {min = minBet, max = myChips}
                actions.allin = myChips
            end
        end
    else
        -- Must call or raise
        if toCall >= myChips then
            -- Can only call all-in or fold
            actions.call = myChips
            actions.allin = myChips
        else
            actions.call = toCall
            -- Raise: min raise = previous raise size or big blind
            local minRaise = math.max(BIG_BLIND, toCall)
            local raiseMax = myChips - toCall
            if raiseMax <= 0 then
                -- Can only call
            elseif raiseMax < minRaise then
                -- Can only all-in as a raise
                actions.allin = myChips
            else
                actions.raise = {min = toCall + minRaise, max = myChips}
                actions.allin = myChips
            end
        end
    end

    return actions
end

---Process an action from a seat
---@param seat number
---@param action string F/K/C/B/R/A
---@param amount number (optional, for B/R/A)
function G.ProcessAction(seat, action, amount)
    amount = tonumber(amount) or 0
    if game.folded[seat] or game.allIn[seat] then return end

    local oppSeat = (seat == G.SEAT_1) and G.SEAT_2 or G.SEAT_1
    local toCall = game.bets[oppSeat] - game.bets[seat]

    if action == "F" then
        -- Fold
        game.folded[seat] = true
        game.actedThisRound[seat] = true
        -- Opponent wins the pot
        G.CollectBets()
        G.AwardPot(oppSeat)
        return

    elseif action == "K" then
        -- Check
        game.actedThisRound[seat] = true

    elseif action == "C" then
        -- Call
        local callAmt = math.min(toCall, game.chips[seat])
        game.chips[seat] = game.chips[seat] - callAmt
        game.bets[seat] = game.bets[seat] + callAmt
        game.actedThisRound[seat] = true
        if game.chips[seat] == 0 then
            game.allIn[seat] = true
        end

    elseif action == "B" then
        -- Bet (when no bet is on the table)
        local betAmt = math.min(amount, game.chips[seat])
        game.chips[seat] = game.chips[seat] - betAmt
        game.bets[seat] = game.bets[seat] + betAmt
        game.actedThisRound[seat] = true
        game.actedThisRound[oppSeat] = false  -- opponent must respond
        game.lastRaiser = seat
        if game.chips[seat] == 0 then
            game.allIn[seat] = true
        end

    elseif action == "R" then
        -- Raise
        local totalPut = math.min(amount, game.chips[seat] + game.bets[seat])
        local addAmount = totalPut - game.bets[seat]
        addAmount = math.min(addAmount, game.chips[seat])
        game.chips[seat] = game.chips[seat] - addAmount
        game.bets[seat] = game.bets[seat] + addAmount
        game.actedThisRound[seat] = true
        game.actedThisRound[oppSeat] = false  -- opponent must respond
        game.lastRaiser = seat
        if game.chips[seat] == 0 then
            game.allIn[seat] = true
        end

    elseif action == "A" then
        -- All-in
        local allAmt = game.chips[seat]
        game.bets[seat] = game.bets[seat] + allAmt
        game.chips[seat] = 0
        game.allIn[seat] = true
        game.actedThisRound[seat] = true
        -- If all-in is a raise, opponent must respond
        if game.bets[seat] > game.bets[oppSeat] then
            game.actedThisRound[oppSeat] = false
            game.lastRaiser = seat
        end
    end

    -- Check if betting round is complete
    if G.IsBettingRoundComplete() then
        G.AdvancePhase()
    else
        -- Switch actor
        game.currentActor = oppSeat
        G.CancelActionTimeout()
        if game.currentActor == game.mySeat then
            G.StartActionTimeout()
        end
        if WowPoker.UI and WowPoker.UI.UpdateAll then
            WowPoker.UI.UpdateAll()
        end
    end
end

---Send my action to the opponent
function G.DoAction(action, amount)
    if game.currentActor ~= game.mySeat then return end
    amount = amount or 0

    G.CancelActionTimeout()

    -- Send to opponent
    P.Send(game.opponent, P.MSG.ACT, action, amount)

    -- Process locally
    G.ProcessAction(game.mySeat, action, amount)
end

---Check if the current betting round is complete
function G.IsBettingRoundComplete()
    -- If someone folded, yes
    if game.folded[G.SEAT_1] or game.folded[G.SEAT_2] then
        return true
    end

    -- Both must have acted
    if not game.actedThisRound[G.SEAT_1] or not game.actedThisRound[G.SEAT_2] then
        return false
    end

    -- Bets must be equal (or one is all-in)
    if game.bets[G.SEAT_1] == game.bets[G.SEAT_2] then
        return true
    end

    -- If one is all-in and other has acted, round complete
    if game.allIn[G.SEAT_1] or game.allIn[G.SEAT_2] then
        return true
    end

    return false
end

---Collect bets into pot and reset for next round
function G.CollectBets()
    game.pot = game.pot + game.bets[G.SEAT_1] + game.bets[G.SEAT_2]
    game.bets = {0, 0}
end

---Advance to the next phase
function G.AdvancePhase()
    G.CollectBets()
    G.CancelActionTimeout()

    local bothAllIn = game.allIn[G.SEAT_1] and game.allIn[G.SEAT_2]
    local oneAllIn = game.allIn[G.SEAT_1] or game.allIn[G.SEAT_2]

    if game.state == G.STATE.PREFLOP then
        game.state = G.STATE.FLOP
        if game.isHost then
            G.DealCommunity(3) -- Flop
        end
    elseif game.state == G.STATE.FLOP then
        game.state = G.STATE.TURN
        if game.isHost then
            G.DealCommunity(1) -- Turn
        end
    elseif game.state == G.STATE.TURN then
        game.state = G.STATE.RIVER
        if game.isHost then
            G.DealCommunity(1) -- River
        end
    elseif game.state == G.STATE.RIVER then
        game.state = G.STATE.SHOWDOWN
        G.DoShowdown()
        return
    end

    -- Reset acted flags for new round
    game.actedThisRound = {false, false}
    game.lastRaiser = 0

    -- If both all-in, no more betting, just run cards
    if bothAllIn or (oneAllIn and game.bets[G.SEAT_1] == game.bets[G.SEAT_2]) then
        -- Skip betting, auto-advance after a short delay
        if game.isHost then
            C_Timer.After(1.5, function()
                if game.state ~= G.STATE.SHOWDOWN and game.state ~= G.STATE.HAND_OVER and game.state ~= G.STATE.IDLE then
                    G.AdvancePhase()
                end
            end)
        end
    else
        -- Post-flop: non-dealer acts first
        local nonDealer = (game.dealerSeat == G.SEAT_1) and G.SEAT_2 or G.SEAT_1

        -- Skip all-in players
        if game.allIn[nonDealer] then
            game.currentActor = game.dealerSeat
            game.actedThisRound[nonDealer] = true
        elseif game.allIn[game.dealerSeat] then
            game.currentActor = nonDealer
            game.actedThisRound[game.dealerSeat] = true
        else
            game.currentActor = nonDealer
        end

        if game.currentActor == game.mySeat then
            G.StartActionTimeout()
        end
    end

    if WowPoker.UI and WowPoker.UI.UpdateAll then
        WowPoker.UI.UpdateAll()
    end
end

---Run out remaining board when both are all-in (host only)
function G.RunOutBoard()
    if not game.isHost then return end

    G.CollectBets()

    local function dealNextPhase()
        if game.state == G.STATE.PREFLOP then
            game.state = G.STATE.FLOP
            G.DealCommunity(3)
            C_Timer.After(1.5, dealNextPhase)
        elseif game.state == G.STATE.FLOP then
            game.state = G.STATE.TURN
            G.DealCommunity(1)
            C_Timer.After(1.5, dealNextPhase)
        elseif game.state == G.STATE.TURN then
            game.state = G.STATE.RIVER
            G.DealCommunity(1)
            C_Timer.After(1.5, dealNextPhase)
        elseif game.state == G.STATE.RIVER then
            game.state = G.STATE.SHOWDOWN
            G.DoShowdown()
        end
    end

    C_Timer.After(1.0, dealNextPhase)
end

---Deal community cards (host only)
function G.DealCommunity(count)
    if not game.isHost then return end

    D.Burn(game.deck)
    local cards = D.Deal(game.deck, count)

    -- Add to community
    for _, card in ipairs(cards) do
        game.community[#game.community + 1] = card
    end

    -- Build card strings for protocol
    local cardStrs = {}
    for _, card in ipairs(cards) do
        cardStrs[#cardStrs + 1] = D.CardToString(card)
    end

    -- Send to opponent
    P.Send(game.opponent, P.MSG.DEAL, game.state, unpack(cardStrs))

    if WowPoker.UI and WowPoker.UI.UpdateAll then
        WowPoker.UI.UpdateAll()
    end
end

---Handle receiving community cards (guest)
function G.OnReceiveCommunity(phase, cardStrs)
    -- Set state based on phase
    if phase == G.STATE.FLOP or phase == "FLOP" then
        game.state = G.STATE.FLOP
    elseif phase == G.STATE.TURN or phase == "TURN" then
        game.state = G.STATE.TURN
    elseif phase == G.STATE.RIVER or phase == "RIVER" then
        game.state = G.STATE.RIVER
    end

    -- Add cards to community
    for _, str in ipairs(cardStrs) do
        local card = D.StringToCard(str)
        if card then
            game.community[#game.community + 1] = card
        end
    end

    -- Reset acted flags for new round
    game.actedThisRound = {false, false}
    game.lastRaiser = 0

    -- Post-flop: non-dealer acts first
    local nonDealer = (game.dealerSeat == G.SEAT_1) and G.SEAT_2 or G.SEAT_1

    if game.allIn[nonDealer] then
        game.currentActor = game.dealerSeat
        game.actedThisRound[nonDealer] = true
    elseif game.allIn[game.dealerSeat] then
        game.currentActor = nonDealer
        game.actedThisRound[game.dealerSeat] = true
    else
        game.currentActor = nonDealer
    end

    if game.currentActor == game.mySeat then
        G.StartActionTimeout()
    end

    if WowPoker.UI and WowPoker.UI.UpdateAll then
        WowPoker.UI.UpdateAll()
    end
end

-- ==========================================
-- HAND EVALUATION
-- ==========================================

-- Hand rank constants
local HAND_HIGH_CARD      = 1
local HAND_PAIR           = 2
local HAND_TWO_PAIR       = 3
local HAND_THREE_KIND     = 4
local HAND_STRAIGHT       = 5
local HAND_FLUSH          = 6
local HAND_FULL_HOUSE     = 7
local HAND_FOUR_KIND      = 8
local HAND_STRAIGHT_FLUSH = 9
local HAND_ROYAL_FLUSH    = 10

local HAND_RANK_NAMES = {
    [1] = "HAND_HIGH_CARD",
    [2] = "HAND_PAIR",
    [3] = "HAND_TWO_PAIR",
    [4] = "HAND_THREE_KIND",
    [5] = "HAND_STRAIGHT",
    [6] = "HAND_FLUSH",
    [7] = "HAND_FULL_HOUSE",
    [8] = "HAND_FOUR_KIND",
    [9] = "HAND_STRAIGHT_FLUSH",
    [10] = "HAND_ROYAL_FLUSH",
}

---Get the localized name of a hand rank
function G.GetHandRankName(rank)
    local key = HAND_RANK_NAMES[rank]
    return key and L[key] or "?"
end

---Evaluate a 5-card hand, returns {rank, score}
---Score is rank * 1000000 + kicker values for tie-breaking
local function Evaluate5(cards)
    -- Sort by rank value descending
    local sorted = {}
    for i, c in ipairs(cards) do
        sorted[i] = {rank = D.RANK_VALUES[c.rank], suit = c.suit, origRank = c.rank}
    end
    table.sort(sorted, function(a, b) return a.rank > b.rank end)

    local ranks = {}
    local suits = {}
    for _, c in ipairs(sorted) do
        ranks[#ranks + 1] = c.rank
        suits[#suits + 1] = c.suit
    end

    -- Check flush
    local isFlush = (suits[1] == suits[2] and suits[2] == suits[3] and
                     suits[3] == suits[4] and suits[4] == suits[5])

    -- Check straight
    local isStraight = false
    local straightHigh = 0
    -- Normal straight
    if ranks[1] - ranks[2] == 1 and ranks[2] - ranks[3] == 1 and
       ranks[3] - ranks[4] == 1 and ranks[4] - ranks[5] == 1 then
        isStraight = true
        straightHigh = ranks[1]
    end
    -- Wheel (A-2-3-4-5): A is 14, so sorted would be 14,5,4,3,2
    if not isStraight and ranks[1] == 14 and ranks[2] == 5 and ranks[3] == 4 and
       ranks[4] == 3 and ranks[5] == 2 then
        isStraight = true
        straightHigh = 5  -- 5-high straight
    end

    -- Count rank occurrences
    local counts = {}
    for _, r in ipairs(ranks) do
        counts[r] = (counts[r] or 0) + 1
    end

    -- Group by count
    local quads, trips, pairs, singles = {}, {}, {}, {}
    for r, c in pairs(counts) do
        if c == 4 then quads[#quads + 1] = r
        elseif c == 3 then trips[#trips + 1] = r
        elseif c == 2 then pairs[#pairs + 1] = r
        else singles[#singles + 1] = r
        end
    end
    table.sort(quads, function(a,b) return a > b end)
    table.sort(trips, function(a,b) return a > b end)
    table.sort(pairs, function(a,b) return a > b end)
    table.sort(singles, function(a,b) return a > b end)

    local handRank, score

    if isFlush and isStraight then
        if straightHigh == 14 then
            handRank = HAND_ROYAL_FLUSH
            score = HAND_ROYAL_FLUSH * 1000000 + 14
        else
            handRank = HAND_STRAIGHT_FLUSH
            score = HAND_STRAIGHT_FLUSH * 1000000 + straightHigh
        end
    elseif #quads > 0 then
        handRank = HAND_FOUR_KIND
        score = HAND_FOUR_KIND * 1000000 + quads[1] * 100 + (singles[1] or 0)
    elseif #trips > 0 and #pairs > 0 then
        handRank = HAND_FULL_HOUSE
        score = HAND_FULL_HOUSE * 1000000 + trips[1] * 100 + pairs[1]
    elseif isFlush then
        handRank = HAND_FLUSH
        score = HAND_FLUSH * 1000000 + ranks[1] * 10000 + ranks[2] * 1000 +
                ranks[3] * 100 + ranks[4] * 10 + ranks[5]
    elseif isStraight then
        handRank = HAND_STRAIGHT
        score = HAND_STRAIGHT * 1000000 + straightHigh
    elseif #trips > 0 then
        handRank = HAND_THREE_KIND
        score = HAND_THREE_KIND * 1000000 + trips[1] * 10000 +
                (singles[1] or 0) * 100 + (singles[2] or 0)
    elseif #pairs >= 2 then
        handRank = HAND_TWO_PAIR
        score = HAND_TWO_PAIR * 1000000 + pairs[1] * 10000 + pairs[2] * 100 +
                (singles[1] or 0)
    elseif #pairs == 1 then
        handRank = HAND_PAIR
        score = HAND_PAIR * 1000000 + pairs[1] * 10000 +
                (singles[1] or 0) * 100 + (singles[2] or 0) * 10 + (singles[3] or 0)
    else
        handRank = HAND_HIGH_CARD
        score = HAND_HIGH_CARD * 1000000 + ranks[1] * 10000 + ranks[2] * 1000 +
                ranks[3] * 100 + ranks[4] * 10 + ranks[5]
    end

    return handRank, score
end

---Generate all C(n,5) combinations from n cards
local function Combinations5(cards)
    local combos = {}
    local n = #cards
    for i = 1, n - 4 do
        for j = i + 1, n - 3 do
            for k = j + 1, n - 2 do
                for l = k + 1, n - 1 do
                    for m = l + 1, n do
                        combos[#combos + 1] = {cards[i], cards[j], cards[k], cards[l], cards[m]}
                    end
                end
            end
        end
    end
    return combos
end

---Evaluate the best 5-card hand from 7 cards (2 hole + 5 community)
---@param holeCards table
---@param community table
---@return number handRank
---@return number score
function G.EvaluateHand(holeCards, community)
    -- Combine hole + community
    local all = {}
    for _, c in ipairs(holeCards) do all[#all + 1] = c end
    for _, c in ipairs(community) do all[#all + 1] = c end

    local combos = Combinations5(all)
    local bestRank = 0
    local bestScore = 0

    for _, combo in ipairs(combos) do
        local rank, score = Evaluate5(combo)
        if score > bestScore then
            bestRank = rank
            bestScore = score
        end
    end

    return bestRank, bestScore
end

-- ==========================================
-- SHOWDOWN
-- ==========================================

---Perform showdown (host only evaluates and sends result)
function G.DoShowdown()
    game.state = G.STATE.SHOWDOWN

    if not game.isHost then
        if WowPoker.UI and WowPoker.UI.UpdateAll then
            WowPoker.UI.UpdateAll()
        end
        return
    end

    -- Send host's cards to opponent for showdown reveal
    local myCards = game.holeCards[game.mySeat]
    P.Send(game.opponent, P.MSG.SD,
           D.CardToString(myCards[1]), D.CardToString(myCards[2]))

    -- Evaluate both hands
    local rank1, score1 = G.EvaluateHand(game.holeCards[G.SEAT_1], game.community)
    local rank2, score2 = G.EvaluateHand(game.holeCards[G.SEAT_2], game.community)

    local winnerSeat
    if score1 > score2 then
        winnerSeat = G.SEAT_1
    elseif score2 > score1 then
        winnerSeat = G.SEAT_2
    else
        winnerSeat = 0  -- tie
    end

    local winRank = (winnerSeat == G.SEAT_1) and rank1 or rank2
    if winnerSeat == 0 then winRank = rank1 end  -- same rank on tie

    -- Send result
    P.Send(game.opponent, P.MSG.RES, winnerSeat, winRank, game.pot)

    -- Apply result locally
    G.ApplyResult(winnerSeat, winRank, game.pot)
end

---Award pot to winner (on fold)
function G.AwardPot(winnerSeat)
    game.state = G.STATE.HAND_OVER
    game.chips[winnerSeat] = game.chips[winnerSeat] + game.pot

    local winnerName
    if winnerSeat == game.mySeat then
        winnerName = UnitName("player")
    else
        winnerName = game.opponent
    end
    G.PrintMessage(string.format(L["GAME_WINS_POT"], winnerName, game.pot))

    -- Update stats
    G.UpdateBiggestPot(game.pot)
    game.pot = 0

    if WowPoker.UI and WowPoker.UI.UpdateAll then
        WowPoker.UI.UpdateAll()
    end

    -- Check for game over
    if game.chips[G.SEAT_1] <= 0 or game.chips[G.SEAT_2] <= 0 then
        G.GameOver()
    else
        -- Next hand after delay (host starts)
        if game.isHost then
            C_Timer.After(3, function()
                if game.state == G.STATE.HAND_OVER then
                    G.StartNewHand()
                end
            end)
        end
    end
end

---Apply showdown result
function G.ApplyResult(winnerSeat, handRank, pot)
    game.state = G.STATE.HAND_OVER

    if winnerSeat == 0 then
        -- Tie: split pot
        local half = math.floor(pot / 2)
        game.chips[G.SEAT_1] = game.chips[G.SEAT_1] + half
        game.chips[G.SEAT_2] = game.chips[G.SEAT_2] + (pot - half)
        G.PrintMessage(L["GAME_SPLIT_POT"])
    else
        game.chips[winnerSeat] = game.chips[winnerSeat] + pot
        local winnerName
        if winnerSeat == game.mySeat then
            winnerName = UnitName("player")
        else
            winnerName = game.opponent
        end
        local rankName = G.GetHandRankName(handRank)
        G.PrintMessage(string.format(L["GAME_WINS_POT"], winnerName, pot) .. " (" .. rankName .. ")")
    end

    G.UpdateBiggestPot(pot)
    game.pot = 0

    if WowPoker.UI and WowPoker.UI.UpdateAll then
        WowPoker.UI.UpdateAll()
    end

    -- Check for game over
    if game.chips[G.SEAT_1] <= 0 or game.chips[G.SEAT_2] <= 0 then
        G.GameOver()
    else
        -- Next hand after delay (host starts)
        if game.isHost then
            C_Timer.After(3, function()
                if game.state == G.STATE.HAND_OVER then
                    G.StartNewHand()
                end
            end)
        end
    end
end

-- ==========================================
-- GAME OVER / QUIT
-- ==========================================

function G.GameOver()
    game.state = G.STATE.IDLE

    local iWon = game.chips[game.mySeat] > 0
    if iWon then
        G.PrintMessage(L["GAME_OVER_WIN"])
        G.RecordWin()
    else
        G.PrintMessage(string.format(L["GAME_OVER_LOSE"], game.opponent))
        G.RecordLoss()
    end

    G.StopHeartbeat()

    if WowPoker.UI and WowPoker.UI.UpdateAll then
        WowPoker.UI.UpdateAll()
    end
end

function G.QuitGame()
    if game.state == G.STATE.IDLE then return end

    if game.opponent then
        P.Send(game.opponent, P.MSG.QUIT)
    end

    G.RecordLoss()
    G.ResetGame()
end

function G.OnOpponentQuit()
    G.PrintMessage(string.format(L["GAME_OPPONENT_QUIT"], game.opponent or "?"))
    G.RecordWin()
    G.ResetGame()
end

function G.ResetGame()
    G.CancelInviteTimeout()
    G.CancelActionTimeout()
    G.StopHeartbeat()

    game.state = G.STATE.IDLE
    game.opponent = nil
    game.isHost = false
    game.mySeat = 0
    game.handNumber = 0
    game.dealerSeat = 0
    game.deck = nil
    game.holeCards = {{}, {}}
    game.community = {}
    game.pot = 0
    game.bets = {0, 0}
    game.chips = {0, 0}
    game.folded = {false, false}
    game.allIn = {false, false}
    game.actedThisRound = {false, false}
    game.currentActor = 0
    game.lastRaiser = 0
    game.pendingInviteFrom = nil
    game.missedPongs = 0

    if WowPoker.UI and WowPoker.UI.UpdateAll then
        WowPoker.UI.UpdateAll()
    end
end

-- ==========================================
-- TIMERS
-- ==========================================

function G.StartInviteTimeout()
    G.CancelInviteTimeout()
    game.inviteTimer = C_Timer.NewTimer(30, function()
        if game.state == G.STATE.WAITING_ACCEPT then
            G.PrintMessage(L["INVITE_TIMEOUT"])
            G.ResetGame()
        end
        if game.pendingInviteFrom then
            G.PrintMessage(L["INVITE_TIMEOUT"])
            game.pendingInviteFrom = nil
            if WowPoker.UI and WowPoker.UI.HideInvitePopup then
                WowPoker.UI.HideInvitePopup()
            end
        end
    end)
end

function G.CancelInviteTimeout()
    if game.inviteTimer then
        game.inviteTimer:Cancel()
        game.inviteTimer = nil
    end
end

function G.StartActionTimeout()
    G.CancelActionTimeout()
    game.actionTimer = C_Timer.NewTimer(60, function()
        if game.currentActor == game.mySeat and game.state ~= G.STATE.IDLE and
           game.state ~= G.STATE.HAND_OVER and game.state ~= G.STATE.SHOWDOWN then
            G.PrintMessage(L["GAME_ACTION_TIMEOUT"])
            G.DoAction("F", 0)
        end
    end)
end

function G.CancelActionTimeout()
    if game.actionTimer then
        game.actionTimer:Cancel()
        game.actionTimer = nil
    end
end

-- ==========================================
-- HEARTBEAT
-- ==========================================

function G.StartHeartbeat()
    G.StopHeartbeat()
    game.missedPongs = 0
    game.pingTimer = C_Timer.NewTicker(15, function()
        if game.state == G.STATE.IDLE then
            G.StopHeartbeat()
            return
        end
        if game.opponent then
            game.missedPongs = game.missedPongs + 1
            P.Send(game.opponent, P.MSG.PING)
            if game.missedPongs >= 3 then
                G.PrintMessage(string.format(L["GAME_DISCONNECT"], game.opponent))
                G.RecordWin()
                G.ResetGame()
            end
        end
    end)
end

function G.StopHeartbeat()
    if game.pingTimer then
        game.pingTimer:Cancel()
        game.pingTimer = nil
    end
end

function G.OnPong()
    game.missedPongs = 0
end

-- ==========================================
-- STATS
-- ==========================================

function G.RecordWin()
    if WowPokerDB and WowPokerDB.stats then
        WowPokerDB.stats.gamesPlayed = WowPokerDB.stats.gamesPlayed + 1
        WowPokerDB.stats.gamesWon = WowPokerDB.stats.gamesWon + 1
    end
end

function G.RecordLoss()
    if WowPokerDB and WowPokerDB.stats then
        WowPokerDB.stats.gamesPlayed = WowPokerDB.stats.gamesPlayed + 1
        WowPokerDB.stats.gamesLost = WowPokerDB.stats.gamesLost + 1
    end
end

function G.UpdateBiggestPot(pot)
    if WowPokerDB and WowPokerDB.stats then
        if pot > WowPokerDB.stats.biggestPot then
            WowPokerDB.stats.biggestPot = pot
        end
    end
end

function G.ShowStats()
    if not WowPokerDB or not WowPokerDB.stats then return end
    local s = WowPokerDB.stats
    G.PrintMessage(L["STATS_TITLE"])
    G.PrintMessage(string.format(L["STATS_PLAYED"], s.gamesPlayed))
    G.PrintMessage(string.format(L["STATS_WON"], s.gamesWon))
    G.PrintMessage(string.format(L["STATS_LOST"], s.gamesLost))
    G.PrintMessage(string.format(L["STATS_BIGGEST_POT"], s.biggestPot))
end

-- ==========================================
-- UTILITY
-- ==========================================

function G.PrintMessage(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00CC66[WowPoker]|r " .. msg)
end

---Get phase display name
function G.GetPhaseLabel()
    local stateToKey = {
        [G.STATE.PREFLOP] = "PHASE_PREFLOP",
        [G.STATE.FLOP] = "PHASE_FLOP",
        [G.STATE.TURN] = "PHASE_TURN",
        [G.STATE.RIVER] = "PHASE_RIVER",
        [G.STATE.SHOWDOWN] = "PHASE_SHOWDOWN",
    }
    local key = stateToKey[game.state]
    return key and L[key] or ""
end
