# Tripzo

Next.js 15 + Supabase reverse-quotation travel marketplace.

## Env vars
Copy `.env.example` to `.env.local`, fill in from Supabase → Project Settings → API:
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY` — server-only, never expose to the browser
- `NEXT_PUBLIC_SITE_URL` — your deployed URL once you have one, e.g. `https://tripzo.vercel.app`

## Push to GitHub from your phone
1. github.com → **+** → New repository → name it `tripzo` → Create (leave README/gitignore unchecked).
2. On the repo page: **Add file → Create new file**.
3. In the name field, type the full path including folders — e.g. `app/login/page.tsx` — GitHub creates the folders for you.
4. Paste that file's content below the name field, commit straight to `main`.
5. Repeat per file. For doing several at once, change `github.com` to `github.dev` in the URL — that opens a full browser code editor where you can create the whole folder tree and commit it together.

## Deploy
1. vercel.com → sign in with GitHub → **Add New → Project** → import `tripzo`.
2. Add the four env vars from `.env.example` with real values.
3. Deploy — Vercel runs `npm install` and `npm run build` in the cloud. If it fails, the build log says why; paste that log back here and I'll fix it.
4. After the first deploy: Supabase → Authentication → URL Configuration → set Site URL and Redirect URLs to your Vercel URL (needed for the email-confirmation link to work).

## This phase
Auth only — sign up, email confirmation, log in, log out, a dashboard reading your row from `public.users` through RLS. Itinerary posting, quotations, and the guest/driver/admin dashboards are next.
