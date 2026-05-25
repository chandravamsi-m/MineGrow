## Context
The mobile app (PR #6) fetches the payment UPI ID from a new `GET /app/config` endpoint so it can be changed without an app release. Currently the UPI ID is hardcoded in mobile env-var (`PAYMENT_UPI_ID`) and falls back to `minegrow@upi` — clearly not viable for production.

## Acceptance criteria
- [ ] New DB table `app_config (key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at TIMESTAMPTZ, updated_by INT REFERENCES users(id))`
- [ ] Seed: `INSERT INTO app_config (key, value) VALUES ('payment_upi_id', 'minegrow@upi');`
- [ ] New NestJS module `src/app-config/` with controller + service
- [ ] Public endpoint `GET /app/config` (no auth required) returning:
  ```json
  { "payment_upi_id": "minegrow@upi" }
  ```
- [ ] In-memory cache (~60s TTL) — this endpoint is hit on every payment screen open
- [ ] Wire into `app.module.ts`

## Why a separate endpoint?
- Lets admin rotate the UPI ID without an app release
- Easily extensible for other client-config (feature flags, minimum app version, etc.)

## Related
- Admin panel needs a Settings page to manage this — see companion issue
- Mobile feature lives at `minegrow_mobile/lib/src/features/app_config/` (already merged in PR #6)
