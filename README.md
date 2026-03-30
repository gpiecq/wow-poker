# WowPoker

A World of Warcraft Classic TBC addon for playing Texas Hold'em Poker in heads-up (1v1) mode.

## Features

- **Heads-up Texas Hold'em** between two players
- **Virtual chips** (1,000 per game), fixed blinds 10/20
- **Full poker rules**: Fold, Check, Call, Bet, Raise, All-In
- **Complete hand evaluation**: High Card through Royal Flush (21 combinations tested)
- **Graphical interface**: 800x500 poker table with card rendering, action bar, and bet slider
- **Right-click invite**: "Invite to Poker" option in player context menus
- **Bilingual**: English and French (auto-detected)
- **Statistics**: Games played/won/lost, biggest pot (saved per character)
- **Timeouts**: 30s invite, 60s action (auto-fold), heartbeat disconnect detection

## Installation

1. Copy the `WowPoker` folder into `Interface/AddOns/`
2. Restart the game or `/reload`

## Commands

| Command | Description |
|---------|-------------|
| `/poker invite <name>` | Invite a player |
| `/poker accept` | Accept an invitation |
| `/poker decline` | Decline an invitation |
| `/poker stats` | View your statistics |
| `/poker quit` | Quit the current game |
| `/poker help` | Show help |

## How to Play

1. Target a player or use `/poker invite <name>`
2. The opponent accepts via popup or `/poker accept`
3. The poker table opens automatically
4. Play hands until one player runs out of chips

## Heads-Up Rules

- **Dealer** = Small Blind (10), **Non-dealer** = Big Blind (20)
- **Pre-flop**: dealer acts first
- **Post-flop**: non-dealer acts first
- Dealer alternates each hand
- Game ends when a player reaches 0 chips

## Architecture

| File | Description |
|------|-------------|
| `WowPoker.toc` | Addon metadata (Interface: 20505) |
| `Locale.lua` | FR/EN localization strings |
| `Protocol.lua` | Network messaging via addon WHISPER |
| `Deck.lua` | 52-card deck, shuffle, deal |
| `GameLogic.lua` | State machine, betting, hand evaluation |
| `CardTextures.lua` | Card rendering (FontStrings + backdrops) |
| `UI.lua` | Poker table UI (800x500) |
| `Menu.lua` | Right-click context menu integration |
| `Core.lua` | Initialization, events, slash commands |

## Communication Protocol

Messages are sent via `C_ChatInfo.SendAddonMessage` on the WHISPER channel using the prefix `WowPoker`.

Format: `VERSION:MSGTYPE:FIELD1:FIELD2:...`

The host (inviter) manages the deck, deals cards, and evaluates the showdown. The guest receives cards and results.

## Requirements

- World of Warcraft Classic TBC (Interface 20505)
- Two players required
