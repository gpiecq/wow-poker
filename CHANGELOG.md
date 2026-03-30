# Changelog

All notable changes to WowPoker will be documented in this file.

---

## [1.0.0] - 2026-03-31

### Added

#### Core Addon
- Addon initialization with `SavedVariablesPerCharacter` persistence
- Slash commands: `/poker invite`, `/poker accept`, `/poker decline`, `/poker stats`, `/poker quit`, `/poker help`
- Bilingual support (English / French) with automatic detection via `GetLocale()`

#### Network Protocol
- Addon message communication via `C_ChatInfo.SendAddonMessage` on WHISPER channel
- Message format: `VERSION:MSGTYPE:FIELD1:FIELD2:...` with prefix `WowPoker`
- 13 message types: INV, ACC, DEC, NH, DEAL, COM, ACT, SD, RES, QUIT, PING, PONG, SYNC

#### Game Logic
- Complete Texas Hold'em state machine: IDLE, WAITING_ACCEPT, PREFLOP, FLOP, TURN, RIVER, SHOWDOWN, HAND_OVER
- Heads-up rules: Dealer = Small Blind (10), Non-dealer = Big Blind (20)
- Pre-flop dealer acts first, post-flop non-dealer acts first
- Dealer alternates each hand
- 6 player actions: Fold, Check, Call, Bet, Raise, All-In
- Betting round validation with proper raise mechanics

#### Hand Evaluation
- Full 5-card hand evaluation for all 10 poker hand ranks (High Card through Royal Flush)
- Best hand selection from 7 cards using all C(7,5) = 21 combinations
- Numeric scoring system (rank * 1,000,000 + kickers) for tie-breaking
- Wheel straight (A-2-3-4-5) support

#### Deck
- 52-card deck with Fisher-Yates shuffle
- Deal and burn card operations
- Card encoding as 2-character strings (rank + suit, e.g., `Ah`, `Tc`)

#### User Interface
- 800x500 draggable poker table with dark green felt backdrop
- Opponent zone: name, chips, cards (face down), bet, dealer badge
- Community zone: 5 card slots, pot display, phase label
- Player zone: name, chips, cards (face up), bet, dealer badge
- Action bar: 6 buttons (Fold, Check, Call, Bet, Raise, All-In) with bet slider
- Status bar: "Your turn" / "Waiting..."
- Card rendering via FontStrings and backdrops with rank, suit symbols, and colored corners
- Invitation popup with Accept/Decline buttons

#### Context Menu
- "Invite to Poker" option in right-click player context menus (Player, Party, Friend)

#### Timers & Reliability
- 30-second invitation timeout
- 60-second action timeout with auto-fold
- 15-second heartbeat ping/pong with disconnect detection (3 missed pongs)

#### Statistics
- Per-character saved stats: games played, games won, games lost, biggest pot
- `/poker stats` command to display statistics
