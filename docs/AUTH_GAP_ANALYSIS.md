# Trust Rummy — Authentication Gap Analysis

**Date:** 2026-07-22 (updated after MVP Critical/High hardening)  
**Stack:** Spring Boot 3, PostgreSQL, JWT, `users` + `refresh_tokens` tables, Flutter clients  
**Scope:** Historical gap analysis — see canvas `mvp-auth-audit` and current code for live status.  
**Note:** Access JWT is **15m**, refresh tokens are **SHA-256 hashed at rest**, password-change
revokes all refresh rows, Flutter uses `flutter_secure_storage` + `ApiClient` 401 refresh.

---

## Summary

> **2026-07-22:** Critical/High session hardening from this doc is largely **done** on
> `feature/auth-mvp-session-hardening` (hashed refresh, reuse revoke-all, rate limits, 15m JWT,
> WS active-user check, Flutter cold-start refresh). Remaining body sections may still describe
> the old “missing” state — prefer the note at top + canvas `mvp-auth-audit` for current truth.
> Still deferred: email/MFA/OAuth, access-token blocklist, stronger password policy, wallet-grade ops.

Core auth for the Flutter lobby + WebSocket game loop is **in place** for MVP/dev. Wallet-grade
account recovery and some production ops remain open (see deferred list above).

| Layer | Verdict |
|-------|---------|
| Dev / MVP multiplayer auth | Critical/High gaps closed on auth branch |
| Production (wallet + recovery + MFA) | Post-MVP gaps remain |

---

## 1. What Already Exists

### 1.1 Key files

| Layer | Path | Key types / methods |
|-------|------|---------------------|
| Controller | `backend/.../controller/AuthController.java` | `register`, `login`, `refresh`, `logout` |
| Controller | `backend/.../controller/UserController.java` | `me`, `updateMe`, `changePassword` |
| Service | `backend/.../service/AuthService.java` | `register`, `login`, `refresh`, `logout`, `issueAuthResponse`, `issueRefreshToken` |
| Service | `backend/.../service/UserProfileService.java` | `changePassword`, `getProfile`, `updateProfile` |
| JWT util | `backend/.../security/JwtTokenUtil.java` | `generateToken`, `validateToken`, `isTokenValid`, `extractUsername` |
| Filter | `backend/.../security/JwtAuthenticationFilter.java` | Bearer header on REST |
| WS handshake | `backend/.../security/JwtHandshakeInterceptor.java` | `beforeHandshake` |
| UserDetails | `backend/.../security/CustomUserDetailsService.java` | `loadUserByUsername` |
| Security config | `backend/.../config/SecurityConfig.java` | Filter chain, CORS, BCrypt |
| WS config | `backend/.../config/WebSocketConfig.java` | Interceptor on `/ws/**` |
| Entities | `User.java`, `RefreshToken.java` | |
| Repos | `UserRepository.java`, `RefreshTokenRepository.java` | |
| Migration | `backend/.../db/migration/V1__baseline.sql` | `users`, `refresh_tokens` |
| Config | `application.properties` | `jwt.secret`, `jwt.expiration-ms`, CORS |
| Flutter | `frontend/lib/services/auth_api_service.dart` | register/login/refresh/logout |
| Flutter | `frontend/lib/services/user_api_service.dart` | profile + change password |
| Flutter UI | `frontend/lib/screens/account_test_screen.dart` | Manual auth test UI |

### 1.2 Flows implemented

| Flow | Endpoint | Status |
|------|----------|--------|
| Register | `POST /api/v1/auth/register` | Implemented |
| Login | `POST /api/v1/auth/login` | Implemented |
| Refresh | `POST /api/v1/auth/refresh` | Implemented (rotates refresh) |
| Logout | `POST /api/v1/auth/logout` | Implemented (revokes refresh if provided) |
| Change password | `PUT /api/v1/users/me/password` | Implemented (JWT required) |
| Profile get/update | `GET` / `PUT /api/v1/users/me` | Implemented |
| Forgot / reset password | — | **Missing** |
| Email verify | — | **Missing** |
| Logout-all / list sessions | — | **Missing** |

