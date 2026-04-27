# ANITA

**AI-native personal finance companion** — chat with your money, track spending and goals, optionally link a bank via Stripe, and keep everything synced across **native iOS**, a **React** web app, and a **Node** backend.

This monorepo is the full stack behind ANITA: product UI, API, auth, subscriptions, and analytics wired for real-world use (including TestFlight-style flows).

---

## What it does

| Area | Highlights |
|------|------------|
| **Chat** | Conversational finance assistant powered by a backend LLM pipeline; onboarding language (EN/DE), consent for third‑party processing, premium gating. |
| **Finance** | Dashboards, categories, goals, limits, XP progression, manual transactions — or bank-fed data when linked. |
| **Accounts** | Supabase Auth (Apple, Google, email), profile sync, secure token use toward the API. |
| **Money movement** | Stripe Financial Connections for bank linking; Stripe subscriptions / App Store IAP patterns depending on surface. |
| **Insight** | PostHog analytics on iOS; backend aggregates transactions and metrics for the apps. |

---

## Architecture

```text
  ANITA iOS (SwiftUI) ──HTTPS / JWT──► ANITA backend (Express, TypeScript)
         │                                      │
         │                                      ├── Stripe (Financial Connections, billing)
         └──────────────────┬───────────────────┘
                            ▼
                     Supabase (Auth + Postgres)

  ANITA webapp (React, TS) ──► same backend & Supabase
  Landing page (Vite + React) ──► marketing / funnel
```

---

## Tech stack

| Layer | Choices |
|--------|---------|
| **Mobile** | SwiftUI, Combine/async-await, StoreKit 2 · Stripe iOS SDK (Financial Connections), PostHog iOS SDK, Google Sign-In, AppAuth patterns |
| **Backend** | Node 20+, Express 5, TypeScript, Stripe server SDK, `@supabase/supabase-js`, CORS, `dotenv` |
| **Web app** | React 18, TypeScript, CRA-style tooling, Radix UI, Stripe.js, Supabase client, Framer Motion, OCR/document helpers where needed |
| **Landing** | Vite + React |
| **Data / auth** | Supabase (Auth + Postgres API) |
| **Hosting** | Backend deployable on **Railway** (`railway.json` at repo root); frontend often static or Node host |
| **Payments** | Stripe (Financial Connections + subscriptions); Apple IAP via StoreKit on iOS |

---

## Repository layout

| Path | Purpose |
|------|---------|
| [`ANITA IOS/`](./ANITA%20IOS/) | Xcode project — SwiftUI app, networking, onboarding, subscriptions |
| [`ANITA backend/`](./ANITA%20backend/) | REST API: chat completion, transactions, Stripe sessions, Supabase-backed flows |
| [`ANITA webapp/`](./ANITA%20webapp/) | Full-featured web client (parity with core flows) |
| [`anita-landing-page/`](./anita-landing-page/) | Lightweight marketing site |
| [`docs/`](./docs/) | Deep-dive guides (e.g. bank connection troubleshooting) |

Folder names match historical Xcode / tooling paths (`ANITA IOS` with a space). Prefer quoting paths in shell: `cd "ANITA IOS"`.

---

## Getting started (contributors)

### Prerequisites

- Xcode (latest stable for iOS targets), Node **20+**, npm  
- Supabase project + Stripe account (for full flows)  
- Optional: Railway CLI / dashboard for backend deploys  

### Backend

```bash
cd "ANITA backend"
cp .env.example .env   # if present; otherwise create .env per backend README / SECURITY notes
npm install
npm run dev
# default dev server (see backend logs), often http://localhost:3001
```

Set secrets in `.env` — **never commit** `.env`. See [`ANITA backend/SECURITY.md`](./ANITA%20backend/SECURITY.md) where applicable.

### iOS

Open `ANITA IOS/ANITA.xcodeproj` in Xcode. Configure signing for your team.  
For device testing against a Mac-hosted API, set **Settings → Backend URL** to `http://<your-mac-lan-ip>:3001` (same Wi‑Fi as the phone).

### Web / landing

```bash
cd "ANITA webapp" && npm install && npm start   # or the script defined in package.json
cd anita-landing-page && npm install && npm run dev
```

---

## Docs

- **[Stripe Financial Connections](docs/stripe-financial-connections.md)** — local backend vs Railway, TestFlight checks, common errors.

---

## Security & open source

- Do **not** commit production API keys. Use environment variables and CI secrets.  
- Client-side keys with restricted roles (e.g. Supabase anon, Stripe publishable) may appear in apps by design — still rotate if exposed and enforce **RLS** / backend validation.

---

## License

Unless otherwise noted in subfolders, confirm license per component before redistribution.

---

<p align="center">
  Built as a portfolio-grade full-stack finance product · iOS · React · Node · Supabase · Stripe
</p>
