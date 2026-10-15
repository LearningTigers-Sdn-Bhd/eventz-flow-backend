# Security Fixes — Deployment Configuration

Post-remediation runbook for the 2026-09-01 security sprint. Covers the **only**
config decisions you need to make when deploying. Everything not listed here works
out of the box with secure defaults.

**TL;DR — for the current Cloudflare → Coolify/Traefik → Rails setup, you need to
do _nothing_. All defaults are already correct and secure.**

---

## 1. `TRUSTED_PROXIES` (backend) — usually leave unset

**What it does:** tells Rails which upstream hops are trusted proxies, so
`request.remote_ip` resolves the **real client IP** instead of the edge proxy's IP.
This is what makes session records, audit logs and anything else reading
`request.remote_ip` attribute requests to the actual person.

**It does NOT affect Rack::Attack.** `Rack::Attack::Request` is a bare subclass of
`::Rack::Request`, so its `req.ip` uses Rack's own `ip_filter` and never consults
`trusted_proxies`. Rack's default filter already treats RFC1918 and loopback as
proxies, so the per-IP throttles resolve the real client on their own.

**Default (already in `config/application.rb`):** trusts private/Docker ranges
`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `127.0.0.0/8`, plus IPv6 `::1`
and `fc00::/7`. The IPv6 entries are required: setting `trusted_proxies` **replaces**
Rails' built-in list rather than extending it, so omitting them breaks
`remote_ip` on any IPv6 hop.

| Your topology | What to do |
|---|---|
| **Cloudflare → Coolify/Traefik → Rails** (current) | ✅ **Nothing.** Traefik is on the private Docker network, covered by the default. Cloudflare is upstream and handled automatically. |
| Cloudflare connects **directly** to Rails (no Traefik) | Set `TRUSTED_PROXIES` to Cloudflare's published IP ranges |
| Public-IP load balancer directly in front of Rails | Set `TRUSTED_PROXIES` to that LB's CIDR |

**Only set it if the proxy immediately in front of Rails is on a PUBLIC IP:**

```bash
# comma-separated CIDRs, appended to the private/loopback defaults listed above
TRUSTED_PROXIES="203.0.113.0/24,173.245.48.0/20"
```

**Verify it works (one command, ~1 min):** hit the API from a phone on mobile data,
then check the Rails log. You should see the carrier's **public IP**, not a `10.x`
address. If you see `10.x`, `172.x`, or `192.168.x` for an external visitor,
`trusted_proxies` isn't matching your proxy.

> ⚠️ **Do NOT** set `TRUSTED_PROXIES="0.0.0.0/0"`. That trusts the header from
> anyone, letting an attacker spoof `X-Forwarded-For` so every `request.remote_ip`
> in your logs and session records becomes attacker-controlled.

---

## 2. Panel env flags (both default OFF — leave OFF for government)

These are **opt-in** features that trade security for convenience. They default to
the secure state; only set them if a human explicitly decides to.

| Flag | Default | Effect when `true` | Government |
|------|---------|--------------------|-----------|
| `NEXT_PUBLIC_ENABLE_OFFLINE_SYNC` | **off** | Caches the full attendee list (name/email/phone) in plaintext browser localStorage for offline check-in | ❌ Leave off |
| `NEXT_PUBLIC_ENABLE_NYTSYS` | **off** | Loads the nytsys third-party marketing/analytics script on public pages | ❌ Leave off |

> These are `NEXT_PUBLIC_*` build-time vars — they are baked into the client bundle
> at `next build`. Changing them requires a rebuild + redeploy of the panel image.
> Never put secrets in `NEXT_PUBLIC_*`.

---

## 3. What requires NO config (works automatically)

- **CSP + security headers** — applied to all responses by `next.config.ts`, no env needed.
- **Console stripping** — automatic in production builds (`compiler.removeConsole`).
- **Generic login error + constant-time bcrypt** — code-level, always on. The dummy
  digest mirrors `ActiveModel::SecurePassword.min_cost`, so its bcrypt cost matches
  real user digests in every environment (regression-tested in
  `spec/requests/v1/authentication_spec.rb`).
- **check_account throttles (30/hr + 3/min burst)** — automatic; Rack::Attack resolves the client IP itself (see §1).
- **Swagger `/api-docs` guard** — automatically disabled outside development/test (`Rails.env.local?`).
- **Offline PII purge** — runs on app load + logout automatically.

---

## 4. Deferred — needs a staging soak before production

These were **deliberately held** (reviewer guidance) and are NOT active yet:

- **CSP `connect-src`: drop the bare `https:`** so only `NEXT_PUBLIC_API_URL` is
  allowed. This is the single highest-value CSP line (stops XSS data exfiltration)
  but will break any call to an undeclared host. Ship to **staging first**, watch
  the browser console for CSP violation reports, then promote.
- **CSP `img-src`: scope `https:` down to your storage domain** (same soak).
- **`script-src 'unsafe-inline'` removal** — needs Next.js nonce middleware; a real
  project, not a header tweak.

When you do the `connect-src` tightening, `NEXT_PUBLIC_API_URL` becomes
load-bearing — make sure it is set correctly in the panel build environment.

---

## 5. First-deploy checklist

1. [ ] Deploy backend + panel as normal (Coolify rebuild picks up the changes).
2. [ ] Confirm the panel builds with `NEXT_PUBLIC_API_URL` set (already required).
3. [ ] **Do NOT** set `NEXT_PUBLIC_ENABLE_OFFLINE_SYNC` or `NEXT_PUBLIC_ENABLE_NYTSYS`.
4. [ ] Verify real client IP in logs (mobile-data test above).
5. [ ] Confirm `https://<api-domain>/api-docs` returns 404 in production.
6. [ ] Spot-check a login with a wrong password → should say "Invalid email or
       password" (no "Email not found"), and take ~the same time for a fake email.