### 1.3 Request / response shapes

```text
POST /api/v1/auth/register
  body: { username (3–32), email, password (6–128), displayName? }
  → 200 AuthResponse

POST /api/v1/auth/login
  body: { username, password }
  → 200 AuthResponse
  → 401 { timestamp, status, error: "Invalid credentials" }

POST /api/v1/auth/refresh
  body: { refreshToken }
  → 200 AuthResponse
  → 400 invalid token (IllegalArgumentException)
  → 409 expired/revoked (IllegalStateException)
      (docs sometimes say 400 — documentation drift)

POST /api/v1/auth/logout
  body: { refreshToken? }   // optional; empty → no-op
  → 204

AuthResponse:
  { token, tokenType: "Bearer", username, expiresInMs, refreshToken }

PUT /api/v1/users/me/password   (Authorization: Bearer <jwt>)
  body: { currentPassword, newPassword (6–128) }
  → 204
```

### 1.4 JWT creation / validation / claims / expiry

**Creation** (`JwtTokenUtil.generateToken`):
- Claims: `sub` = username; `iat`; `exp`; optional empty `extraClaims`
- **No** `iss`, `aud`, `jti`, user id, role, or email claims
- Algorithm: HMAC-SHA via `Keys.hmacShaKeyFor(secret)`

**Validation:**
- REST filter: signature + subject match + not expired
- WS handshake: `isTokenValid` only (signature/parse); does **not** re-check user active or load `UserDetails`

**Lifetimes:**

| Token | Lifetime | Source |
|-------|----------|--------|
| Access JWT | 86,400,000 ms (**24h**) | `jwt.expiration-ms=86400000` in `application.properties` |
| Refresh | **30 days** | Hardcoded `AuthService.REFRESH_TOKEN_EXPIRATION_MS` |
| `AuthResponse.expiresInMs` | Hardcoded 86,400,000 | Can desync if `jwt.expiration-ms` is changed without updating `AuthService` |

### 1.5 Refresh token storage / rotation / revocation

**Storage** (`refresh_tokens` in `V1__baseline.sql`):
- Columns: `id`, `token` (unique VARCHAR 128), `user_id`, `revoked`, `expires_at`, `created_at`
- Opaque Base64url from 48 random bytes
- Stored **plaintext** in DB
- Repository: `findByToken` only — no `findByUser`, no revoke-all

**Rotation** (`AuthService.refresh`):
1. Lookup by token  
2. Reject if revoked or expired  
3. Mark old row `revoked=true`  
4. Issue new access + new refresh  

**Revocation:**
- Logout: revoke single refresh if provided; silent no-op otherwise  
- **No** revoke-on-password-change  
- **No** reuse detection / family invalidation  
- Access JWT **not** blocklisted  

### 1.6 Security filter chain / CORS / CSRF

`SecurityConfig.securityFilterChain`:
- CSRF disabled (typical for Bearer JWT)
- Session: `STATELESS`
- `permitAll`: `/api/v1/auth/**`, `/actuator/health`, `/ws/**`
- Everything else: authenticated
- JWT filter before `UsernamePasswordAuthenticationFilter`
- Password encoder: `BCryptPasswordEncoder`

**CORS:** origins from `cors.allowed-origins` (localhost ports); methods GET/POST/PUT/PATCH/DELETE/OPTIONS; headers Authorization, Content-Type, Accept; `allowCredentials=true`.

**WS CORS:** `http://localhost:*`, `http://127.0.0.1:*`.

### 1.7 User model & password hashing

`User` fields: `id`, `username`, `email`, `passwordHash`, `displayName`, `walletBalance`, `role` (default `"PLAYER"`), `active` / `is_active` (default true), `createdAt`, `updatedAt`.

