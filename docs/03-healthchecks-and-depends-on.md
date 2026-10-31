
# Assignment 7 - Task 3 — Health Checks & Startup Order

Author: Ginny Ibe

## Health-check method per service

| Service       | Check command (runs inside the container)                          | Interval / Timeout / Retries / Start period | What "healthy" proves |
|---------------|--------------------------------------------------------------------|---------------------------------------------|-----------------------|
| database      | `mysqladmin ping -h 127.0.0.1 -uroot -p"$$MYSQL_ROOT_PASSWORD" --silent` | 10s / 5s / 10 / 30s | MySQL accepts TCP connections on 3306 |
| backend       | `wget -q --spider http://127.0.0.1:8080/health`                    | 10s / 5s / 5 / 15s  | Node process is up and Express returns 200 on `/health` |
| frontend      | `wget -q --spider http://127.0.0.1/assets/css/style.css`           | 10s / 5s / 3 / 5s   | Nginx is serving the static assets |
| reverse-proxy | `wget -q --spider http://127.0.0.1/nginx-health`                   | 10s / 5s / 3 / 5s   | Proxy Nginx is up and its config loaded |

### Design decisions
- **Backend `/health` route** was added to `backend/server.js`. It returns `200 OK`
  without querying MySQL — a liveness check. Database readiness is covered by the
  database's own check, so a DB blip does not cascade into the backend/proxy being
  marked unhealthy.
- **`-h 127.0.0.1` (TCP), not `localhost` (socket), for MySQL.** During first-time
  init MySQL runs a temporary server on the socket only (`port: 0` in the logs).
  A socket ping would report healthy too early; a TCP ping only passes once the
  real server is listening on 3306 and the seed SQL has run.
- **`$$MYSQL_ROOT_PASSWORD`** is expanded inside the container, so the root
  password never appears in the healthcheck definition shown by `docker inspect`.
- **`127.0.0.1` instead of `localhost` for wget**, because on Alpine `localhost`
  can resolve to IPv6 `::1`, which these servers do not listen on.
- No extra packages were installed — `wget` is already in `node:20-alpine`
  and `nginx:alpine` (BusyBox).

## Startup dependency order

database ──(service_healthy)──► backend ──┐
                                          ├─(service_healthy)──► reverse-proxy
frontend ─────────────────────────────────┘

1. `database` and `frontend` start first (no dependencies).
2. `backend` starts only after `database` is **healthy**.
3. `reverse-proxy` starts only after both `frontend` and `backend` are **healthy**.

Observed on `docker compose up -d --build`:
database Healthy (6.6s) → backend Healthy (12.2s) → reverse-proxy Started (12.4s).

## Before vs. after

- **Task 2 (plain `depends_on`)**: Compose only waited for the database *container*
  to start. The backend connected while MySQL was still initialising, crashed with
  `ECONNREFUSED database:3306`, showed `Restarting (1)`, and the proxy returned
  **502 Bad Gateway** until a restart succeeded.
- **Task 3 (`condition: service_healthy`)**: the backend waits for MySQL to be
  ready, starts once, and connects first time — no crash loop, no 502 on startup.