---

## 6. Follow-up fixes applied after the first remediation pass

A second audit of the remediation diff found three defects in the fixes themselves.
All three are corrected; recorded here so the reasoning isn't lost.

**1. `trusted_proxies` was dropping IPv6.** Setting
`config.action_dispatch.trusted_proxies` **replaces** Rails' built-in
`TRUSTED_PROXIES` list rather than extending it (see
`action_dispatch/middleware/remote_ip.rb`). The original list was IPv4-only, so
Rails' default `::1` and `fc00::/7` entries were silently lost and `remote_ip`
would have resolved to the proxy on any IPv6 hop. Both are now listed explicitly.
Also corrected `127.0.0.1/8` → `127.0.0.0/8`.

**2. The dummy bcrypt digest used the wrong cost in test.** Rails does *not* lower
`BCrypt::Engine.cost` in the test environment — it flips the separate
`ActiveModel::SecurePassword.min_cost` flag (set from `Rails.env.test?` in the
ActiveModel railtie), which makes real digests `MIN_COST` (4) while the dummy
stayed at 12. That inverted the very timing gap the fix exists to close, and
slowed the suite. `dummy_password_digest` now mirrors Rails' own branch, so cost
matches real user digests in every environment.

**3. Two comments described behavior that does not exist.** `trusted_proxies` was
credited with fixing Rack::Attack throttle keys; it does not (see §1). Comments
rewritten to state what the code actually does.

**Regression coverage added** in `spec/requests/v1/authentication_spec.rb`:

- unknown email / wrong password / inactive account must return a byte-identical
  status and body — mutation-tested by reintroducing the old `elsif user.nil?`
  branch and confirming the spec fails
- the dummy digest's bcrypt cost must equal a real user's

---

## 7. CSP verification (performed, not assumed)

The production build was served locally and driven in a browser. All eight headers
are emitted on every response, in their production form (no `unsafe-eval`, no
localhost allowances):

```
Content-Security-Policy      default-src 'self'; script-src 'self' 'unsafe-inline'; ...
X-Frame-Options              DENY
X-Content-Type-Options       nosniff
Referrer-Policy              strict-origin-when-cross-origin
Cross-Origin-Opener-Policy   same-origin
X-DNS-Prefetch-Control       on
Permissions-Policy           camera=(self), microphone=(), geolocation=(), payment=(self)
Strict-Transport-Security    max-age=63072000; includeSubDomains; preload
```

| Surface | Result |
|---|---|
| `/` landing | renders fully, no console output |
| `/auth` login | renders fully, no console output |
| `/events/[slug]/check-in` | data loads, scanner reports READY TO SCAN |
| `html5-qrcode` scanner mounted | mounts clean — no `worker-src` / `media-src` violation |

**Zero CSP violations.** `html5-qrcode` is a bundled npm dependency, not a CDN
load, so `script-src 'self'` covers it.

### Finding: silent `localhost` fallback when `NEXT_PUBLIC_API_URL` is unset

`src/utils/rest-api.ts`, `src/lib/api/ticket-rsvp/endpoints.ts` and
`src/lib/api/dashboard/server-endpoints.ts` all fall back to a hardcoded
`http://localhost:3000` when `NEXT_PUBLIC_API_URL` is missing. The build does
**not** fail on the missing variable, so a typo in the Coolify build environment
ships a panel pointed at localhost.

CSP catches this — the fallback is plain `http:` and is refused by `connect-src`:

```
Connecting to 'http://localhost:3000/...' violates the following
Content-Security-Policy directive: "connect-src 'self'  https: wss:"
```

So the failure mode is safe (blocked, loud in the console) rather than silent data
leakage. Still worth a build-time guard that fails the build when
`NEXT_PUBLIC_API_URL` is unset — currently untracked work, not part of this phase.

> Note for §4: when you tighten `connect-src`, testing a **production build**
> locally will break, because the localhost allowance only exists on the `isDev`
> branch. Build with `NEXT_PUBLIC_API_URL` set to the host you're testing against.
