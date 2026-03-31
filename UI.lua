local UI = {}
WowPoker.UI = UI

local G = WowPoker.Game
local CT = WowPoker.CardTextures
local D = WowPoker.Deck
local L = WowPoker.L

-- Main frame dimensions
local FRAME_WIDTH = 800
local FRAME_HEIGHT = 500

local TABLE_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 2,
    insets = {left = 2, right = 2, top = 2, bottom = 2},
}

local TITLE_BAR_HEIGHT = 24
local ACTION_BAR_HEIGHT = 50
local STATUS_BAR_HEIGHT = 20

-- Frame references
local mainFrame
local titleBar, titleText, closeButton
local oppNameText, oppChipsText, oppBetText, oppDealerBadge
local oppCards = {}
local communityCards = {}
local potText, phaseText
local myNameText, myChipsText, myBetText, myDealerBadge
local myCards = {}
local actionBar
local btnFold, btnCheck, btnCall, btnBet, btnRaise, btnAllIn
local betSlider, betSliderText
local statusText
local invitePopup
local minimapButton

-- ==========================================
-- MINIMAP BUTTON
-- ==========================================

function UI.CreateMinimapButton()
    if minimapButton then return end

    local BUTTON_SIZE = 32
    local savedAngle = WowPokerDB and WowPokerDB.minimapAngle or 225

    minimapButton = CreateFrame("Button", "WowPokerMinimapButton", Minimap)
    minimapButton:SetSize(32, 32)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(8)
    minimapButton:SetMovable(true)
    minimapButton:SetClampedToScreen(true)
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapButton:RegisterForDrag("LeftButton")

    -- Border (same as NodeCounter)
    local overlay = minimapButton:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")

    -- Custom ace of diamonds icon
    local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexture("Interface\\AddOns\\WowPoker\\textures\\minimap-icon")

    -- Highlight (same as NodeCounter)
    local highlight = minimapButton:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(24, 24)
    highlight:SetPoint("CENTER")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")

    -- Position around minimap
    local function UpdatePosition(angle)
        local radius = 80
        local x = math.cos(math.rad(angle)) * radius
        local y = math.sin(math.rad(angle)) * radius
        minimapButton:ClearAllPoints()
        minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    UpdatePosition(savedAngle)

    -- Drag to reposition around minimap
    local isDragging = false
    minimapButton:SetScript("OnDragStart", function()
        isDragging = true
    end)

    minimapButton:SetScript("OnDragStop", function()
        isDragging = false
    end)

    minimapButton:SetScript("OnUpdate", function()
        if not isDragging then return end
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        local angle = math.deg(math.atan2(cy - my, cx - mx))
        UpdatePosition(angle)
        if WowPokerDB then
            WowPokerDB.minimapAngle = angle
        end
    end)

    -- Click handlers
    minimapButton:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            UI.Toggle()
        elseif button == "RightButton" then
            WowPoker.Game.ShowStats()
        end
    end)

    -- Tooltip
    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cFFFFD700WowPoker|r")
        GameTooltip:AddLine(L["HELP_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Left-click", "Toggle table", 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddDoubleLine("Right-click", "Stats", 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddDoubleLine("Drag", "Move button", 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:Show()
    end)

    minimapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- ==========================================
-- MAIN FRAME
-- ==========================================

function UI.CreateMainFrame()
    if mainFrame then return end

    mainFrame = CreateFrame("Frame", "WowPokerMainFrame", UIParent, "BackdropTemplate")
    mainFrame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetBackdrop(TABLE_BACKDROP)
    mainFrame:SetBackdropColor(0.1, 0.35, 0.1, 0.95)  -- Dark green felt
    mainFrame:SetBackdropBorderColor(0.3, 0.2, 0.1, 1) -- Brown border
    mainFrame:SetFrameStrata("HIGH")
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:SetClampedToScreen(true)
    mainFrame:Hide()

    -- Title bar
    titleBar = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    titleBar:SetSize(FRAME_WIDTH, TITLE_BAR_HEIGHT)
    titleBar:SetPoint("TOP", mainFrame, "TOP", 0, 0)
    titleBar:SetBackdrop(TABLE_BACKDROP)
    titleBar:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
    titleBar:SetBackdropBorderColor(0.3, 0.2, 0.1, 1)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() mainFrame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() mainFrame:StopMovingOrSizing() end)

    titleText = titleBar:CreateFontString(nil, "OVERLAY")
    titleText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    titleText:SetText("|cFFFFD700WowPoker|r - Texas Hold'em")

    closeButton = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeButton:SetPoint("RIGHT", titleBar, "RIGHT", -2, 0)
    closeButton:SetScript("OnClick", function()
        UI.Hide()
    end)

    -- ==========================================
    -- OPPONENT ZONE (top area)
    -- ==========================================
    local oppZone = CreateFrame("Frame", nil, mainFrame)
    oppZone:SetSize(FRAME_WIDTH - 40, 100)
    oppZone:SetPoint("TOP", mainFrame, "TOP", 0, -TITLE_BAR_HEIGHT - 10)

    oppNameText = oppZone:CreateFontString(nil, "OVERLAY")
    oppNameText:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    oppNameText:SetPoint("LEFT", oppZone, "LEFT", 20, 20)
    oppNameText:SetTextColor(1, 0.8, 0)

    oppChipsText = oppZone:CreateFontString(nil, "OVERLAY")
    oppChipsText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    oppChipsText:SetPoint("LEFT", oppZone, "LEFT", 20, 0)
    oppChipsText:SetTextColor(1, 1, 1)

    oppBetText = oppZone:CreateFontString(nil, "OVERLAY")
    oppBetText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    oppBetText:SetPoint("LEFT", oppZone, "LEFT", 20, -20)
    oppBetText:SetTextColor(1, 0.85, 0)

    oppDealerBadge = oppZone:CreateFontString(nil, "OVERLAY")
    oppDealerBadge:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    oppDealerBadge:SetPoint("LEFT", oppZone, "LEFT", 160, 20)
    oppDealerBadge:SetText("|cFFFFFFFF[" .. L["DEALER"] .. "]|r")
    oppDealerBadge:Hide()

    -- Opponent cards (face down)
    for i = 1, 2 do
        oppCards[i] = CT.CreateCard(oppZone, "WowPokerOppCard" .. i)
        oppCards[i]:SetPoint("CENTER", oppZone, "CENTER", (i - 1.5) * 70, 0)
    end

    -- ==========================================
    -- COMMUNITY ZONE (center)
    -- ==========================================
    local comZone = CreateFrame("Frame", nil, mainFrame)
    comZone:SetSize(FRAME_WIDTH - 40, 120)
    comZone:SetPoint("CENTER", mainFrame, "CENTER", 0, 10)

    -- Pot display
    potText = comZone:CreateFontString(nil, "OVERLAY")
    potText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    potText:SetPoint("TOP", comZone, "TOP", 0, 5)
    potText:SetTextColor(1, 0.84, 0)

    -- Phase label
    phaseText = comZone:CreateFontString(nil, "OVERLAY")
    phaseText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    phaseText:SetPoint("TOP", comZone, "TOP", 0, -18)
    phaseText:SetTextColor(0.8, 0.8, 0.8)

    -- 5 community card slots
    for i = 1, 5 do
        communityCards[i] = CT.CreateCard(comZone, "WowPokerComCard" .. i)
        communityCards[i]:SetPoint("CENTER", comZone, "CENTER", (i - 3) * 70, -10)
    end

    -- ==========================================
    -- PLAYER ZONE (bottom area)
    -- ==========================================
    local myZone = CreateFrame("Frame", nil, mainFrame)
    myZone:SetSize(FRAME_WIDTH - 40, 100)
    myZone:SetPoint("BOTTOM", mainFrame, "BOTTOM", 0,
                     ACTION_BAR_HEIGHT + STATUS_BAR_HEIGHT + 10)

    myNameText = myZone:CreateFontString(nil, "OVERLAY")
    myNameText:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    myNameText:SetPoint("LEFT", myZone, "LEFT", 20, 20)
    myNameText:SetTextColor(0.3, 1, 0.3)

    myChipsText = myZone:CreateFontString(nil, "OVERLAY")
    myChipsText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    myChipsText:SetPoint("LEFT", myZone, "LEFT", 20, 0)
    myChipsText:SetTextColor(1, 1, 1)

    myBetText = myZone:CreateFontString(nil, "OVERLAY")
    myBetText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    myBetText:SetPoint("LEFT", myZone, "LEFT", 20, -20)
    myBetText:SetTextColor(1, 0.85, 0)

    myDealerBadge = myZone:CreateFontString(nil, "OVERLAY")
    myDealerBadge:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    myDealerBadge:SetPoint("LEFT", myZone, "LEFT", 160, 20)
    myDealerBadge:SetText("|cFFFFFFFF[" .. L["DEALER"] .. "]|r")
    myDealerBadge:Hide()

    -- Player cards (face up)
    for i = 1, 2 do
        myCards[i] = CT.CreateCard(myZone, "WowPokerMyCard" .. i)
        myCards[i]:SetPoint("CENTER", myZone, "CENTER", (i - 1.5) * 70, 0)
    end

    -- ==========================================
    -- STATUS BAR
    -- ==========================================
    statusText = mainFrame:CreateFontString(nil, "OVERLAY")
    statusText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    statusText:SetPoint("BOTTOM", mainFrame, "BOTTOM",
                         0, ACTION_BAR_HEIGHT + 3)
    statusText:SetTextColor(1, 1, 0)

    -- ==========================================
    -- ACTION BAR
    -- ==========================================
    actionBar = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    actionBar:SetSize(FRAME_WIDTH, ACTION_BAR_HEIGHT)
    actionBar:SetPoint("BOTTOM", mainFrame, "BOTTOM", 0, 0)
    actionBar:SetBackdrop(TABLE_BACKDROP)
    actionBar:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    actionBar:SetBackdropBorderColor(0.3, 0.2, 0.1, 1)

    local btnWidth = 80
    local btnHeight = 28
    local btnY = 12
    local startX = -280

    local function MakeActionButton(label, xOff)
        local btn = CreateFrame("Button", nil, actionBar, "UIPanelButtonTemplate")
        btn:SetSize(btnWidth, btnHeight)
        btn:SetPoint("BOTTOM", actionBar, "BOTTOM", xOff, btnY)
        btn:SetText(label)
        btn:Disable()
        return btn
    end

    btnFold  = MakeActionButton(L["ACTION_FOLD"],  startX)
    btnCheck = MakeActionButton(L["ACTION_CHECK"], startX + 90)
    btnCall  = MakeActionButton(L["ACTION_CALL"],  startX + 180)
    btnBet   = MakeActionButton(L["ACTION_BET"],   startX + 270)
    btnRaise = MakeActionButton(L["ACTION_RAISE"], startX + 360)
    btnAllIn = MakeActionButton(L["ACTION_ALLIN"], startX + 450)

    -- Bet/Raise slider
    betSlider = CreateFrame("Slider", "WowPokerBetSlider", actionBar, "OptionsSliderTemplate")
    betSlider:SetSize(120, 16)
    betSlider:SetPoint("BOTTOM", actionBar, "BOTTOM", startX + 560, btnY + 6)
    betSlider:SetMinMaxValues(20, 1000)
    betSlider:SetValueStep(10)
    betSlider:SetObeyStepOnDrag(true)
    betSlider:SetValue(20)
    betSlider:Hide()

    -- Remove default slider text
    local sliderName = betSlider:GetName()
    if sliderName then
        local low = _G[sliderName .. "Low"]
        local high = _G[sliderName .. "High"]
        local text = _G[sliderName .. "Text"]
        if low then low:SetText("") end
        if high then high:SetText("") end
        if text then text:SetText("") end
    end

    betSliderText = actionBar:CreateFontString(nil, "OVERLAY")
    betSliderText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    betSliderText:SetPoint("BOTTOM", betSlider, "TOP", 0, 2)
    betSliderText:SetTextColor(1, 1, 1)
    betSliderText:Hide()

    betSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / 10) * 10  -- Round to nearest 10
        betSliderText:SetText(L["BET_AMOUNT"] .. ": " .. value)
    end)

    -- Button click handlers
    btnFold:SetScript("OnClick", function()
        G.DoAction("F", 0)
    end)

    btnCheck:SetScript("OnClick", function()
        G.DoAction("K", 0)
    end)

    btnCall:SetScript("OnClick", function()
        G.DoAction("C", 0)
    end)

    btnBet:SetScript("OnClick", function()
        local amount = math.floor(betSlider:GetValue() / 10) * 10
        G.DoAction("B", amount)
    end)

    btnRaise:SetScript("OnClick", function()
        local amount = math.floor(betSlider:GetValue() / 10) * 10
        G.DoAction("R", amount)
    end)

    btnAllIn:SetScript("OnClick", function()
        G.DoAction("A", 0)
    end)

    -- ==========================================
    -- INVITE POPUP
    -- ==========================================
    UI.CreateInvitePopup()