- Hashing: BCrypt on register and change-password  
- `CustomUserDetailsService` maps `ROLE_{role}` and uses `user.isActive()` as Spring `enabled`  
- Unique: username + email (DB + entity)

### 1.8 WebSocket JWT handshake

`JwtHandshakeInterceptor`:
1. Token from `?token=` query **or** `Authorization: Bearer`  
2. `isTokenValid` → else 401, reject upgrade  
3. Puts `username` + `token` into session attributes  

Wired on `/ws/telemetry` and `/ws/game/{roomCode}`. REST JWT filter skips `/ws/**`. Flutter `ApiConfig` puts JWT in the WebSocket query string.

### 1.9 Tests covering auth

**No dedicated auth tests.**

Auth is only a helper in game integration tests (`AbstractGameIntegrationTest.register()` → `POST /api/v1/auth/register`) used to mint JWTs for WS/settlement/lifecycle tests.

Not covered: login failure, refresh rotation/replay, logout, change password, expired JWT, WS handshake reject, inactive user.

---

## 2. What Is Missing

### 2.1 APIs / features

- Forgot / reset password (token email flow)  
- Email verification / resend  
- Logout-all-devices / revoke all refresh tokens  
- List active sessions / devices  
- Access-token blocklist **or** short-lived access + forced re-auth after logout  
- Admin lock/disable user API (`is_active` unused beyond `UserDetails`)  
- Role-based authorization (`@PreAuthorize` / `hasRole` nowhere — role is decorative)  
- Refresh-token reuse → kill token family  
- Password change → revoke all refreshes  
- Optional `GET /api/v1/auth/me` introspection (profile already under `/users/me`)  

### 2.2 Database gaps

- No index on `refresh_tokens(user_id)` (needed for logout-all / cleanup)  
- No `replaced_by` / `family_id` / `device_info` / `ip` / `user_agent` on refresh tokens  
- No password-reset / email-verify token tables  
- No `failed_login_attempts` / `locked_until` on users  
- Refresh token stored plaintext (hash-at-rest would be stronger)  
- No cleanup job for expired/revoked rows  

### 2.3 Config gaps

- No `jwt.issuer` / `jwt.audience`  
- No key rotation / JWKS / `kid`  
- No separate refresh TTL property (hardcoded 30d)  
- Default JWT secret in properties if `JWT_SECRET` unset  
- DB password committed in `application.properties`  
- README still documents `/api/auth/*` (missing `v1`)  

### 2.4 Frontend gaps

- `shared_preferences` in `pubspec.yaml` but never used — no JWT persistence  
- No `flutter_secure_storage` (or equivalent) for refresh token  
- Tokens live in `TextEditingController`s on test screens only  
- No auth session service / auto-refresh interceptor on 401  
- No production login/register UI — only test screens  
- JWT in WS URL query (proxy/log leakage risk)  
- No proactive refresh before access expiry (`expiresInMs` ignored)  

---

## 3. Security Issues

| Severity | Issue | Evidence / notes |
|----------|-------|------------------|
| **High** | Default/weak JWT secret in repo | `application.properties`: `change-this-dev-only-secret-key-min-32-chars!!` |
| **High** | DB credentials committed | `application.properties` datasource password |
| **High** | Access JWT valid **24h** after logout | Logout only revokes refresh; no access blocklist |
| **High** | JWT in WS query string | `api_config.dart` game/telemetry WS URIs; interceptor prefers query param |
| **Medium** | Refresh reuse does not kill family | Revoked replay fails; other sessions keep working |
| **Medium** | Change password leaves all refresh tokens valid | `UserProfileService.changePassword` — no refresh revoke |
| **Medium** | Refresh tokens plaintext in DB | `RefreshToken.token` column |
| **Medium** | No rate limiting / lockout on login/register/refresh | No matches in codebase |
| **Medium** | Weak password policy (min 6, no complexity) | Register / change-password DTOs |
| **Medium** | Roles never enforced | `ROLE_*` set but no method security |
| **Medium** | WS handshake does not check `is_active` | `isTokenValid` only |
| **Low** | `expiresInMs` hardcode vs config | `AuthService` vs `@Value jwt.expiration-ms` |
| **Low** | CSRF off + CORS credentials | Acceptable for Bearer apps; tighten origins for prod |
| **Low** | Flutter tokens in plain UI fields | Test screens; secure storage unused |
| **Info** | Docs say refresh replay → 400; code → **409** | RULES_ENGINE vs `IllegalStateException` → CONFLICT |

