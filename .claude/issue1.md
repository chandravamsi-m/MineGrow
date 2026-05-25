## Context
The mobile app (PR #6) now expects the OTP send response to include a `resend_delay` value so the OTP screen can show an accurate countdown instead of a hardcoded 30s.

Mobile gracefully falls back to 30s if the field is absent, but a backend-driven delay enables abuse prevention (e.g. exponential backoff on repeated requests).

## Acceptance criteria
- [ ] `POST /auth/send-otp` response includes `resend_delay` (integer, seconds)
- [ ] Default value: `30`
- [ ] (Optional) Scale on repeated requests (e.g. 30 → 60 → 120 within a 5-min window)

## File to modify
`minegrow_backend/src/auth/auth.service.ts` (around line 54)

## Suggested response shape
```json
{
  "message": "OTP dispatched successfully via Supabase",
  "resend_delay": 30
}
```

## Mobile-side wiring (already done in PR #6)
- `AuthRepository.sendOtp()` reads `resend_delay` from response
- Stored in `AuthStorageKeys.otpResendDelay`
- OTP verification screen uses stored delay to start countdown
