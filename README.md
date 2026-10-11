# BRAVE Social Growth Marketplace

Full-stack Node.js/Express website with an original BRAVE storefront design, six platform categories, 37+ service cards, NGN pricing, checkout, order IDs and a Dockerfile.

## Run locally
```bash
npm install
npm start
```
Open http://localhost:3000

## Payments, email & order tracking

**Payment methods** — customers choose at checkout:
- **Paystack** (card, bank, USSD): set `PAYSTACK_SECRET_KEY` + `PAYSTACK_PUBLIC_KEY` and the checkout opens Paystack's popup automatically. Paystack's webhook (`/api/paystack/webhook`) verifies the HMAC signature and marks orders paid; customers return via `/pay.html?reference=...` which verifies server-side too. If the secret is missing, Paystack is hidden and customers see bank transfer instead.
- **Bank transfer**: set `BANK_NAME`, `BANK_ACCOUNT_NAME`, `BANK_ACCOUNT_NUMBER` — customers see the account details and confirm payment; you verify and mark the order **paid** from the admin dashboard.
- Without any payment config the storefront works in plain order-taking mode (same as before); `/api/config` tells the frontend what's enabled.

**Email receipts** (optional, via Brevo SMTP): set `SMTP_HOST=smtp-relay.brevo.com`, `SMTP_PORT=587`, `SMTP_USER`, `SMTP_PASS`, plus `OWNER_EMAIL`. Every order sends the customer a receipt and you a notification. Without SMTP settings, ordering still works — emails are just skipped.

**Customer order tracking**: `/track.html` — customers look up any order by ID (e.g. `BRV-8A2F91CD`) plus the email used at checkout, and see live status, payment state and audit history (API: `GET /api/track/:orderId?email=...`, rate-limited).

