# Rummy Rules Engine

Documentation for the in-memory 13-card Indian Rummy engine (`backend/src/main/java/com/trustrummy/backend/game/` + `service/RummyEngineService.java`). Covers state transitions, configurable parameters, the WebSocket action/event contract, and the design assumptions made where the source spec was ambiguous.

## 1. Package map

```
game/
├── model/     Card, Suit, Value, Meld, MeldType, DeclareResult, GroupingResult,
│              GameVariant, MatchStatus, DealStatus, TurnPhase, RoundStatus, MatchPlayerStatus
├── config/    GameConfig — per-room configurable rule set
├── state/     MatchState (root, per room), Deal (per hand), PlayerScorecard (per player, whole match)
├── engine/    DeckFactory, HandValidator, ScoreCalculator, TurnManager
└── ws/        ActionType, DrawSource, GameActionMessage (inbound),
               EventType, GameEvent (outbound), GameBroadcastService (session registry + redaction)

service/
├── RummyEngineService     orchestrator — the only class that mutates a MatchState
├── GamePersistenceService async (@Async) durable audit trail / final results
└── GameStateService       ConcurrentHashMap<roomCode, MatchState> registry
```

All gameplay mutation is funneled through `RummyEngineService`, which acquires `MatchState#lock` (a `ReentrantLock`) for the duration of each action, so concurrent WebSocket messages for the same room are processed atomically.

## 2. State machine

### 2.1 Match lifecycle (`MatchStatus`)

```
WAITING --(host sends START_MATCH, >=2 seated players)--> IN_PROGRESS --(1 active player remains, or POINTS variant deal ends)--> COMPLETED
```

### 2.2 Deal lifecycle (`DealStatus`)

```
IN_PROGRESS --(valid DECLARE | wrong DECLARE | drops down to 1 active player)--> COMPLETED
```

Each deal that completes while >= 2 players remain active in the match (Pool variants only) immediately triggers the next deal (`RummyEngineService#startNewDeal`).

### 2.3 Turn phase (`TurnPhase`), per current turn-holder

```
AWAITING_DRAW --(DRAW_CARD)--> AWAITING_DISCARD --(DISCARD_CARD | DECLARE)--> [next player] AWAITING_DRAW
AWAITING_DRAW --(DROP)--> [next player] AWAITING_DRAW
```

`DROP` is only legal in `AWAITING_DRAW` (i.e. before drawing, as the very first thing on your turn).

### 2.4 Per-deal player status (`RoundStatus`) — reset every deal

```
PLAYING --(DROP)--> DROPPED
PLAYING --(DECLARE, valid)--> DECLARED_VALID
PLAYING --(DECLARE, invalid)--> DECLARED_WRONG
```

### 2.5 Per-match player status (`MatchPlayerStatus`) — persists across deals

```
ACTIVE --(cumulativeScore >= eliminationThreshold, Pool variants only)--> ELIMINATED
ACTIVE --(last player standing at match end)--> WINNER
```

## 3. Configurable parameters (`GameConfig`)

| Field | Default | Notes |
|---|---|---|
| `maxPlayers` | 6 | Copied from the room's `maxPlayers` (2–6) at match start |
| `gameVariant` | `POOL_101` | `POOL_101` \| `POOL_201` \| `POINTS` |
| `penaltyFirstDrop` | 20 | Points for dropping on a player's first turn of a deal |
| `penaltyMiddleDrop` | 40 | Points for dropping on any later turn |
| `penaltyMaxCap` | 80 | Hard ceiling on any single deal's loss for one player |
| `penaltyWrongDeclare` | 80 | Flat points for an invalid declare |
| `cardsPerPlayer` | 13 | |
| `turnTimeoutSeconds` | 30 | Countdown before `RummyEngineService` auto-plays the turn |

`GameVariant.eliminationThreshold()`: `POOL_101` → 101, `POOL_201` → 201, `POINTS` → unreachable (no elimination; a `POINTS` match is exactly one deal).

## 4. Deck & wild joker

