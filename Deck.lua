local D = {}
WowPoker.Deck = D

local RANKS = {"2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K", "A"}
local SUITS = {"h", "d", "c", "s"}

-- Rank values for evaluation
D.RANK_VALUES = {
    ["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5, ["6"] = 6,
    ["7"] = 7, ["8"] = 8, ["9"] = 9, ["T"] = 10, ["J"] = 11,
    ["Q"] = 12, ["K"] = 13, ["A"] = 14,
}

-- Display names
D.RANK_DISPLAY = {
    ["2"] = "2", ["3"] = "3", ["4"] = "4", ["5"] = "5", ["6"] = "6",
    ["7"] = "7", ["8"] = "8", ["9"] = "9", ["T"] = "10", ["J"] = "J",
    ["Q"] = "Q", ["K"] = "K", ["A"] = "A",
}

D.SUIT_SYMBOLS = {
    ["h"] = "\226\153\165", -- ♥
    ["d"] = "\226\153\166", -- ♦
    ["c"] = "\226\153\163", -- ♣
    ["s"] = "\226\153\160", -- ♠
}

D.SUIT_COLORS = {
    ["h"] = {1, 0, 0},     -- red
    ["d"] = {1, 0, 0},     -- red
    ["c"] = {0, 0, 0},     -- black
    ["s"] = {0, 0, 0},     -- black
}

---Create a new deck instance
---@return table deck
function D.New()
    local deck = {
        cards = {},
        index = 1,
    }

    -- Build 52 cards
    for _, suit in ipairs(SUITS) do
        for _, rank in ipairs(RANKS) do
            deck.cards[#deck.cards + 1] = {rank = rank, suit = suit}
        end
    end

    return deck
end

---Shuffle the deck using Fisher-Yates algorithm
---@param deck table
function D.Shuffle(deck)
    local cards = deck.cards
    local n = #cards
    for i = n, 2, -1 do
        local j = math.random(1, i)
        cards[i], cards[j] = cards[j], cards[i]
    end
    deck.index = 1
end

---Deal a number of cards from the deck
---@param deck table
---@param count number
---@return table cards
function D.Deal(deck, count)
    local dealt = {}
    for i = 1, count do
        if deck.index <= #deck.cards then
            dealt[#dealt + 1] = deck.cards[deck.index]
            deck.index = deck.index + 1
        end
    end
    return dealt
end

---Burn one card from the top (discard)
---@param deck table
function D.Burn(deck)
    if deck.index <= #deck.cards then
        deck.index = deck.index + 1
    end
end

---Convert a card table to a 2-char string (e.g., "Ah")
---@param card table {rank, suit}
---@return string
function D.CardToString(card)
    return card.rank .. card.suit
end

---Convert a 2-char string to a card table
---@param str string e.g., "Ah"
---@return table card {rank, suit}
function D.StringToCard(str)
    if not str or #str < 2 then return nil end
    return {rank = str:sub(1, 1), suit = str:sub(2, 2)}
end

---Convert an array of card tables to a colon-separated string
---@param cards table Array of {rank, suit}
---@return string
function D.CardsToString(cards)
    local strs = {}
    for _, card in ipairs(cards) do
        strs[#strs + 1] = D.CardToString(card)
    end
    return table.concat(strs, ":")
end

---Convert a list of card strings to card tables
---@param strings table Array of 2-char strings
---@return table cards
function D.StringsToCards(strings)
    local cards = {}
    for _, str in ipairs(strings) do
        local card = D.StringToCard(str)
        if card then
            cards[#cards + 1] = card
        end
    end
    return cards
end

---Get the display string for a card (e.g., "A♥")
---@param card table {rank, suit}
---@return string
function D.CardDisplayString(card)
    return D.RANK_DISPLAY[card.rank] .. D.SUIT_SYMBOLS[card.suit]
end
