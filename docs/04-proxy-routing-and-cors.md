# Task 4 — Reverse Proxy Routing & CORS

Author: Ginny Ibe

## Selected reverse proxy

**Nginx** (`nginx:alpine`), config in `proxy/nginx.conf`, bind-mounted read-only
into the container at `/etc/nginx/conf.d/default.conf`.

It is the **only** service with a published port (`80:80`). Frontend, backend and
database have no `ports:` entry and are reachable only on the Docker networks.

## Routes

| # | Location (match type)     | Upstream          | Serves                                         |
|---|---------------------------|-------------------|------------------------------------------------|
| 1 | `= /nginx-health` (exact) | — (Nginx itself)  | Proxy liveness check, returns `200 OK`         |
| 2 | `= /health` (exact)       | `backend:8080`    | Backend health endpoint                        |
| 3 | `/api/` (prefix)          | `backend:8080`    | Cart API (`GET/POST /api/cart`, `DELETE /api/cart/delete`) |
| 4 | `/assets/` (prefix)       | `frontend:80`     | Static CSS, JS and images; `expires 7d` caching |
| 5 | `/` (catch-all)           | `backend:8080`    | Server-rendered pages: `/`, `/cart`, `/gallery`, `/category/:name` |

Nginx checks exact matches (`=`) first, then the **longest** matching prefix, so
`/api/cart` goes to rule 3 and `/assets/css/style.css` to rule 4, even though `/`
would also match them.

Upstreams are referenced by **Docker Compose service name** (`backend`, `frontend`),
never by IP. `resolver 127.0.0.11 valid=10s` (Docker's internal DNS) plus
`set $backend ...` makes Nginx re-resolve those names every 10 s, so a recreated
container with a new IP does not cause stale-IP 502 errors.

Forwarded headers on every request: `Host`, `X-Real-IP`, `X-Forwarded-For`,
`X-Forwarded-Proto`, so the backend sees the real client and protocol.
`server_tokens off` hides the Nginx version.

## Was CORS required?

**No.** CORS (Cross-Origin Resource Sharing) only applies when JavaScript on a page
from one origin (scheme + host + port) calls a *different* origin.

With this proxy, the browser loads everything from **one origin**:

| Request               | URL seen by the browser            |
|-----------------------|------------------------------------|
| Page                  | `http://<public-ip>/`              |
| API call from page JS | `http://<public-ip>/api/cart`      |
| Stylesheet / images   | `http://<public-ip>/assets/...`    |

The frontend and backend being separate containers is invisible to the browser — the
proxy joins them under the same origin. Every request is **same-origin**, so the
browser never sends a CORS preflight and no `Access-Control-Allow-*` headers are
needed. The site's own JavaScript (`/assets/js/`) calls relative paths such as
`/api/cart`, which always resolve to the same origin. Verified with grep: the only API calls in the site JS are `$.post("/api/cart")`
(book.js:11) and `$.ajax({ url: "/api/cart/delete" })` (book.js:22) — both relative.

Leaving CORS headers out is also the more secure choice: any `Access-Control-Allow-Origin`
header would only grant *other* sites permission to read the API's responses.
If the API were later served from a different domain (e.g. `api.example.com`),
CORS would then be added with a fixed allowlist of trusted origins — never by
echoing back the request's `Origin` header.

## Verification (local)

    curl -sI http://localhost/                      -> HTTP/1.1 200 OK
    curl -s  http://localhost/api/cart              -> {"cart":[],"book":null}  200
    curl -sI http://localhost/assets/css/style.css  -> 200, Content-Type: text/css, Expires +7d
    curl -s  http://localhost/health                -> OK  200

One claim in this doc, that the site's JavaScript only calls relative URLs, should be checked rather than assumed. Run:

grep -rnoE "(fetch|ajax|\\\$\.(get|post))\(['\"][^'\"]*" frontend/public/assets/js/ | grep -v "\.min\." | head