- 2 standard 52-card decks + 2 printed jokers = **106 cards** (`DeckFactory`).
- At deal start: shuffle → deal `cardsPerPlayer` to each active player (round-robin) → flip the next card as the **cut/wild joker**.
- Wild value = the cut card's rank, unless the cut card is itself a printed joker, in which case **Aces** are wild for that deal.
- A card counts as a joker if it is a printed joker **or** its rank matches the deal's wild value — but the same physical card can still be used at its own natural rank/suit within a specific meld (e.g. three wild-rank cards of different suits are a legal natural `SET`). `HandValidator` explores both interpretations by classifying every 3/4-card combination independently.
- If the closed deck empties mid-deal, the discard pile (minus its current top card) is reshuffled back into a fresh closed deck.

## 5. Declare validation (`HandValidator`)

A declare is valid iff the 13 cards can be partitioned into exactly 4 disjoint groups (one of size 4, three of size 3 — the only way to split 13 cards into groups of size 3–4) such that:

- at least 1 group is a **pure sequence** (3+ consecutive same-suit cards, zero jokers), and
- at least 2 groups total are sequences (pure or impure), and
- every other group is a valid **set** (same rank, distinct suits, 3–4 cards).

Implemented as bitmask-indexed backtracking over precomputed candidate melds (13 cards → at most `C(13,3)+C(13,4)` ≈ 1000 candidates to classify, trivial to search exhaustively).

**Assumptions** (spec was silent/ambiguous on these):
- Ace ranks low only — sequences never wrap King→Ace.
- Jokers may fill **sets** as well as impure sequences (standard convention; the spec's set example just didn't show one).
- A meld candidate needs at least one *natural* (non-joker) anchor card — an all-joker "group" is disallowed as ambiguous.

## 6. Scoring a losing hand (`ScoreCalculator`)

```
if hand has no pure sequence at all:
    points = penaltyMaxCap
else:
    points = min(bestEffortDeadwood(hand), penaltyMaxCap)
```

`bestEffortDeadwood` (`HandValidator#computeBestGrouping`) is a bitmask DP that greedily maximizes the point-value removed by disjoint melds (partial coverage allowed, unlike strict declare validation) — the complement is the deadwood. Deadwood value of a card is 0 if it's a printed joker or matches the deal's wild rank, else its face value (A/J/Q/K = 10, 2–10 = face).

**Wrong-declare round-voiding assumption**: the spec says a wrong declare ends the round immediately but doesn't say how other still-`PLAYING` players are scored. This engine treats the round as **voided for everyone else** (0 points) — only the wrong-declarer is penalized (`penaltyWrongDeclare`). Players who had already dropped earlier in that same deal keep their drop penalty regardless.

## 7. Turn timeout auto-play (`TurnManager` + `RummyEngineService#onTurnTimeout`)

One cancellable timer per room, reset every time a turn changes. On fire:

1. If still `AWAITING_DRAW`, auto-draw from the closed deck.
2. Compute the best-effort grouping of the resulting hand; auto-discard the highest deadwood-value leftover card (or, if the hand is empty, auto-drop).

This is a placeholder heuristic — never declares on the player's behalf.

## 8. Anti-cheat: opponent hand obfuscation

Every outbound state event is built **per recipient** (`GameBroadcastService#broadcastPersonalized`): each connected player always sees every seat's `handSize`, but the `hand` (actual card codes) field is populated **only** for their own `userId`. Drawing from the closed deck is therefore private; drawing from the open pile is implicitly public since the discard top was already visible before the draw.

## 9. WebSocket contract — `/ws/game/{roomCode}?token=<jwt>`

### Inbound (`GameActionMessage`)

| `type` | Extra fields | When legal |
|---|---|---|
| `START_MATCH` | — | Match `WAITING`, sender is the room's host, >= 2 seated players |
| `DRAW_CARD` | `source`: `CLOSED` \| `OPEN` | Your turn, `AWAITING_DRAW` |
| `DISCARD_CARD` | `cardCode` (e.g. `"10H"`, `"AS"`, `"JK"`) | Your turn, `AWAITING_DISCARD` |
| `DECLARE` | `cardCode` — the 14th card you're setting aside; the remaining 13 are validated | Your turn, `AWAITING_DISCARD` |
| `DROP` | — | Your turn, `AWAITING_DRAW` (before drawing) |

