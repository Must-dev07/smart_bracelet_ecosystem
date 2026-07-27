# Smart Bracelet — Doctor Dashboard (Next.js)

Web dashboard for doctors and administrators of the newborn smart-bracelet
monitoring ecosystem. Talks to the Django backend REST API (`/api/v1/`).

> **Disclaimer** — This system flags abnormal readings for caregiver or
> medical follow-up. It is **not** a medical diagnosis device.

## Stack
- Next.js 14 (App Router) + TypeScript
- Tailwind CSS
- Chart.js via react-chartjs-2 (vitals, statistics)
- jsPDF + jspdf-autotable (real client-side PDF reports)
- JWT auth against the backend, with silent refresh + session rotation

## Pages
| Route | Access | Purpose |
|---|---|---|
| `/login` | public | Doctor/admin sign-in (parents are redirected to the mobile app) |
| `/dashboard` | doctor/admin | Stats cards, latest active alerts, bracelet fleet (auto-refresh 30 s) |
| `/patients` | doctor/admin | Patients list with search |
| `/patients/[id]` | doctor/admin | Latest reading, vitals charts (6 h/24 h/7 d/30 d, adaptive granularity), medical history (add entries), alert history |
| `/alerts` | doctor/admin | Triage: filter by status/severity, acknowledge (auto-refresh 20 s) |
| `/statistics` | doctor/admin | Alerts by type (bar), severity (doughnut), 14-day trend (line) |
| `/reports` | doctor/admin | Per-patient PDF report: identity, vitals min/avg/max, alert log, disclaimer on every page |
| `/settings` | doctor/admin | Doctor profile editing (name, phone, specialty), environment info |
| `/users` | **admin only** | Full user listing with role filter (backend returns 403 for others) |

Role gating: the sidebar hides admin links for doctors; authorization is
always enforced server-side (doctors only see their assigned babies —
foreign objects return 404).

## Setup
```bash
cp .env.example .env.local          # set NEXT_PUBLIC_API_BASE_URL
npm install
npm run dev                          # http://localhost:3100
```

Production:
```bash
npm run build && npm run start
```

The backend must allow this origin via `CORS_ALLOWED_ORIGINS`
(see `backend/.env.example`).

## Notes
- All list fetches walk DRF pagination (`?page=N`) to completion.
- Measurement queries use the backend granularity buckets
  (`raw`/`minute`/`hour`/`day`) chosen automatically from the period length.
- Tokens are stored in `localStorage`; refresh rotation on the backend
  revokes superseded sessions, and logout revokes the current one.