end

-- ==========================================
-- INVITE POPUP
-- ==========================================

function UI.CreateInvitePopup()
    invitePopup = CreateFrame("Frame", "WowPokerInvitePopup", UIParent, "BackdropTemplate")
    invitePopup:SetSize(300, 120)
    invitePopup:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    invitePopup:SetBackdrop(TABLE_BACKDROP)
    invitePopup:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    invitePopup:SetBackdropBorderColor(1, 0.84, 0, 1)
    invitePopup:SetFrameStrata("DIALOG")
    invitePopup:EnableMouse(true)
    invitePopup:Hide()

    invitePopup.title = invitePopup:CreateFontString(nil, "OVERLAY")
    invitePopup.title:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    invitePopup.title:SetPoint("TOP", invitePopup, "TOP", 0, -15)
    invitePopup.title:SetTextColor(1, 0.84, 0)

    invitePopup.text = invitePopup:CreateFontString(nil, "OVERLAY")
    invitePopup.text:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    invitePopup.text:SetPoint("CENTER", invitePopup, "CENTER", 0, 5)
    invitePopup.text:SetTextColor(1, 1, 1)

    invitePopup.acceptBtn = CreateFrame("Button", nil, invitePopup, "UIPanelButtonTemplate")
    invitePopup.acceptBtn:SetSize(100, 25)
    invitePopup.acceptBtn:SetPoint("BOTTOMLEFT", invitePopup, "BOTTOMLEFT", 30, 15)
    invitePopup.acceptBtn:SetText(L["INVITE_POPUP_ACCEPT"])
    invitePopup.acceptBtn:SetScript("OnClick", function()
        invitePopup:Hide()
        G.AcceptInvite()
    end)

    invitePopup.declineBtn = CreateFrame("Button", nil, invitePopup, "UIPanelButtonTemplate")
    invitePopup.declineBtn:SetSize(100, 25)
    invitePopup.declineBtn:SetPoint("BOTTOMRIGHT", invitePopup, "BOTTOMRIGHT", -30, 15)
    invitePopup.declineBtn:SetText(L["INVITE_POPUP_DECLINE"])
    invitePopup.declineBtn:SetScript("OnClick", function()
        invitePopup:Hide()
        G.DeclineInvite()
    end)