```json
{ "type": "DRAW_CARD", "source": "CLOSED" }
{ "type": "DISCARD_CARD", "cardCode": "10H" }
{ "type": "DECLARE", "cardCode": "7S" }
{ "type": "DROP" }
```

### Outbound (`GameEvent`) — flat JSON, `type` + event-specific fields

| `type` | Fields |
|---|---|
| `ROOM_STATE` | Sent once on connect: `roomCode`, `matchStatus`, and (if a deal is live) the full deal snapshot below |
| `DEAL_STARTED` | `dealNumber`, `wildValue`, `cutJokerCard`, `discardTop`, `closedDeckCount`, `currentTurnUserId`, `turnPhase`, `players[]` |
| `TURN_STATE` | Same deal snapshot shape, sent whenever the turn advances |
| `CARD_DRAWN` | Same deal snapshot shape (drawer's own `hand` included only for them) |
| `CARD_DISCARDED` | Same deal snapshot shape |
| `PLAYER_DROPPED` | Same deal snapshot shape |
| `DECLARE_RESULT` | `userId`, `valid`, `reason`, `melds[]` (`{type, cards[]}`) |
| `SCORE_UPDATE` | `dealNumber`, `scores[]` (`{userId, username, roundPoints, cumulativeScore, matchStatus}`) |
| `PLAYER_ELIMINATED` | `userId` |
| `MATCH_ENDED` | `winnerUserId`, `finalScores` (`{userId: cumulativeScore}`) |
| `ERROR` | `message` |

`players[]` entries (deal snapshot shape): `{userId, username, seatNumber, cumulativeScore, matchStatus, roundStatus, handSize, hand? }` — `hand` only present for the viewer's own entry.

## 10. Persistence

`GamePersistenceService` (all methods `@Async`, called fire-and-forget from `RummyEngineService`) keeps the hot path off the database:

- `recordMatchStart` — flips the room to `IN_PROGRESS`, opens a `GameSession`.
- `recordMove` — appends a `GameMoveLog` row per draw/discard/declare/drop (sequence-numbered per room).
- `recordMatchEnd` — closes the `GameSession` (winner, `endedAt`), writes each player's final `cumulativeScore` onto their `RoomPlayer.score`, flips the room to `COMPLETED`.

## 11. Room lobby REST contract

Connecting the game WebSocket does **not** seat a player — it only opens a channel for broadcasts. A player must be seated (a `RoomPlayer` row) before `START_MATCH` will count them. The room creator is auto-seated at seat `0` by `POST /api/v1/rooms`. All routes below require `Authorization: Bearer <jwt>` and, on success, broadcast a `ROOM_STATE` event (with the updated `players[]`) to any sockets already connected to that room — so already-open clients see the change without reconnecting.

| Method | Route | Body | Behavior |
|---|---|---|---|
| `GET` | `/api/v1/rooms/{roomCode}` | — | Room detail incl. `players[]`. `404` if the room code doesn't exist. |
| `POST` | `/api/v1/rooms/{roomCode}/join` | — | Seats the caller at the next free seat. Idempotent — re-joining an already-seated (and not-`LEFT`) room is a no-op; re-joining after having `LEFT` reactivates the same seat. `404` if room not found, `409` if full or `status != WAITING`. |
| `POST` | `/api/v1/rooms/{roomCode}/leave` | — | Un-seats the caller (marks `RoomPlayer.status = LEFT`) while `status == WAITING`. If the **host** leaves, the whole room is disbanded (`status -> CANCELLED`, every seat marked `LEFT`) — nobody else can ever send a valid `START_MATCH` for it. `404` if not seated, `409` if the room already started. |
| `DELETE` | `/api/v1/rooms/{roomCode}` | — | Host-only: disbands a still-`WAITING` room (same effect as the host leaving). `403` if caller isn't the host, `409` if already started. |
| `PUT` | `/api/v1/rooms/{roomCode}/ready` | `{ready: boolean}` | Toggles the caller's `RoomPlayer.status` between `JOINED`/`READY`. Purely informational for now — `START_MATCH` does not currently require all seats to be `READY`. |

`players[]` in every `RoomResponse`/`ROOM_STATE` payload here is `{userId, username, seatNumber, status}` and always excludes anyone with `status == LEFT`.

## 12. Other design decisions made while implementing

- **Match start trigger**: manual — the room's host (creator) sends `START_MATCH`; it is not automatic on reaching `maxPlayers`.
- **Deck exhaustion**: reshuffle the discard pile (minus its top card) back into the closed deck, rather than voiding the deal.
- Only players seated and not `LEFT` (`RoomPlayer` rows) at the moment `START_MATCH` is received are dealt into the match — see section 11 for how a player gets seated/un-seated.

## 13. Account, wallet & match-history REST contract

Everything here is pre-/post-game bookkeeping — none of it touches the live deal, which stays entirely on the `/ws/game/{roomCode}` socket (section 9).

**Auth — `/api/v1/auth` (all routes `permitAll`, no `Authorization` header needed/used):**

| Method | Route | Body | Behavior |
|---|---|---|---|
| `POST` | `/register` | `{username, email, password, displayName?}` | Creates the user, returns `AuthResponse` (`token`, `refreshToken`, `expiresInMs`). |
| `POST` | `/login` | `{username, password}` | Same `AuthResponse` shape as register. |
| `POST` | `/refresh` | `{refreshToken}` | Redeems a still-valid, unrevoked refresh token for a brand-new access + refresh token pair. **Rotates** the refresh token — the old one is marked revoked, so replaying it fails with `400`. |
| `POST` | `/logout` | `{refreshToken?}` | The access JWT is stateless (no blocklist yet), so this only revokes the given refresh token, if any. Always `204`. |

**Profile — `/api/v1/users` (JWT required):**

| Method | Route | Body | Behavior |
|---|---|---|---|
| `GET` | `/me` | — | `{id, username, email, displayName, walletBalance, role, createdAt}`. |
| `PUT` | `/me` | `{displayName?, email?}` | Partial update; `409`-style `400` if the new email is already taken. |
| `PUT` | `/me/password` | `{currentPassword, newPassword}` | `400` if `currentPassword` doesn't match. |

**Wallet — `/api/v1/wallet` (JWT required):**

| Method | Route | Body | Behavior |
|---|---|---|---|
| `GET` | `/balance` | — | `{username, balance}`. |
| `POST` | `/deposit` | `{amount}` | Credits the wallet, writes a `WalletTransaction` (`DEPOSIT`) row, returns the new balance. |
| `POST` | `/withdraw` | `{amount}` | Debits the wallet (`409`/`400` if insufficient funds), writes a `WalletTransaction` (`WITHDRAWAL`) row. |
| `GET` | `/transactions?page=&size=` | — | Paginated ledger, newest first. |

Match stakes are **not yet** wired into this ledger — `WalletTransactionType.STAKE_DEBIT`/`STAKE_PAYOUT` exist for when that lands, but today only manual deposit/withdraw ever create rows.

**Match history & audit — `/api/v1/history` (JWT required, read-only):**

| Method | Route | Body | Behavior |
|---|---|---|---|
| `GET` | `/matches?page=&size=` | — | Every session the caller was ever seated in, newest first: `{sessionId, roomCode, gameVariant, stakeAmount, status, winnerUsername, myFinalScore, startedAt, endedAt}`. |
| `GET` | `/matches/{sessionId}` | — | Full detail incl. every seated player's `{username, seatNumber, finalScore, status}`. `403` if the caller wasn't a participant, `404` if the session doesn't exist. |
| `GET` | `/matches/{sessionId}/moves?page=&size=` | — | The `GameMoveLog` trail for that session, in play order. Same `403`/`404` rules as above. |
| `GET` | `/scorecard` | — | Aggregate `{totalMatches, wins, losses, netChips, bestDealScore}` across completed matches. **`netChips` is a heuristic** (winner-takes-the-table projection from `stakeAmount`), not a read of the wallet ledger — see the wallet note above. |
