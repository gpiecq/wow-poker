WowPoker = WowPoker or {}

local L = {}
WowPoker.L = L

local locale = GetLocale()

if locale == "frFR" then
    -- General
    L["ADDON_LOADED"] = "WowPoker charge. Tapez /poker pour l'aide."
    L["ADDON_NAME"] = "WowPoker"
    L["HELP_TITLE"] = "Commandes WowPoker :"
    L["HELP_INVITE"] = "/poker invite <nom> - Inviter un joueur"
    L["HELP_ACCEPT"] = "/poker accept - Accepter l'invitation"
    L["HELP_DECLINE"] = "/poker decline - Refuser l'invitation"
    L["HELP_STATS"] = "/poker stats - Voir vos statistiques"
    L["HELP_QUIT"] = "/poker quit - Quitter la partie"
    L["HELP_HELP"] = "/poker help - Afficher cette aide"

    -- Invitations
    L["INVITE_SENT"] = "Invitation envoyee a %s."
    L["INVITE_RECEIVED"] = "%s vous invite a jouer au poker ! /poker accept ou /poker decline"
    L["INVITE_ACCEPTED"] = "%s a accepte l'invitation."
    L["INVITE_DECLINED"] = "%s a refuse l'invitation."
    L["INVITE_TIMEOUT"] = "L'invitation a expire."
    L["INVITE_ALREADY_IN_GAME"] = "Vous etes deja en partie."
    L["INVITE_NO_PENDING"] = "Aucune invitation en attente."
    L["INVITE_POPUP_TITLE"] = "%s vous invite au poker"
    L["INVITE_POPUP_ACCEPT"] = "Accepter"
    L["INVITE_POPUP_DECLINE"] = "Refuser"
    L["INVITE_CONTEXT_MENU"] = "Inviter au Poker"

    -- Game phases
    L["PHASE_PREFLOP"] = "Pre-Flop"
    L["PHASE_FLOP"] = "Flop"
    L["PHASE_TURN"] = "Turn"
    L["PHASE_RIVER"] = "River"
    L["PHASE_SHOWDOWN"] = "Abattage"

    -- Actions
    L["ACTION_FOLD"] = "Se Coucher"
    L["ACTION_CHECK"] = "Parole"
    L["ACTION_CALL"] = "Suivre"
    L["ACTION_BET"] = "Miser"
    L["ACTION_RAISE"] = "Relancer"
    L["ACTION_ALLIN"] = "Tapis"
    L["YOUR_TURN"] = "Votre tour"
    L["WAITING"] = "En attente..."

    -- Hand ranks
    L["HAND_HIGH_CARD"] = "Carte haute"
    L["HAND_PAIR"] = "Paire"
    L["HAND_TWO_PAIR"] = "Double paire"
    L["HAND_THREE_KIND"] = "Brelan"
    L["HAND_STRAIGHT"] = "Suite"
    L["HAND_FLUSH"] = "Couleur"
    L["HAND_FULL_HOUSE"] = "Full"
    L["HAND_FOUR_KIND"] = "Carre"
    L["HAND_STRAIGHT_FLUSH"] = "Quinte flush"
    L["HAND_ROYAL_FLUSH"] = "Quinte flush royale"

    -- Game messages
    L["GAME_NEW_HAND"] = "-- Nouvelle main #%d --"
    L["GAME_YOU_ARE_DEALER"] = "Vous etes le dealer."
    L["GAME_OPPONENT_DEALER"] = "%s est le dealer."
    L["GAME_WINS_POT"] = "%s remporte le pot de %d jetons !"
    L["GAME_SPLIT_POT"] = "Egalite ! Le pot est partage."
    L["GAME_OVER_WIN"] = "Partie terminee ! Vous avez gagne !"
    L["GAME_OVER_LOSE"] = "Partie terminee ! %s a gagne."
    L["GAME_OPPONENT_QUIT"] = "%s a quitte la partie."
    L["GAME_DISCONNECT"] = "%s semble deconnecte."
    L["GAME_ACTION_TIMEOUT"] = "Temps ecoule, couche automatiquement."

    -- Stats
    L["STATS_TITLE"] = "Statistiques WowPoker :"
    L["STATS_PLAYED"] = "Parties jouees : %d"
    L["STATS_WON"] = "Parties gagnees : %d"
    L["STATS_LOST"] = "Parties perdues : %d"
    L["STATS_BIGGEST_POT"] = "Plus gros pot : %d"

    -- UI labels
    L["POT"] = "Pot"
    L["CHIPS"] = "Jetons"
    L["DEALER"] = "D"
    L["BET_AMOUNT"] = "Mise"