end

function UI.ShowInvitePopup(senderName)
    if not invitePopup then return end
    invitePopup.title:SetText(L["ADDON_NAME"])
    invitePopup.text:SetText(string.format(L["INVITE_POPUP_TITLE"], senderName))
    invitePopup:Show()
end

function UI.HideInvitePopup()
    if invitePopup then
        invitePopup:Hide()
    end
end

-- ==========================================
-- SHOW / HIDE
-- ==========================================

function UI.Show()
    if not mainFrame then
        UI.CreateMainFrame()
    end
    mainFrame:Show()
end

function UI.Hide()
    if mainFrame then
        mainFrame:Hide()
    end
end

function UI.Toggle()
    if mainFrame and mainFrame:IsShown() then
        UI.Hide()
    else
        UI.Show()
    end
end

function UI.IsShown()
    return mainFrame and mainFrame:IsShown()
end

-- ==========================================
-- UPDATE ALL
-- ==========================================

function UI.UpdateAll()
    if not mainFrame then
        UI.CreateMainFrame()
    end

    local state = G.GetState()
    local mySeat = G.GetMySeat()
    local oppSeat = G.GetOpponentSeat()

    -- Update names
    local playerName = UnitName("player") or "You"
    local opponentName = G.GetOpponent() or "Opponent"

    oppNameText:SetText(opponentName)
    myNameText:SetText(playerName)

    -- Update chips
    if state ~= G.STATE.IDLE then
        oppChipsText:SetText(L["CHIPS"] .. ": " .. G.GetChips(oppSeat))
        myChipsText:SetText(L["CHIPS"] .. ": " .. G.GetChips(mySeat))

        -- Bets
        local oppBet = G.GetBet(oppSeat)
        local myBet = G.GetBet(mySeat)
        oppBetText:SetText(oppBet > 0 and (L["BET_AMOUNT"] .. ": " .. oppBet) or "")
        myBetText:SetText(myBet > 0 and (L["BET_AMOUNT"] .. ": " .. myBet) or "")

        -- Pot
        local totalPot = G.GetPot() + G.GetBet(G.SEAT_1) + G.GetBet(G.SEAT_2)
        potText:SetText(L["POT"] .. ": " .. totalPot)

        -- Phase
        phaseText:SetText(G.GetPhaseLabel())
    else
        oppChipsText:SetText("")
        myChipsText:SetText("")
        oppBetText:SetText("")
        myBetText:SetText("")
        potText:SetText("")
        phaseText:SetText("")
    end

    -- Dealer badge
    local dealerSeat = G.GetDealerSeat()
    if dealerSeat == mySeat then
        myDealerBadge:Show()
        oppDealerBadge:Hide()
    elseif dealerSeat == oppSeat then
        oppDealerBadge:Show()
        myDealerBadge:Hide()
    else
        myDealerBadge:Hide()
        oppDealerBadge:Hide()
    end

    -- My cards
    local myHole = G.GetHoleCards(mySeat)
    if #myHole >= 2 then
        CT.ShowCard(myCards[1], D.CardToString(myHole[1]))
        CT.ShowCard(myCards[2], D.CardToString(myHole[2]))
    else
        CT.HideCard(myCards[1])
        CT.HideCard(myCards[2])
    end

    -- Opponent cards
    local oppHole = G.GetHoleCards(oppSeat)
    if state == G.STATE.SHOWDOWN or state == G.STATE.HAND_OVER then
        -- Show opponent cards at showdown (if we have them)
        if #oppHole >= 2 then
            CT.ShowCard(oppCards[1], D.CardToString(oppHole[1]))
            CT.ShowCard(oppCards[2], D.CardToString(oppHole[2]))
        else
            CT.ShowFaceDown(oppCards[1])
            CT.ShowFaceDown(oppCards[2])
        end
    elseif state ~= G.STATE.IDLE and state ~= G.STATE.WAITING_ACCEPT then
        -- Face down during play
        CT.ShowFaceDown(oppCards[1])
        CT.ShowFaceDown(oppCards[2])
    else
        CT.HideCard(oppCards[1])
        CT.HideCard(oppCards[2])
    end

    -- Community cards
    local community = G.GetCommunity()
    for i = 1, 5 do
        if community[i] then
            CT.ShowCard(communityCards[i], D.CardToString(community[i]))
        else
            CT.HideCard(communityCards[i])
        end
    end

    -- Status text
    if state ~= G.STATE.IDLE and state ~= G.STATE.WAITING_ACCEPT then
        if G.IsMyTurn() then
            statusText:SetText("|cFF00FF00" .. L["YOUR_TURN"] .. "|r")
        else
            statusText:SetText("|cFFAAAA00" .. L["WAITING"] .. "|r")
        end
    else
        statusText:SetText("")
    end

    -- Update action buttons
    UI.UpdateActions()
