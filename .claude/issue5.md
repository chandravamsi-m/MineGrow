## Context
The mobile app (PR #6) now fetches the payment UPI ID from `GET /app/config`. Without an admin UI to edit that value, the only way to rotate the UPI ID is a direct DB write — too risky for production. This issue covers both the backend admin endpoints and the React Settings page.

Depends on the companion issue *"Backend: app_config table + GET /app/config endpoint"* being merged first.

## Acceptance criteria

### Backend
- [ ] `GET /admin/app-config` — list all rows from `app_config` (admin-only, JWT-protected)
- [ ] `PATCH /admin/app-config/:key` — body `{ "value": "..." }`, updates row + sets `updated_by` from JWT claims + writes an audit log entry
- [ ] Wire into existing `admin.module.ts` / `admin.controller.ts`

### Admin frontend
- [ ] New sidebar entry **Settings** in `minegrow_admin/src/components/Sidebar.tsx`
- [ ] New page component `minegrow_admin/src/components/SettingsPanel.tsx`
- [ ] Page shows a form with each `app_config` key as an editable field:
  - Payment UPI ID (text input)
  - (Future) OTP resend delay, minimum app version, feature flags, etc.
- [ ] Save button → `PATCH /admin/app-config/:key`
- [ ] Use the existing `ToastContext` for success/error feedback
- [ ] Use the existing `ConfirmContext` to confirm changes to the UPI ID (high-impact change)

## Files
- `minegrow_backend/src/admin/admin.controller.ts` (add 2 routes)
- `minegrow_backend/src/admin/admin.service.ts` (add 2 service methods + audit-log writes)
- `minegrow_admin/src/components/Sidebar.tsx` (add menu entry)
- `minegrow_admin/src/components/SettingsPanel.tsx` (new)
- `minegrow_admin/src/App.tsx` (register route)
