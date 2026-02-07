#!/bin/bash
set -e
cd /tmp

ENV_FILE="$(dirname "$0")/../backend/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "[ERROR] .env file not found"
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

echo "[INFO] Loaded environment variables"



# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Config
DB_USER="bmi_user"
DB_NAME="bmidb"
DB_VERSION="14"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

print() { echo -e "${BLUE}==> $1${NC}"; }
fail() { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }
ok()   { echo -e "${GREEN}[OK] $1${NC}"; }

[[ $EUID -eq 0 ]] || fail "Run as root"
[[ -n "$DB_PASSWORD" ]] || fail "DB_PASSWORD not set"

print "Installing PostgreSQL"
if ! command -v psql >/dev/null; then
  apt update -qq
  apt install -y postgresql-$DB_VERSION postgresql-client-$DB_VERSION
fi
ok "PostgreSQL ready"

systemctl enable --now postgresql

print "Configuring PostgreSQL auth"
PG_HBA="/etc/postgresql/$DB_VERSION/main/pg_hba.conf"
grep -q "BMI App" "$PG_HBA" || cat >> "$PG_HBA" <<EOF

# BMI App
local   $DB_NAME  $DB_USER  md5
host    $DB_NAME  $DB_USER  127.0.0.1/32  md5
EOF
systemctl reload postgresql
ok "PostgreSQL configured"

print "Creating DB user"
sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1 || \
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
ok "User ready"

print "Creating DB"
sudo -u postgres psql -lqt | cut -d\| -f1 | grep -qw "$DB_NAME" || \
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
ok "Database ready"

print "Running migrations"
export PGPASSWORD="$DB_PASSWORD"
for f in "$PROJECT_ROOT/backend/migrations/"*.sql; do
  psql -U "$DB_USER" -d "$DB_NAME" -h localhost -f "$f"
done
unset PGPASSWORD
ok "Migrations done"

print "Database setup complete"
