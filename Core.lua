local P = WowPoker.Protocol
local G = WowPoker.Game
local D = WowPoker.Deck
local L = WowPoker.L
local UI = WowPoker.UI
local M = WowPoker.Menu

-- ==========================================
-- EVENT FRAME
-- ==========================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "WowPoker" then
            WowPoker.Core.OnAddonLoaded()
        end
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        P.OnAddonMessage(prefix, message, channel, sender)
    end
end)

-- ==========================================
-- CORE MODULE
-- ==========================================

local Core = {}
WowPoker.Core = Core

function Core.OnAddonLoaded()
    -- Initialize saved variables
    if not WowPokerDB then
        WowPokerDB = {}
    end
    if not WowPokerDB.stats then
        WowPokerDB.stats = {
            gamesPlayed = 0,
            gamesWon = 0,
            gamesLost = 0,
            biggestPot = 0,
        }
    end

    -- Register addon message prefix
    P.RegisterPrefix()

    -- Register protocol handlers
    Core.RegisterProtocolHandlers()

    -- Initialize menu (right-click integration)
    M.Init()

    -- Create the UI (hidden) and minimap button
    UI.CreateMainFrame()
    UI.CreateMinimapButton()

    -- Register slash commands
    Core.RegisterSlashCommands()

    G.PrintMessage(L["ADDON_LOADED"])
end

-- ==========================================
-- SLASH COMMANDS
-- ==========================================

function Core.RegisterSlashCommands()
    SLASH_WOWPOKER1 = "/poker"
    SLASH_WOWPOKER2 = "/wowpoker"
    SlashCmdList["WOWPOKER"] = function(msg)
        msg = msg or ""
        local cmd, arg = msg:match("^(%S+)%s*(.*)")
        cmd = cmd and cmd:lower() or msg:lower()

        if cmd == "invite" and arg and arg ~= "" then
            G.SendInvite(arg)
        elseif cmd == "accept" then
            G.AcceptInvite()
        elseif cmd == "decline" then
            G.DeclineInvite()
        elseif cmd == "stats" then
            G.ShowStats()
        elseif cmd == "quit" then
            G.QuitGame()
        elseif cmd == "show" then
            UI.Show()
        elseif cmd == "hide" then
            UI.Hide()
        elseif cmd == "help" or cmd == "" then
            Core.ShowHelp()
        else
            Core.ShowHelp()
        end
    end
end

function Core.ShowHelp()
    G.PrintMessage(L["HELP_TITLE"])
    G.PrintMessage(L["HELP_INVITE"])
    G.PrintMessage(L["HELP_ACCEPT"])
    G.PrintMessage(L["HELP_DECLINE"])
    G.PrintMessage(L["HELP_STATS"])
    G.PrintMessage(L["HELP_QUIT"])
    G.PrintMessage(L["HELP_HELP"])
end

-- ==========================================
-- PROTOCOL HANDLERS
-- ==========================================

function Core.RegisterProtocolHandlers()
    local game = G.game

    -- INV: Invitation received
    P.RegisterHandler(P.MSG.INV, function(sender, fields)
        if G.GetState() ~= G.STATE.IDLE then
            -- Already in a game, auto-decline
            P.Send(sender, P.MSG.DEC)
            return
        end

        game.pendingInviteFrom = sender
        G.PrintMessage(string.format(L["INVITE_RECEIVED"], sender))
        G.StartInviteTimeout()

        -- Show popup
        UI.ShowInvitePopup(sender)
    end)

    -- ACC: Invitation accepted
    P.RegisterHandler(P.MSG.ACC, function(sender, fields)
        if G.GetState() ~= G.STATE.WAITING_ACCEPT then return end

        local shortSender = sender:match("^([^-]+)") or sender
        local shortOpp = game.opponent and (game.opponent:match("^([^-]+)") or game.opponent)
        if shortSender ~= shortOpp then return end

        -- Store full sender name (with realm if present)
        game.opponent = sender

        G.CancelInviteTimeout()
        G.PrintMessage(string.format(L["INVITE_ACCEPTED"], sender))

        -- Initialize chips
        game.chips = {1000, 1000}

        -- Show UI
        UI.Show()
        UI.UpdateAll()

        -- Start heartbeat
        G.StartHeartbeat()

        -- Host starts the first hand
        C_Timer.After(1, function()
            G.StartNewHand()
        end)
    end)

    -- DEC: Invitation declined
    P.RegisterHandler(P.MSG.DEC, function(sender, fields)
        if G.GetState() ~= G.STATE.WAITING_ACCEPT then return end

        G.CancelInviteTimeout()
        G.PrintMessage(string.format(L["INVITE_DECLINED"], sender))
        G.ResetGame()
    end)

    -- NH: New hand
    P.RegisterHandler(P.MSG.NH, function(sender, fields)
        -- fields: handNum, dealerSeat, card1, card2
        if #fields < 4 then return end
        G.OnReceiveNewHand(fields[1], fields[2], fields[3], fields[4])
    end)

    -- DEAL: Community cards dealt
    P.RegisterHandler(P.MSG.DEAL, function(sender, fields)
        -- fields: phase, card1, [card2, card3]
        if #fields < 2 then return end
        local phase = fields[1]
        local cardStrs = {}
        for i = 2, #fields do
            cardStrs[#cardStrs + 1] = fields[i]
        end
        G.OnReceiveCommunity(phase, cardStrs)
    end)

    -- ACT: Opponent action
    P.RegisterHandler(P.MSG.ACT, function(sender, fields)
        -- fields: action, amount
        if #fields < 2 then return end
        local action = fields[1]
        local amount = tonumber(fields[2]) or 0

        -- Opponent's seat
        local oppSeat = G.GetOpponentSeat()
        G.CancelActionTimeout()
        G.ProcessAction(oppSeat, action, amount)
    end)

    -- SD: Showdown (opponent reveals cards)
    P.RegisterHandler(P.MSG.SD, function(sender, fields)
        -- fields: card1, card2
        if #fields < 2 then return end
        local oppSeat = G.GetOpponentSeat()
        game.holeCards[oppSeat] = {
            D.StringToCard(fields[1]),
            D.StringToCard(fields[2]),
        }

        -- If we're not the host, send our cards back
        if not G.IsHost() then
            local myCards = G.GetHoleCards(G.GetMySeat())
            if #myCards >= 2 then
                P.Send(game.opponent, P.MSG.SD,
                       D.CardToString(myCards[1]), D.CardToString(myCards[2]))
            end
        end

        if UI.UpdateAll then
            UI.UpdateAll()
        end
    end)

    -- RES: Result from host
    P.RegisterHandler(P.MSG.RES, function(sender, fields)
        -- fields: winnerSeat, handRank, pot
        if #fields < 3 then return end
        local winnerSeat = tonumber(fields[1]) or 0
        local handRank = tonumber(fields[2]) or 0
        local pot = tonumber(fields[3]) or 0
        G.ApplyResult(winnerSeat, handRank, pot)
    end)

    -- QUIT: Opponent quit
    P.RegisterHandler(P.MSG.QUIT, function(sender, fields)
        G.OnOpponentQuit()
    end)

    -- PING: Heartbeat request
    P.RegisterHandler(P.MSG.PING, function(sender, fields)
        P.Send(sender, P.MSG.PONG)
    end)

    -- PONG: Heartbeat response
    P.RegisterHandler(P.MSG.PONG, function(sender, fields)
        G.OnPong()
    end)
end