end

-- ==========================================
-- UPDATE ACTION BUTTONS
-- ==========================================

function UI.UpdateActions()
    -- Disable all by default
    btnFold:Disable()
    btnCheck:Disable()
    btnCall:Disable()
    btnBet:Disable()
    btnRaise:Disable()
    btnAllIn:Disable()
    betSlider:Hide()
    betSliderText:Hide()

    -- Reset call button text
    btnCall:SetText(L["ACTION_CALL"])

    if not G.IsMyTurn() then return end

    local actions = G.GetValidActions()
    if not actions then return end

    if actions.fold then
        btnFold:Enable()
    end

    if actions.check then
        btnCheck:Enable()
    end

    if actions.call then
        btnCall:Enable()
        if type(actions.call) == "number" then
            btnCall:SetText(L["ACTION_CALL"] .. " (" .. actions.call .. ")")
        end
    end

    if actions.bet then
        btnBet:Enable()
        if type(actions.bet) == "table" then
            betSlider:SetMinMaxValues(actions.bet.min, actions.bet.max)
            betSlider:SetValue(actions.bet.min)
            betSlider:Show()
            betSliderText:SetText(L["BET_AMOUNT"] .. ": " .. actions.bet.min)
            betSliderText:Show()
        end
    end

    if actions.raise then
        btnRaise:Enable()
        if type(actions.raise) == "table" then
            betSlider:SetMinMaxValues(actions.raise.min, actions.raise.max)
            betSlider:SetValue(actions.raise.min)
            betSlider:Show()
            betSliderText:SetText(L["BET_AMOUNT"] .. ": " .. actions.raise.min)
            betSliderText:Show()
        end
    end

    if actions.allin then
        btnAllIn:Enable()
    end
end
