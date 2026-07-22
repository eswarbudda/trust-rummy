# Lobby API gaps

Documented against the Lobby MVP (`feature/lobby-screen-mvp`).

## Implemented with existing APIs

| Feature | API |
|---------|-----|
| Profile + wallet in header | `GET /api/v1/users/me` |
| Create table | `POST /api/v1/rooms` |
| Join by code | `POST /api/v1/rooms/{code}/join` |
| Waiting room seats | `GET /api/v1/rooms/{code}` (poll) |
| Leave / cancel waiting | `POST .../leave`, `DELETE .../{code}` |
| Active tables (WAITING list) | `GET /api/v1/rooms` — no seat counts |
| Recent games | `GET /api/v1/history/matches` |
| Resume v1 | Client-persisted `roomCode` + `GET /rooms/{code}` |

## Gaps (not invented on client)

| Feature | Status | Proposed backend |
|---------|--------|------------------|
| Quick Join / matchmaking | UI disabled (“Coming soon”) | `POST /api/v1/rooms/quick-join` |
| Public / Private visibility | Not in MVP UI | `visibility` on create + list filter |
| Resume without local storage | Heuristic only | `GET /api/v1/rooms/me/active` |
| Seat counts on Active Tables | Not shown (no N+1) | Enrich list DTO with `seatedCount` |
| Avatar image | Initials only | Optional `avatarUrl` on profile |

## Waiting room → table

Host connects WS and sends `START_MATCH`. Guests poll until `IN_PROGRESS` / `DEAL_STARTED`, then open `RummyGameScreen` on the shared socket path used by the waiting room connection.
