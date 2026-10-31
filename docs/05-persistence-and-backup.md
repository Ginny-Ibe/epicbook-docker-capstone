# Task 5 — Persistence, Backup & Restore

Author: Ginny Ibe

## Where the data lives

| Item              | Value                                         |
|-------------------|-----------------------------------------------|
| Named volume      | `db_data` (Docker name `theepicbook_db_data`)   |
| Mounted at        | `/var/lib/mysql` in the `database` container  |
| Database          | `bookstore` — tables Author, Book, Cart, Cartbook, Checkout |
| Lifecycle         | Survives `docker compose down`, container rebuilds and recreation. Only `docker compose down -v` or `docker volume rm` deletes it. |

## Backup plan

| Question  | Decision |
|-----------|----------|
| **What**  | Logical backup with `mysqldump` of the `bookstore` database (schema + data as SQL). Portable across MySQL versions, human-readable, easy to verify with `grep`. |
| **How**   | `--single-transaction` for a consistent snapshot without locking tables (site stays online), plus `--routines --triggers`. |
| **When**  | Daily at 02:00 (low traffic), plus a manual backup **before every deployment or schema change**. |
| **Where** | `backups/` on the VM host, outside the Docker volume. Git-ignored. Next step: copy each dump to object storage (AWS S3) so losing the VM does not also lose the backups. |
| **Retention** | Keep the last 7 daily dumps; older files deleted automatically. |
| **Secrets** | The root password is read inside the container (`$MYSQL_ROOT_PASSWORD`), so it never appears on the command line, in shell history, or in cron logs. |

### Backup command

    BACKUP_FILE=backups/bookstore-$(date +%Y%m%d-%H%M%S).sql
    docker compose exec -T database sh -c \
      'mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --routines --triggers bookstore' \
      2>/dev/null > "$BACKUP_FILE"

`-T` is required: without it Docker adds terminal control characters that corrupt the file.

### Verify a backup is usable

    ls -lh "$BACKUP_FILE"                 # not 0 bytes
    tail -1 "$BACKUP_FILE"                # "-- Dump completed on ..."
    grep "CREATE TABLE" "$BACKUP_FILE"    # all 5 tables present

### Automation (cron on the VM)

    0 2 * * * cd /home/ubuntu/theepicbook && docker compose exec -T database sh -c 'mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction bookstore' > backups/bookstore-$(date +\%Y\%m\%d).sql 2>/dev/null
    30 2 * * * find /home/ubuntu/theepicbook/backups -name "bookstore-*.sql" -mtime +7 -delete

## Restore procedure

1. Choose **one** backup file (newest shown first):

       ls -t backups/bookstore-*.sql
       BACKUP_FILE=backups/<chosen-file>.sql

2. Take a fresh backup of the current state first (in case the restore is the wrong call).
3. Restore — the dump contains `DROP TABLE IF EXISTS` + `CREATE TABLE` + `INSERT`, so tables are rebuilt exactly as they were:

       docker compose exec -T database sh -c \
         'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" bookstore' 2>/dev/null < "$BACKUP_FILE"

4. Verify row counts and spot-check a known record; load the site and check `/health`.

## Restore drill performed (2026-10-31)

| Step | Action | Result |
|------|--------|--------|
| 1 | Recorded test data | 54 books; test record id 1 = "28 Summers" |
| 2 | Backup with `mysqldump` | `backups/bookstore-20261031-*.sql`, 5 tables, ends with "Dump completed" |
| 3 | Controlled data loss: `DELETE FROM Book WHERE id = 1` | 53 books; id 1 → 0 rows |
| 4 | Restore from the backup | 54 books; id 1 "28 Summers" back, visible on the site |
| 5 | `docker compose down` (no `-v`) then `up -d --wait` | Containers removed, volume kept; after restart still 54 books incl. id 1 |

Two failure types tested: **data loss inside the database** (fixed by restore)
and **container loss** (survived thanks to the named volume).