**Spam protection**: the public order endpoint is rate-limited per IP (default 5 orders / 10 min — tune with `ORDER_RATE_MAX` / `ORDER_RATE_WINDOW_MIN`) and validates target URLs (must be a valid http(s) URL on the service's platform) and email format.

**Trust pages**: `/terms.html`, `/privacy.html` and `/refund.html` are live and linked in the footer — edit the placeholders (business name, contact email) before going live.

All of the above are configured by environment variables — copy **`.env.example`** and fill in what you have; anything left blank degrades gracefully.

## Change the NGN conversion rate
```bash
NGN_PER_USD=1400 npm start
```
Default: `1332` NGN/USD. Update this value before production based on the rate/pricing you choose.

## Auto-fulfillment via supplier panel
The site can forward every **paid** order to an SMM supplier panel automatically and complete the order when the panel delivers:

```bash
# .env — panel uses the standard SMM panel API v2 (POST {key, action:add|status, ...} to /api/v2)
PANEL_API_URL=https://your-panel.com/api/v2
PANEL_API_KEY=your-panel-key
# our catalog id → the panel's service id (only mapped services auto-forward)
PANEL_SERVICES=ig-followers:1001,ig-likes:1002,tt-followers:2001
# optional: the panel's real per-1000 USD price per service — profit report uses these instead of catalog estimates (rows are tagged "panel" vs "est")
PANEL_COSTS=ig-followers:1.0,ig-likes:0.8
```

Behavior: on payment (Paystack webhook/verification or **Mark paid**) the order is sent to the panel with the customer's target URL and quantity, a background poller checks progress every 5 s, and when the panel reports **Completed** the order auto-completes (₦ lands in revenue; history says `by panel`). **Canceled** panel orders get flagged `refund needed`. Failures and unmapped services degrade to manual fulfillment and are logged to `data/security.log` (`panel-forwarded`, `panel-completed`, `panel-forward-failed`, …). The dashboard shows the panel status and remaining count on each paid order. **Panel minimums are enforced automatically**: the server fetches each mapped service's `min` from the panel (refreshed every 6 h) and exposes it at `/api/config`; the storefront snaps small quantities up to the minimum on blur, and the API rejects below-minimum orders with a clear 400 instead of a panel error.

## Pricing model
Catalog prices are **per 1,000 units** (the SMM-panel convention): ₦4,000 on the Instagram Followers card = 1,000 followers. The checkout total is `price × quantity ÷ 1000`, so ordering 1,000 costs ₦4,000 regardless of the quantity typed. Quantities from 1 to 100,000 are accepted. All retail prices were rebalanced against the supplier panel's real wholesale rates (rebalanced 2026-09-22) so every auto-fulfilled service clears a minimum gross margin — see the admin **Profit report** for per-service cost and margin at live rates.

## Admin API
A built-in admin dashboard is served at **`/admin.html`** — open it, paste the admin token once (stored in your browser's localStorage), and manage all orders from a table with status dropdowns and a two-click delete (click **Del**, then **Sure?** to confirm). A **toast notification** appears whenever a new order arrives, and the new order is tagged `NEW` next to its History count for 60 seconds. The table **auto-refreshes every 10 seconds** (pausing while a delete is armed, a confirmation flash is showing, or the tab is hidden) and a **search box** filters by order ID, email, or target URL. **Export CSV** downloads the currently filtered view, optionally bounded by the **From/To** date pickers (inclusive, matched on order date in your local timezone; the filename carries the range) — BOM + RFC-4180 escaping, Excel-safe, with a `Completed At` column derived from the audit history — for bookkeeping. Every order carries an **audit history**: click the counter in the History column to see each status change with timestamp and who made it (customer creation, or `admin@<token-tag>@<ip>` for admin actions).

Start the server with an admin token (minimum 16 characters):
```bash
ADMIN_TOKEN=your-long-random-secret-16+chars npm start
```
Tokens shorter than 16 characters are rejected (configurable with `ADMIN_TOKEN_MIN_LENGTH`). Generate a strong one with `node -e "console.log(require('crypto').randomBytes(24).toString('hex'))"`.
List orders (optionally filter by status):
```bash
curl -H "Authorization: Bearer your-secret" http://localhost:3000/api/admin/orders
curl -H "Authorization: Bearer your-secret" "http://localhost:3000/api/admin/orders?status=pending"
```
Update an order's status (`pending`, `processing`, `completed`, `cancelled`) or payment state (`markPaid:true` verifies a bank transfer and emails the customer a receipt):
```bash
curl -X PATCH -H "Authorization: Bearer your-secret" -H "Content-Type: application/json" \
  -d '{"status":"completed"}' http://localhost:3000/api/admin/orders/BRV-XXXXXXXX
curl -X PATCH -H "Authorization: Bearer your-secret" -H "Content-Type: application/json" \
  -d '{"markPaid":true}' http://localhost:3000/api/admin/orders/BRV-XXXXXXXX
```
Paid orders can't be deleted by accident — delete the payment first (`{"markPaid":false}`).
Summary stats (order counts by status + naira revenue from completed orders):
```bash
curl -H "Authorization: Bearer your-secret" http://localhost:3000/api/admin/stats
```
Delete an order:
```bash
curl -X DELETE -H "Authorization: Bearer your-secret" http://localhost:3000/api/admin/orders/BRV-XXXXXXXX
```
Export **all** orders as CSV (ignores any dashboard filters; same columns and escaping as the dashboard export). Add `?month=YYYY-MM` to export a single calendar month (order date, UTC); an invalid month returns `400`:
```bash
curl -H "Authorization: Bearer your-secret" -o brave-orders-all.csv \
  http://localhost:3000/api/admin/orders.csv
curl -H "Authorization: Bearer your-secret" -o brave-orders-month-2026-09.csv \
  "http://localhost:3000/api/admin/orders.csv?month=2026-09"
```
Monthly bookkeeping summary (orders, completed count, and naira revenue grouped by month, newest first):
```bash
curl -H "Authorization: Bearer your-secret" http://localhost:3000/api/admin/monthly
```
Supplier-profit report — per-order retail (₦, what the customer paid) vs estimated panel cost (US$ at the catalog's wholesale rates) plus totals, **and a per-service margin table** (all 27 storefront services: retail ₦/1k vs panel cost $/1k vs margin, `panel` = real PANEL_COSTS rate, `est ≈` = catalog estimate, `unmapped` = no cost known):
```bash
curl -H "Authorization: Bearer your-secret" http://localhost:3000/api/admin/profit
```
Recent security events (newest first, `?n=` for up to 200) — failed admin logins, lockouts, rate-limit hits, token rotations, webhook deliveries:
```bash
curl -H "Authorization: Bearer your-secret" "http://localhost:3000/api/admin/security-log?n=50"
```
The dashboard's **Security events** panel filters these by event type and IP/actor (client-side over the last 200) and offers a **download raw** button, which fetches the complete log via `GET /api/admin/security-log/raw` (plain text, dated attachment name, same auth — the token never appears in a URL).
Requests with a wrong/missing token get `401`; if no `ADMIN_TOKEN(S)` is set (or any token is too short) the admin API returns `503`.

### Production hardening
- **Multiple tokens**: set `ADMIN_TOKENS="token-one,token-two"` (comma-separated; `ADMIN_TOKEN` still works as a single-token fallback). Every token must meet the minimum length. Admin actions in the audit history are attributed as `admin@<8-char token tag>@<ip>`, so different holders are distinguishable.
- **Token rotation** (no downtime): `curl -X POST -H "Authorization: Bearer <current-token>" http://localhost:3000/api/admin/rotate-token` → returns a fresh random token, active immediately alongside the old one. Add it to `ADMIN_TOKENS` in your environment, remove the old one, restart — the leaked/retired token then stops working. Rotations are recorded in `data/security.log`.
- **Isolated data directory**: set `DATA_DIR=./data-volume` to move `orders.json`, `security-state.json`, and `security.log` elsewhere (Docker volume mounts, scratch test instances).
- **New-order webhook**: set `ADMIN_WEBHOOK_URL` to any HTTPS endpoint and the server will `POST` `{event:'order.created', at, order:{...}}` there the moment an order lands — fire-and-forget, so webhook failures never block order creation. Point it at an email/WhatsApp automation (Zapier, Make, n8n, a Telegram bot, etc.) to get pinged wherever you like. Optionally set `ADMIN_WEBHOOK_SECRET` to have every delivery signed in the `X-BRAVE-Signature: sha256=<hmac>` header (HMAC-SHA256 of the raw body) so your receiver can verify it's genuinely from the app. Deliveries are logged to `data/security.log`.
- **Behind a reverse proxy** (nginx/Caddy/Cloudflare): set `TRUST_PROXY=1` (or a hop count / IP list) so rate limiting and audit IPs reflect real clients instead of the proxy. Always terminate TLS at the proxy — `ADMIN_TOKEN` and order data must never cross the public internet in cleartext.
- **Persistent rate limiting & lockout**: hit counters and failed-attempt locks survive restarts (stored in `data/admin-security.json`), so restarting the server no longer resets a brute-force lockout.
- **Audit log**: every status change is recorded on the order (`history[]`). Security events — failed admin logins, brute-force lockouts (start + repeat attempts while locked), rate-limit throttles, token rotations, webhook deliveries — append to `data/security.log`, and the **dashboard shows a live tail** in a collapsible *Security events* panel below the orders table (refreshed on every load and auto-refresh; open/closed state is remembered per device). Back it up alongside `data/orders.json`. The dashboard also has a collapsible **Monthly bookkeeping** panel — orders, completed count, and revenue grouped by month with a one-click per-month CSV download.

## Docker
```bash
# Production deploy with docker compose (recommended)
ADMIN_TOKENS="$(openssl rand -hex 24)" docker compose up -d --build
curl http://localhost:3000/api/health
```
- All state (orders, security/limiter state, webhook log) persists in the named volume `brave-data`, mounted at `/data` (`DATA_DIR=/data` is baked into the image) — orders survive rebuilds and container replacement.
- Runs as a **non-root user**, restarts on failure, and self-reports health via `/api/health` (check with `docker compose ps`).
- Change the host port with `APP_PORT=8080 docker compose up -d`; pass any other supported env var (`ADMIN_WEBHOOK_URL`, `TRUST_PROXY`, `NGN_PER_USD`, …) the same way — see the compose file comments.
- Plain `docker run` equivalent:
```bash
docker build -t brave-social:1.0 .
docker run -d --restart unless-stopped --name brave-social \
  -p 3000:3000 -v brave-data:/data \
  -e DATA_DIR=/data -e ADMIN_TOKENS="$(openssl rand -hex 24)" \
  brave-social:1.0
```
⚠ Without `ADMIN_TOKEN(S)` (16+ chars each) the admin dashboard/API stays disabled (503).

## GitHub
```bash
git init
git add .
git commit -m "Build BRAVE social growth marketplace"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/brave-social-growth.git
git push -u origin main
```

## Azure VM
```bash
git clone https://github.com/YOUR-USERNAME/brave-social-growth.git
cd brave-social-growth
ADMIN_TOKENS="$(openssl rand -hex 24)" docker compose up -d --build
```
Then put nginx or Caddy in front for HTTPS and set `TRUST_PROXY=1` (see *Production hardening* above) so rate limiting and audit IPs reflect real clients.

## One-click deploy (Render / Railway)

The repo ships with `render.yaml` — push to GitHub, then in Render choose **New → Blueprint** and it creates the web service, persistent disk and environment slots automatically (add `ADMIN_TOKEN`, `PAYSTACK_SECRET_KEY`, etc. in the dashboard). Railway works the same way: connect the repo and set the env vars; point a volume at `/data` for order persistence. After deploying, point Paystack's webhook at `https://YOUR-DOMAIN/api/paystack/webhook`.

The app stores orders in `data/orders.json` (persisted in the Docker volume / Render disk when deployed). For heavier production, connect PostgreSQL/MySQL and terminate TLS at a reverse proxy.

Test the wiring without spending panel credit: run `node .freebuff/mock-panel.js 3901` (a tiny fake panel that completes orders after 3 s and enforces the Custom Comments `comments` requirement) and point `PANEL_API_URL=http://localhost:3901/api/v2` with any key and `PANEL_SERVICES` mapping. For the full automated proof, `node .freebuff/fb-comments-e2e.js` spins up the mock + a scratch server on an isolated data dir and asserts the whole chain: order → paid → forwarded **with comment texts** → auto-completed (6 checks; prints `ALL PASS` on success).
# Bravepay-payment-services-
