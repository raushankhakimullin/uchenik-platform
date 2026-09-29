# НЕ ПРИХОЖАНИН. УЧЕНИК.

Отдельная русскоязычная платформа ученичества Sons of God для будущего uchenik.sonsofgod.ru. Основной сайт sonsofgod.ru и почта не меняются.

## Run & Operate

- `pnpm --filter @workspace/uchenik-platform run dev` — Next.js app (managed workflow)
- `pnpm --filter @workspace/uchenik-platform run typecheck` — application typecheck
- `pnpm --filter @workspace/uchenik-platform run build` — application build
- Required variables: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` (set via Replit Secrets). Never add service_role key to client.
- The pre-existing API server and Replit DB packages are template utilities, not the user data store for this product.

## Stack

- Next.js + React + TypeScript + Tailwind
- Supabase Auth, PostgreSQL and Row Level Security. Do not substitute localStorage or Replit DB for user data.

## Where things live

- `artifacts/uchenik-platform/` — web app
- `supabase/migrations/` — schema, policies and initial learning content
- `README.md` — setup and Beget / DNS options

## Architecture decisions

- Confirmed account-to-account discipleship needs recipient acceptance; an unregistered contact is a personal note, never a confirmed link.
- Only group invitations tied to the signed-in user's email can grant membership; group IDs do not.
- Beget tariff is unknown: do not assume Node.js availability or touch the main site's DNS.

## Product

The path centers on action and transmission, not video views or spirituality points. Twelve school modules are listed; only the first is a complete lesson in the initial release. One GBO path is available.

## User preferences

- All user-facing copy in Russian. Brand palette #0F1412, #2E3A2F, #D9C9A6, #F6F4EE, #C9A961; Montserrat ExtraBold and Inter.
- Keep Next.js and Supabase. Telegram and CDN are preparation only until actually connected.

## Gotchas

- Do not call this production-ready until Supabase migrations, secrets, auth email, role access, and hosting/domain are tested against real accounts.
- Replit's artifact was initially scaffolded from a React/Vite template, but the user explicitly requires Next.js; the product code and workflow must run Next.js.

## Pointers

- See the `pnpm-workspace` skill for workspace structure, TypeScript setup, and package details