---

## 4. Required APIs

### 4.1 Keep / harden (already exist)

| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/api/v1/auth/register` | Onboarding |
| `POST` | `/api/v1/auth/login` | Session start |
| `POST` | `/api/v1/auth/refresh` | Silent renew for lobby + WS reconnect |
| `POST` | `/api/v1/auth/logout` | End session (should revoke refresh; ideally shorten access TTL) |
| `GET` | `/api/v1/users/me` | Lobby identity / wallet badge |
| `PUT` | `/api/v1/users/me` | Display name / email |
| `PUT` | `/api/v1/users/me/password` | Account security |

### 4.2 Add for production

| Method | Path | Why |
|--------|------|-----|
| `POST` | `/api/v1/auth/forgot-password` | Recovery without support tickets |
| `POST` | `/api/v1/auth/reset-password` | Complete recovery with one-time token |
| `POST` | `/api/v1/auth/verify-email` | Trust email for wallet/payouts later |
| `POST` | `/api/v1/auth/resend-verification` | UX |
| `POST` | `/api/v1/auth/logout-all` | Theft / shared device / after password change |
| `GET` | `/api/v1/auth/sessions` | Optional: show/revoke devices |
| `DELETE` | `/api/v1/auth/sessions/{id}` | Optional companion |

### 4.3 Hardening that is not a new route (but required)

- Shorten access JWT (e.g. **5–15 min**); keep refresh 7–30d with rotation **+ reuse detection**  
- Hash refresh tokens at rest; index `user_id`; revoke all on password change  
- Rate-limit `/login`, `/register`, `/refresh`, `/forgot-password`  
- Flutter: secure storage + refresh-on-401 + reconnect WS with fresh token  
- Stop putting long-lived JWT in query strings where possible (or use short-lived WS ticket endpoint)  

### 4.4 Already auth-gated (present)

- Wallet: `/api/v1/wallet/*`  
- Rooms: `/api/v1/rooms/*`  
- History: `/api/v1/history/*`  
- WS: `/ws/game/{roomCode}?token=...`  

---

## 5. Concise Gap Checklist

1. No forgot/reset/verify-email APIs or tables  
2. No dedicated auth unit/integration tests  
3. No Flutter secure/persistent session layer (despite `shared_preferences` dependency)  
4. 24h access tokens + logout that cannot kill them  
5. Refresh rotation without theft/family kill; plaintext storage; no `user_id` index  
6. Password change does not invalidate sessions  
7. Weak/default secrets and DB password in config  
8. No rate limit / lockout / email verification  
9. Roles unused; inactive user not checked on WS  
10. JWT missing issuer/audience/jti; no key rotation  
11. Docs drift: README paths; refresh error code 400 vs 409  

---

## 6. Suggested Implementation Priority (for a follow-up plan)

1. **Session hygiene** — short access TTL, refresh hashing + reuse detection, revoke-all on logout/password change  
2. **Account recovery** — forgot/reset password APIs + tables  
3. **Flutter session layer** — secure storage, auto-refresh, safer WS auth  
4. **Email verification** — verify/resend (especially before payouts)  
5. **Hardening** — rate limits, lockout, secrets via env, auth tests, docs sync  

---

*Generated from codebase review of Trust Rummy auth stack. No code was changed as part of this analysis.*
