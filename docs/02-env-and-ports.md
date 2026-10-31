# Environment Variables, Ports, Persistence & Health Checks

Author: Ginny Ibe

## Environment variables (names only — real values live in `.env`, never committed)

### Backend (Node/Express)
| Variable     | Purpose                                                      | Source              |
|--------------|--------------------------------------------------------------|---------------------|
| `NODE_ENV`   | Selects the `production` block in `config/config.json`       | docker-compose.yml  |
| `PORT`       | Port the Express app listens on (code default: 8080)         | docker-compose.yml  |
| `JAWSDB_URL` | MySQL connection string `mysql://USER:PASSWORD@HOST:3306/DB`  | built from `.env`   |

Found with: `grep -rn "process.env" --include=*.js .`
- `server.js` → `process.env.PORT`
- `models/index.js` → `process.env.NODE_ENV`, `process.env[config.use_env_variable]` (= `JAWSDB_URL`)

### Database (MySQL) — set in `.env`
| Variable           | Purpose                                   |
|--------------------|-------------------------------------------|
| `DB_NAME`          | Database name — must be `bookstore` (the SQL seed files hardcode `USE bookstore;`) |
| `DB_USER`          | Application database user                 |
| `DB_PASSWORD`      | Application user's password (secret)      |
| `DB_ROOT_PASSWORD` | MySQL root password (secret)              |

A safe template with placeholder values is committed as `.env.example`.

## Ports
| Service         | Internal port | Published to host? |
|-----------------|---------------|--------------------|
| reverse-proxy   | 80            | **Yes — 80:80 (only public port)** |
| frontend        | 80            | No                 |
| backend         | 8080          | No                 |
| database        | 3306          | No (back-tier only) |

## Persistent data
| Data                          | Location in container | Storage                    |
|-------------------------------|-----------------------|----------------------------|
| MySQL data (Book, Author, Cart tables) | `/var/lib/mysql` | `db_data` named volume |
| Schema + seed SQL (`db/*.sql`) | `/docker-entrypoint-initdb.d/` | read-only bind mount, runs on first start only |
| Reverse-proxy logs            | `/var/log/nginx`      | bind mount `./logs/nginx`  |

The app has no file-upload feature, so no uploads volume is needed.

## Health-check methods
| Service       | Method                                                         |
|---------------|----------------------------------------------------------------|
| database      | `mysqladmin ping` inside the container                         |
| backend       | HTTP `GET /health` on port 8080 → `200 OK` (route added in Task 3) |
| frontend      | HTTP `GET /` on port 80 with `wget --spider`                   |
| reverse-proxy | HTTP `GET /health` on port 80 (proxied to backend) with `wget` |
