local CT = {}
WowPoker.CardTextures = CT

local D = WowPoker.Deck

local CARD_WIDTH = 60
local CARD_HEIGHT = 84

CT.CARD_WIDTH = CARD_WIDTH
CT.CARD_HEIGHT = CARD_HEIGHT

local CARD_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = {left = 1, right = 1, top = 1, bottom = 1},
}

local CARD_BACK_COLOR = {0.1, 0.1, 0.4, 1}       -- Dark blue
local CARD_FACE_COLOR = {0.98, 0.96, 0.90, 1}     -- Cream/white
local CARD_BORDER_COLOR = {0.3, 0.3, 0.3, 1}      -- Gray border
local CARD_BACK_BORDER_COLOR = {0.05, 0.05, 0.25, 1}

---Create a card frame
---@param parent frame
---@param name string|nil
---@return frame cardFrame
function CT.CreateCard(parent, name)
    local card = CreateFrame("Frame", name, parent, "BackdropTemplate")
    card:SetSize(CARD_WIDTH, CARD_HEIGHT)
    card:SetBackdrop(CARD_BACKDROP)
    card:SetBackdropColor(unpack(CARD_FACE_COLOR))
    card:SetBackdropBorderColor(unpack(CARD_BORDER_COLOR))

    -- Center rank (large)
    card.centerRank = card:CreateFontString(nil, "OVERLAY")
    card.centerRank:SetFont("Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
    card.centerRank:SetPoint("CENTER", card, "CENTER", 0, 8)

    -- Center suit symbol
    card.centerSuit = card:CreateFontString(nil, "OVERLAY")
    card.centerSuit:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
    card.centerSuit:SetPoint("CENTER", card, "CENTER", 0, -12)

    -- Top-left corner: rank
    card.topRank = card:CreateFontString(nil, "OVERLAY")
    card.topRank:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    card.topRank:SetPoint("TOPLEFT", card, "TOPLEFT", 4, -3)

    -- Top-left corner: suit
    card.topSuit = card:CreateFontString(nil, "OVERLAY")
    card.topSuit:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    card.topSuit:SetPoint("TOPLEFT", card, "TOPLEFT", 4, -15)

    -- Bottom-right corner: rank (rotated via positioning)
    card.bottomRank = card:CreateFontString(nil, "OVERLAY")
    card.bottomRank:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    card.bottomRank:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -4, 14)

    -- Bottom-right corner: suit
    card.bottomSuit = card:CreateFontString(nil, "OVERLAY")
    card.bottomSuit:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    card.bottomSuit:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -4, 3)

    -- Back overlay (for face-down cards)
    card.backOverlay = card:CreateTexture(nil, "OVERLAY")
    card.backOverlay:SetAllPoints()
    card.backOverlay:SetColorTexture(CARD_BACK_COLOR[1], CARD_BACK_COLOR[2],
                                      CARD_BACK_COLOR[3], CARD_BACK_COLOR[4])
    card.backOverlay:Hide()

    -- Back pattern (decorative lines)
    card.backPattern = card:CreateFontString(nil, "OVERLAY", nil, 2)
    card.backPattern:SetFont("Fonts\\FRIZQT__.TTF", 28, "OUTLINE")
    card.backPattern:SetPoint("CENTER")
    card.backPattern:SetText("WP")
    card.backPattern:SetTextColor(0.2, 0.2, 0.6, 0.8)
    card.backPattern:Hide()

    card.isShowing = false
    card.isFaceDown = false
    card:Hide()

    return card
end

---Show a card face-up
---@param cardFrame frame
---@param cardStr string e.g., "Ah"
function CT.ShowCard(cardFrame, cardStr)
    if not cardFrame or not cardStr then return end

    local card = D.StringToCard(cardStr)
    if not card then return end

    local rankDisplay = D.RANK_DISPLAY[card.rank] or card.rank
    local suitSymbol = D.SUIT_SYMBOLS[card.suit] or card.suit
    local color = D.SUIT_COLORS[card.suit] or {0, 0, 0}

    -- Set center
    cardFrame.centerRank:SetText(rankDisplay)
    cardFrame.centerRank:SetTextColor(color[1], color[2], color[3])
    cardFrame.centerSuit:SetText(suitSymbol)
    cardFrame.centerSuit:SetTextColor(color[1], color[2], color[3])

    -- Set corners
    cardFrame.topRank:SetText(rankDisplay)
    cardFrame.topRank:SetTextColor(color[1], color[2], color[3])
    cardFrame.topSuit:SetText(suitSymbol)
    cardFrame.topSuit:SetTextColor(color[1], color[2], color[3])
    cardFrame.bottomRank:SetText(rankDisplay)
    cardFrame.bottomRank:SetTextColor(color[1], color[2], color[3])
    cardFrame.bottomSuit:SetText(suitSymbol)
    cardFrame.bottomSuit:SetTextColor(color[1], color[2], color[3])

    -- Show all text, hide back
    cardFrame.centerRank:Show()
    cardFrame.centerSuit:Show()
    cardFrame.topRank:Show()
    cardFrame.topSuit:Show()
    cardFrame.bottomRank:Show()
    cardFrame.bottomSuit:Show()
    cardFrame.backOverlay:Hide()
    cardFrame.backPattern:Hide()

    cardFrame:SetBackdropColor(unpack(CARD_FACE_COLOR))
    cardFrame:SetBackdropBorderColor(unpack(CARD_BORDER_COLOR))

    cardFrame.isShowing = true
    cardFrame.isFaceDown = false
    cardFrame:Show()
end

---Show a card face-down (back of card)
---@param cardFrame frame
function CT.ShowFaceDown(cardFrame)
    if not cardFrame then return end

    -- Hide all text
    cardFrame.centerRank:Hide()
    cardFrame.centerSuit:Hide()
    cardFrame.topRank:Hide()
    cardFrame.topSuit:Hide()
    cardFrame.bottomRank:Hide()
    cardFrame.bottomSuit:Hide()

    -- Show back
    cardFrame.backOverlay:Show()
    cardFrame.backPattern:Show()

    cardFrame:SetBackdropColor(unpack(CARD_BACK_COLOR))
    cardFrame:SetBackdropBorderColor(unpack(CARD_BACK_BORDER_COLOR))

    cardFrame.isShowing = true
    cardFrame.isFaceDown = true
    cardFrame:Show()
end

---Hide a card completely
---@param cardFrame frame
function CT.HideCard(cardFrame)
    if not cardFrame then return end
    cardFrame.isShowing = false
    cardFrame.isFaceDown = false
    cardFrame:Hide()
end
