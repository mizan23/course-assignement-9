#!/bin/bash
# Backend Deployment Script (Ubuntu 24.04, Auto Scaling, Golden AMI safe)

set -e

LOG_FILE="/var/log/backend-deploy.log"
exec > >(tee -a ${LOG_FILE}) 2>&1

echo "========================================="
echo "Backend Deployment Started: $(date)"
echo "========================================="

export PATH=$PATH:/usr/bin:/usr/local/bin

# --------------------------------------------------
# Install required system packages
# --------------------------------------------------
echo "Installing required system packages..."
apt-get update -y
apt-get install -y \
    postgresql-client \
    curl \
    git \
    lsof \
    unzip

# --------------------------------------------------
# Install AWS CLI v2 (Ubuntu 24.04 compatible)
# --------------------------------------------------
if ! command -v aws >/dev/null 2>&1; then
    echo "Installing AWS CLI v2..."
    curl -s https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscliv2.zip
    unzip -q /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
fi

# --------------------------------------------------
# Install PM2 if missing
# --------------------------------------------------
if ! command -v pm2 >/dev/null 2>&1; then
    echo "Installing PM2..."
    npm install -g pm2
fi

# --------------------------------------------------
# Fetch EC2 metadata (NO ec2-metadata dependency)
# --------------------------------------------------
echo "Fetching instance metadata..."
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
REGION=${AZ::-1}

echo "Instance ID: ${INSTANCE_ID}"
echo "Region: ${REGION}"

# --------------------------------------------------
# Verify runtime
# --------------------------------------------------
echo "Node.js version: $(node --version)"
echo "NPM version: $(npm --version)"
echo "PM2 version: $(pm2 --version)"
echo "AWS CLI version: $(aws --version)"

# --------------------------------------------------
# Fetch database credentials from SSM Parameter Store
# --------------------------------------------------
echo "Fetching database credentials from Parameter Store..."

DB_HOST=$(aws ssm get-parameter \
  --name "/bmi-app/db-host" \
  --region ${REGION} \
  --query 'Parameter.Value' \
  --output text)

DB_NAME=$(aws ssm get-parameter \
  --name "/bmi-app/db-name" \
  --region ${REGION} \
  --query 'Parameter.Value' \
  --output text)

DB_USER=$(aws ssm get-parameter \
  --name "/bmi-app/db-user" \
  --region ${REGION} \
  --query 'Parameter.Value' \
  --output text)

DB_PASSWORD=$(aws ssm get-parameter \
  --name "/bmi-app/db-password" \
  --with-decryption \
  --region ${REGION} \
  --query 'Parameter.Value' \
  --output text)

echo "Database host: ${DB_HOST}"
echo "Database name: ${DB_NAME}"

# --------------------------------------------------
# Clone repository
# --------------------------------------------------
echo "Cloning repository..."
mkdir -p /var/www
cd /var/www

if [ -d "app" ]; then
    rm -rf app
fi

git clone https://github.com/sarowar-alam/3-tier-web-app-auto-scalling.git app
cd app/backend

# --------------------------------------------------
# Install Node.js dependencies
# --------------------------------------------------
echo "Installing npm dependencies..."
npm ci --omit=dev

# --------------------------------------------------
# Create environment file
# --------------------------------------------------
echo "Creating .env file..."
cat > .env << EOF
NODE_ENV=production
PORT=3000
DATABASE_URL=postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:5432/${DB_NAME}
DB_HOST=${DB_HOST}
DB_PORT=5432
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
FRONTEND_URL=*
EOF

chmod 600 .env
echo ".env file created and secured"

# --------------------------------------------------
# Wait for database readiness
# --------------------------------------------------
echo "Waiting for database to be ready..."
DB_READY=false

for i in {1..60}; do
    if PGPASSWORD=${DB_PASSWORD} psql \
        -h ${DB_HOST} \
        -U ${DB_USER} \
        -d ${DB_NAME} \
        -c "SELECT 1" >/dev/null 2>&1; then
        DB_READY=true
        echo "Database is ready!"
        break
    fi
    echo "Waiting for database... ($i/60)"
    sleep 10
done

if [ "$DB_READY" = false ]; then
    echo "WARNING: Database not ready after 10 minutes. Continuing anyway..."
fi

# --------------------------------------------------
# Run migrations (idempotent)
# --------------------------------------------------
echo "Running database migrations..."
MIGRATION_LOCK="/var/www/.migration_lock"

if [ ! -f "$MIGRATION_LOCK" ]; then
    for migration in migrations/*.sql; do
        if [ -f "$migration" ]; then
            echo "Running migration: $migration"
            PGPASSWORD=${DB_PASSWORD} psql \
                -h ${DB_HOST} \
                -U ${DB_USER} \
                -d ${DB_NAME} \
                -f "$migration" || true
        fi
    done
    touch "$MIGRATION_LOCK"
    echo "Migrations completed and locked"
else
    echo "Migrations already applied"
fi

# --------------------------------------------------
# Verify tables
# --------------------------------------------------
echo "Verifying database tables..."
PGPASSWORD=${DB_PASSWORD} psql \
  -h ${DB_HOST} \
  -U ${DB_USER} \
  -d ${DB_NAME} \
  -c "\dt" || true

# --------------------------------------------------
# Kill existing process on port 3000
# --------------------------------------------------
if lsof -ti:3000 >/dev/null 2>&1; then
    echo "Killing existing process on port 3000..."
    kill -9 $(lsof -ti:3000) || true
fi

# --------------------------------------------------
# Start application with PM2
# --------------------------------------------------
echo "Starting application with PM2..."
pm2 delete all || true
pm2 start ecosystem.config.js --env production
pm2 save

pm2 startup systemd -u root --hp /root || true
pm2 save || true

# --------------------------------------------------
# Final checks
# --------------------------------------------------
echo "========================================="
echo "Backend Deployment Complete: $(date)"
echo "========================================="

pm2 status
sleep 3
curl -s localhost:3000/health || echo "Health endpoint not responding yet"

echo "Logs saved to ${LOG_FILE}"