else
    -- English (default)
    -- General
    L["ADDON_LOADED"] = "WowPoker loaded. Type /poker for help."
    L["ADDON_NAME"] = "WowPoker"
    L["HELP_TITLE"] = "WowPoker Commands:"
    L["HELP_INVITE"] = "/poker invite <name> - Invite a player"
    L["HELP_ACCEPT"] = "/poker accept - Accept invitation"
    L["HELP_DECLINE"] = "/poker decline - Decline invitation"
    L["HELP_STATS"] = "/poker stats - View your statistics"
    L["HELP_QUIT"] = "/poker quit - Quit the game"
    L["HELP_HELP"] = "/poker help - Show this help"

    -- Invitations
    L["INVITE_SENT"] = "Invitation sent to %s."
    L["INVITE_RECEIVED"] = "%s invites you to play poker! /poker accept or /poker decline"
    L["INVITE_ACCEPTED"] = "%s accepted the invitation."
    L["INVITE_DECLINED"] = "%s declined the invitation."
    L["INVITE_TIMEOUT"] = "Invitation expired."
    L["INVITE_ALREADY_IN_GAME"] = "You are already in a game."
    L["INVITE_NO_PENDING"] = "No pending invitation."
    L["INVITE_POPUP_TITLE"] = "%s invites you to poker"
    L["INVITE_POPUP_ACCEPT"] = "Accept"
    L["INVITE_POPUP_DECLINE"] = "Decline"
    L["INVITE_CONTEXT_MENU"] = "Invite to Poker"

    -- Game phases
    L["PHASE_PREFLOP"] = "Pre-Flop"
    L["PHASE_FLOP"] = "Flop"
    L["PHASE_TURN"] = "Turn"
    L["PHASE_RIVER"] = "River"
    L["PHASE_SHOWDOWN"] = "Showdown"

    -- Actions
    L["ACTION_FOLD"] = "Fold"
    L["ACTION_CHECK"] = "Check"
    L["ACTION_CALL"] = "Call"
    L["ACTION_BET"] = "Bet"
    L["ACTION_RAISE"] = "Raise"
    L["ACTION_ALLIN"] = "All-In"
    L["YOUR_TURN"] = "Your turn"
    L["WAITING"] = "Waiting..."

    -- Hand ranks
    L["HAND_HIGH_CARD"] = "High Card"
    L["HAND_PAIR"] = "Pair"
    L["HAND_TWO_PAIR"] = "Two Pair"
    L["HAND_THREE_KIND"] = "Three of a Kind"
    L["HAND_STRAIGHT"] = "Straight"
    L["HAND_FLUSH"] = "Flush"
    L["HAND_FULL_HOUSE"] = "Full House"
    L["HAND_FOUR_KIND"] = "Four of a Kind"
    L["HAND_STRAIGHT_FLUSH"] = "Straight Flush"
    L["HAND_ROYAL_FLUSH"] = "Royal Flush"

    -- Game messages
    L["GAME_NEW_HAND"] = "-- New hand #%d --"
    L["GAME_YOU_ARE_DEALER"] = "You are the dealer."
    L["GAME_OPPONENT_DEALER"] = "%s is the dealer."
    L["GAME_WINS_POT"] = "%s wins the pot of %d chips!"
    L["GAME_SPLIT_POT"] = "Tie! The pot is split."
    L["GAME_OVER_WIN"] = "Game over! You won!"
    L["GAME_OVER_LOSE"] = "Game over! %s won."
    L["GAME_OPPONENT_QUIT"] = "%s has left the game."
    L["GAME_DISCONNECT"] = "%s appears disconnected."
    L["GAME_ACTION_TIMEOUT"] = "Time's up, auto-folding."

    -- Stats
    L["STATS_TITLE"] = "WowPoker Statistics:"
    L["STATS_PLAYED"] = "Games played: %d"
    L["STATS_WON"] = "Games won: %d"
    L["STATS_LOST"] = "Games lost: %d"
    L["STATS_BIGGEST_POT"] = "Biggest pot: %d"

    -- UI labels
    L["POT"] = "Pot"
    L["CHIPS"] = "Chips"
    L["DEALER"] = "D"
    L["BET_AMOUNT"] = "Bet"
end
