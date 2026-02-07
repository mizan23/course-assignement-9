#!/bin/bash

set -e

# Always run from a safe directory
cd /tmp

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DB_USER="bmi_user"
DB_NAME="bmidb"
DB_VERSION="14"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

print_header() {
  echo -e "${BLUE}"
  echo "========================================"
  echo "$1"
  echo "========================================"
  echo -e "${NC}"
}

print_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

check_root() {
  if [[ $EUID -ne 0 ]]; then
    print_error "Run with sudo"
    exit 1
  fi
}

check_postgresql_installed() {
  if command -v psql &> /dev/null; then
    print_success "PostgreSQL already installed"
    return 0
  fi
  return 1
}

install_postgresql() {
  print_header "Installing PostgreSQL $DB_VERSION"
  apt update -qq
  apt install -y postgresql-$DB_VERSION postgresql-client-$DB_VERSION
  print_success "PostgreSQL installed"
}

start_postgresql_service() {
  systemctl start postgresql
  systemctl enable postgresql
  print_success "PostgreSQL service running"
}

create_database_user() {
  print_header "Creating Database User"

  if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1; then
    print_warning "User already exists – skipping"
    return
  fi

  read -sp "Enter password for $DB_USER: " DB_PASS
  echo
  read -sp "Confirm password: " DB_PASS_CONFIRM
  echo

  if [[ "$DB_PASS" != "$DB_PASS_CONFIRM" ]]; then
    print_error "Passwords do not match"
    exit 1
  fi

  export DB_PASSWORD="$DB_PASS"
  sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
  print_success "User created"
}

create_database() {
  print_header "Creating Database"

  if sudo -u postgres psql -lqt | cut -d \| -f1 | grep -qw "$DB_NAME"; then
    print_warning "Database already exists – skipping"
    return
  fi

  sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
  sudo -u postgres psql -d "$DB_NAME" -c "GRANT ALL ON SCHEMA public TO $DB_USER;"
  print_success "Database created"
}

configure_postgresql() {
  print_header "Configuring PostgreSQL"

  PG_CONF="/etc/postgresql/$DB_VERSION/main/postgresql.conf"
  PG_HBA="/etc/postgresql/$DB_VERSION/main/pg_hba.conf"

  cp "$PG_CONF" "$PG_CONF.bak"
  cp "$PG_HBA" "$PG_HBA.bak"

  cat >> "$PG_HBA" <<EOF

# BMI App
local   $DB_NAME  $DB_USER  md5
host    $DB_NAME  $DB_USER  127.0.0.1/32  md5
EOF

  systemctl reload postgresql
  print_success "PostgreSQL configured"
}

run_migrations() {
  print_header "Running Migrations"

  MIGRATIONS="$PROJECT_ROOT/backend/migrations"

  if [[ ! -d "$MIGRATIONS" ]]; then
    print_warning "No migrations directory"
    return
  fi

  export PGPASSWORD="$DB_PASSWORD"

  for f in $(ls "$MIGRATIONS"/*.sql | sort); do
    print_info "Running $(basename "$f")"
    psql -U "$DB_USER" -d "$DB_NAME" -h localhost -f "$f"
  done

  unset PGPASSWORD
  print_success "Migrations completed"
}

seed_sample_data() {
  print_header "Seeding Sample Data"

  read -p "Insert sample data? (y/n): " -n 1 REPLY
  echo
  [[ ! $REPLY =~ ^[Yy]$ ]] && return

  export PGPASSWORD="$DB_PASSWORD"

  psql -U "$DB_USER" -d "$DB_NAME" -h localhost <<EOF
INSERT INTO measurements (weight_kg, height_cm, age, created_at) VALUES
(70.5,175,25,NOW()),
(65.2,162,30,NOW()),
(85.0,180,35,NOW());
EOF

  unset PGPASSWORD
  print_success "Sample data inserted"
}

generate_env_file() {
  print_header "Generating .env"

  cat > "$PROJECT_ROOT/backend/.env" <<EOF
DB_HOST=localhost
DB_PORT=5432
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
EOF

  chmod 600 "$PROJECT_ROOT/backend/.env"
  print_success ".env created"
}

main() {
  print_header "BMI Health Tracker DB Setup"

  read -p "Continue? (y/n): " -n 1 R
  echo
  [[ ! $R =~ ^[Yy]$ ]] && exit 0

  check_root

  check_postgresql_installed || install_postgresql
  start_postgresql_service
  configure_postgresql
  create_database_user
  create_database
  run_migrations
  seed_sample_data
  generate_env_file

  print_success "DATABASE SETUP COMPLETE"
}

main
