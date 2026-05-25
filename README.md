# MineGrow

A full-stack gold-mining **investment platform** where users invest via UPI, earn daily ROI on a 90-day lock, and withdraw principal + returns through a moderated workflow.

The repo is a monorepo containing three independent applications that share a single Supabase (PostgreSQL) database.

---

## Table of Contents

- [Overview](#overview)
- [Repository Layout](#repository-layout)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [How the Product Works](#how-the-product-works)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [1. Database (Supabase)](#1-database-supabase)
  - [2. Backend (NestJS API)](#2-backend-nestjs-api)
  - [3. Admin Panel (React + Vite)](#3-admin-panel-react--vite)
  - [4. Mobile App (Flutter)](#4-mobile-app-flutter)
- [Environment Variables](#environment-variables)
- [API Documentation](#api-documentation)
- [Scripts Cheat-Sheet](#scripts-cheat-sheet)
- [Project Conventions](#project-conventions)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

MineGrow lets retail users put money into one of three fixed investment plans, collect daily ROI accruals automatically via cron, and withdraw earnings on a moderated cycle. Administrators approve deposits/withdrawals and manage plans, users, and the audit ledger from a dedicated web console.

| Plan        | Amount Range (INR) | Daily ROI | Lock Period | Withdraw Cycle |
| ----------- | ------------------ | --------- | ----------- | -------------- |
| Starter     | 1,000 – 10,000     | 1.00 %    | 90 days     | every 30 days  |
| Silver      | 10,001 – 50,000    | 1.20 %    | 90 days     | every 30 days  |
| Gold        | 50,001 – 500,000   | 1.50 %    | 90 days     | every 30 days  |

> Plan parameters are configurable at runtime via the admin panel and stored in the `investment_plan` table.

---

## Repository Layout

```
MineGrow/
├── minegrow_backend/      # NestJS 11 REST API (Supabase + Firebase Admin)
├── minegrow_admin/        # React 19 + Vite 8 admin console (TypeScript)
├── minegrow_mobile/       # Flutter end-user mobile app (Riverpod + GoRouter)
└── README.md              # You are here
```

Each sub-project has its own `README.md`, `package.json` / `pubspec.yaml`, and can be run independently.

---

## Architecture

```
                    ┌──────────────────────┐
                    │   Flutter Mobile     │
                    │   (end users)        │
                    └──────────┬───────────┘
                               │ HTTPS
                               │  /api/v1/*
                               ▼
┌──────────────────┐   ┌──────────────────────┐   ┌─────────────────────┐
│  React Admin     │──▶│   NestJS Backend     │──▶│  Supabase           │
│  Console         │   │   (port 3000)        │   │  (PostgreSQL)       │
└──────────────────┘   │  JWT · Helmet ·      │   └─────────────────────┘
                       │  Throttler · Swagger │
                       │                      │   ┌─────────────────────┐
                       │                      │──▶│  Firebase Admin     │
                       │                      │   │  (push notif.)      │
                       │                      │   └─────────────────────┘
                       │   @nestjs/schedule   │
                       │   (daily ROI cron)   │
                       └──────────────────────┘
```

- **API contract** — every response is wrapped by `TransformInterceptor` into `{ success: boolean, data: <payload> }`. Errors flow through `HttpExceptionFilter` in the same envelope.
- **Auth** — phone-number + OTP for users, email + password for admins; both exchange for a custom JWT.
- **Cron** — `RoiCronModule` accrues daily ROI on active investments and triggers maturity transitions.
- **Audit** — every state-changing action writes to the audit ledger surfaced in the admin console's `LedgerViewer`.

---

## Tech Stack

### Backend — [`minegrow_backend/`](minegrow_backend/)
- **Runtime:** Node.js + TypeScript 5.7
- **Framework:** NestJS 11 (`@nestjs/common`, `@nestjs/core`, `@nestjs/platform-express`)
- **Database:** Supabase / PostgreSQL (`@supabase/supabase-js`)
- **Auth:** `@nestjs/jwt`, `@nestjs/passport`, `passport-jwt`, `bcryptjs`
- **Security:** `helmet`, `@nestjs/throttler`, `class-validator`, `class-transformer`, `joi`
- **Push:** `firebase-admin`
- **Scheduling:** `@nestjs/schedule`
- **Docs:** `@nestjs/swagger` (mounted at `/api-docs`)
- **Testing:** Jest + Supertest

Feature modules (`src/`):
`admin`, `app-config`, `audit`, `auth`, `common`, `config`, `cron`, `investments`, `notifications`, `plans`, `sms`, `uploads`, `users`, `wallet`, `withdrawals`.

### Admin Panel — [`minegrow_admin/`](minegrow_admin/)
- **Framework:** React 19 + TypeScript
- **Bundler:** Vite 8
- **Styling:** Tailwind CSS 4 (`@tailwindcss/vite`, `postcss`, `autoprefixer`)
- **Icons:** `lucide-react`
- **State:** React Context (`AuthContext`, `ToastContext`, `ConfirmContext`)

Top-level views (`src/components/`):
`Dashboard`, `UsersList`, `DepositsQueue`, `WithdrawalsQueue`, `PlansManager`, `LedgerViewer`, `Settings`, `Sidebar`.

### Mobile App — [`minegrow_mobile/`](minegrow_mobile/)
- **Framework:** Flutter (Dart SDK ^3.11.5)
- **State:** `flutter_riverpod` 3
- **Routing:** `go_router` 17
- **HTTP:** `dio` 5 + `http`
- **Secure storage:** `flutter_secure_storage`, `shared_preferences`
- **UI bits:** `pinput` (OTP), `qr_flutter` (UPI QR), `file_picker` (payment proof upload), `intl`, `logger`, `flutter_dotenv`
- **Icon generation:** `flutter_launcher_icons`

Feature folders (`lib/src/features/`):
`splash`, `auth`, `app_config`, `home`, `dashboard`, `investments`, `wallet`, `history`, `withdrawal`, `notifications`, `profile`.

Shared widget library: [`lib/src/shared/widgets/mg_widgets.dart`](minegrow_mobile/lib/src/shared/widgets/mg_widgets.dart) (MGScaffold, MGCard, MGGradientButton, MGTextField, MGSegmentedControl, MGActivePlanCard, AmountChip, etc.).

---

## How the Product Works

**End-user flow (mobile):**
1. **Auth** — user enters phone, receives OTP, verifies, completes onboarding.
2. **Dashboard** — sees wallet summary, active plan card, recent activity.
3. **Invest** — picks a plan, sees the UPI QR + UPI ID, pays externally, uploads payment proof + UTR.
4. **Pending → Approved** — admin reviews the deposit; once approved the investment becomes `active`, `start_date` and `maturity_date` are set.
5. **Daily ROI** — cron accrues `daily_roi_pct` of principal into the wallet's ROI bucket every day.
6. **Withdraw** — user picks Bank or UPI, hits an amount chip (or "All"), and submits. Eligibility rules gate the button.
7. **History & notifications** — ROI history, withdrawal history, and push notifications keep the user informed.

**Admin flow (web console):**
- Approve/reject pending deposits in **DepositsQueue**.
- Approve/reject withdrawals in **WithdrawalsQueue**.
- Edit users, suspend, adjust wallet (audited).
- Configure plans (`PlansManager`), runtime settings (`Settings`), inspect the audit ledger (`LedgerViewer`).

---

## Getting Started

### Prerequisites

| Tool             | Version        | Used by                |
| ---------------- | -------------- | ---------------------- |
| Node.js          | ≥ 20 LTS       | backend, admin         |
| npm              | ≥ 10           | backend, admin         |
| Flutter SDK      | 3.11.5+        | mobile                 |
| Dart SDK         | ^3.11.5        | mobile (via Flutter)   |
| Supabase project | any            | backend (DB)           |
| Firebase project | any            | backend (push notif.)  |
| Android Studio / Xcode | latest    | mobile build targets   |

### 1. Database (Supabase)

1. Create a new Supabase project at <https://supabase.com>.
2. In the SQL editor, run [`minegrow_backend/supabase/schema.sql`](minegrow_backend/supabase/schema.sql).
3. Apply migrations in order from [`minegrow_backend/supabase/migrations/`](minegrow_backend/supabase/migrations/):
   ```
   01_add_kyc_admin_notes.sql
   02_add_app_config_and_prefs.sql
   03_add_investment_plan_image_and_crud.sql
   04_fix_user_address_and_plan_created_at.sql
   05_admin_wallet_adjustment_function.sql
   06_support_legal_app_config.sql
   ```
4. Copy the project URL and the **service role** key — you'll need them for the backend `.env`.

### 2. Backend (NestJS API)

```powershell
cd minegrow_backend
npm install
# create .env (see Environment Variables section below)
npm run dev          # watch mode (nest start --watch)
```

The API boots at `http://localhost:3000/api/v1` and serves Swagger UI at `http://localhost:3000/api-docs`.

### 3. Admin Panel (React + Vite)

```powershell
cd minegrow_admin
npm install
npm run dev          # Vite dev server (default http://localhost:5173)
```

The admin panel expects the backend to be reachable; configure the API base URL in [`minegrow_admin/src/services/`](minegrow_admin/src/services/) (or via a `.env` file consumed by Vite — see that folder for the exact env var name).

### 4. Mobile App (Flutter)

```powershell
cd minegrow_mobile
flutter pub get
# create .env next to pubspec.yaml with API_BASE_URL=http://10.0.2.2:3000/api/v1 (Android emulator)
flutter run          # picks first connected device/emulator
```

> On Android emulators use `10.0.2.2` to reach your host machine's `localhost`. On iOS simulators use `localhost` directly.

To regenerate launcher icons after changing the brand asset:
```powershell
flutter pub run flutter_launcher_icons
```

---

## Environment Variables

### Backend `.env` (in `minegrow_backend/`)

Validated by Joi at boot (`src/config/env.validation.ts`). Required keys typically include:

```env
# Server
PORT=3000
NODE_ENV=development
CORS_ALLOWED_ORIGINS=http://localhost:5173,http://localhost:5174

# Supabase
SUPABASE_URL=https://<your-project>.supabase.co
SUPABASE_SERVICE_ROLE_KEY=<service-role-key>

# JWT
JWT_SECRET=<long-random-string>
JWT_EXPIRES_IN=7d

# Firebase Admin (push notifications)
FIREBASE_PROJECT_ID=...
FIREBASE_CLIENT_EMAIL=...
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"

# SMS / OTP provider
SMS_API_KEY=...
SMS_SENDER_ID=...
```

> Inspect [`minegrow_backend/src/config/env.validation.ts`](minegrow_backend/src/config/env.validation.ts) for the authoritative list of required and optional keys.

### Mobile `.env` (in `minegrow_mobile/`)

```env
API_BASE_URL=http://10.0.2.2:3000/api/v1
```

Loaded via `flutter_dotenv` and bundled as an asset (see `pubspec.yaml` `assets:` section).

---

## API Documentation

Swagger UI is generated automatically and served at:

```
http://localhost:3000/api-docs
```

All response payloads are wrapped:

```json
{ "success": true, "data": { /* ... */ } }
```

```json
{ "success": false, "error": { "code": "...", "message": "..." } }
```

Protected routes use a Bearer JWT (`Authorization: Bearer <token>`) — Swagger UI has an **Authorize** button preconfigured for it.

---

## Scripts Cheat-Sheet

### Backend
| Command              | Purpose                              |
| -------------------- | ------------------------------------ |
| `npm run dev`        | Start API in watch mode              |
| `npm run start`      | Start API once                       |
| `npm run build`      | Compile TypeScript to `dist/`        |
| `npm run prod`       | Run compiled `dist/main.js`          |
| `npm run lint`       | ESLint with `--fix`                  |
| `npm run format`     | Prettier write `src/` and `test/`    |
| `npm test`           | Jest unit tests                      |
| `npm run test:e2e`   | Jest e2e tests                       |
| `npm run test:cov`   | Jest with coverage                   |

### Admin
| Command           | Purpose                          |
| ----------------- | -------------------------------- |
| `npm run dev`     | Vite dev server                  |
| `npm run build`   | `tsc -b && vite build` → `dist/` |
| `npm run preview` | Preview production build         |
| `npm run lint`    | ESLint                           |

### Mobile
| Command                                  | Purpose                          |
| ---------------------------------------- | -------------------------------- |
| `flutter pub get`                        | Fetch Dart packages              |
| `flutter run`                            | Run on connected device          |
| `flutter build apk --release`            | Release APK                      |
| `flutter build appbundle --release`      | Play Store bundle                |
| `flutter build ios --release`            | Release iOS build                |
| `flutter pub run flutter_launcher_icons` | Regenerate launcher icons        |
| `flutter test`                           | Run widget/unit tests            |

---

## Project Conventions

- **Response envelope:** never return raw payloads from controllers — let `TransformInterceptor` wrap them so the mobile + admin clients can rely on `{ success, data }`.
- **Validation:** DTOs use `class-validator` decorators; the global `ValidationPipe` runs with `whitelist: true` and `forbidNonWhitelisted: true`.
- **Rate limiting:** global default is 60 requests / minute / IP via `ThrottlerGuard`. Override per-route with `@Throttle(...)`.
- **Audit:** any write that affects user funds, KYC, or plan state must be recorded via the `AuditModule`.
- **Mobile state:** prefer Riverpod providers over raw `setState` for anything that crosses screens; use `ConsumerStatefulWidget` when you need both.
- **Mobile widgets:** reach for shared widgets in `mg_widgets.dart` before building new ones — most flows already have a matching primitive.

---

## Contributing

1. Branch from `main` using a topic prefix (`feat/...`, `fix/...`, `chore/...`).
2. Keep changes scoped to one sub-project where possible; cross-cutting changes (API contract + mobile consumer) belong in a single PR.
3. Run the relevant lint/test commands before pushing.
4. Open a PR against `main` with a short summary and a manual test plan.

---

## License

Private / proprietary. All rights reserved by the MineGrow team. Sub-project READMEs that ship with their framework's default boilerplate (e.g. the NestJS starter README) reflect that framework's license, not this repository's.
