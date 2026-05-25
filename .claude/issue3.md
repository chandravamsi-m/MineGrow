## Context
The mobile app (PR #6) reads `notification_preferences` from the user profile and uses it as the default for the in-app notification settings screen. Currently the column doesn't exist — mobile gracefully falls back to constants, but per-user defaults aren't honored.

## Acceptance criteria

### DB migration
- [ ] Add column to `users`:
  ```sql
  ALTER TABLE users
  ADD COLUMN notification_preferences JSONB
  DEFAULT '{"push": true, "investments": true, "wallet": true, "promotions": false}'::jsonb;
  ```

### Profile endpoint
- [ ] `GET /users/profile` response includes `notification_preferences` object:
  ```json
  {
    "id": 1,
    "full_name": "...",
    "notification_preferences": {
      "push": true,
      "investments": true,
      "wallet": true,
      "promotions": false
    }
  }
  ```

### Update endpoint
- [ ] New `PATCH /users/notification-preferences` (auth-required) accepting:
  ```json
  { "push": true, "investments": true, "wallet": false, "promotions": false }
  ```
  All four keys optional — only the provided ones are updated.

## Files to modify
- `minegrow_backend/src/users/users.service.ts` (include field in profile read)
- `minegrow_backend/src/users/users.controller.ts` (add PATCH route)
- `minegrow_backend/src/users/users.dto.ts` (add `UpdateNotificationPreferencesDto`)
- `minegrow_backend/supabase/schema.sql` (column addition)

## Mobile-side wiring (already done in PR #6)
- `UserProfile.notificationPreferences` field added
- `NotificationPreferences` class in `app_models.dart`
- Notification settings screen reads profile prefs as fallback default
