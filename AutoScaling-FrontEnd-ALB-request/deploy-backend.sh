#!/bin/bash
# Backend Deployment Script (runs on instance boot from Golden AMI)
# This script clones the repo, configures, and starts the application

set -e

LOG_FILE="/var/log/backend-deploy.log"
exec > >(tee -a ${LOG_FILE}) 2>&1

echo "========================================="
echo "Backend Deployment Started: $(date)"
echo "========================================="

# Get instance metadata
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
REGION=$(ec2-metadata --availability-zone | cut -d " " -f 2 | sed 's/[a-z]$//')

echo "Instance ID: ${INSTANCE_ID}"
echo "Region: ${REGION}"

# Fetch database credentials from Parameter Store
echo "Fetching database credentials from Parameter Store..."
DB_HOST=$(aws ssm get-parameter --name "/bmi-app/db-host" --region ${REGION} --query 'Parameter.Value' --output text)
DB_NAME=$(aws ssm get-parameter --name "/bmi-app/db-name" --region ${REGION} --query 'Parameter.Value' --output text)
DB_USER=$(aws ssm get-parameter --name "/bmi-app/db-user" --region ${REGION} --query 'Parameter.Value' --output text)
DB_PASSWORD=$(aws ssm get-parameter --name "/bmi-app/db-password" --with-decryption --region ${REGION} --query 'Parameter.Value' --output text)
BACKEND_ALB_URL=$(aws ssm get-parameter --name "/bmi-app/backend-alb-url" --region ${REGION} --query 'Parameter.Value' --output text)

# Clone repository
echo "Cloning repository..."
cd /var/www
if [ -d "app" ]; then
    rm -rf app
fi
git clone https://github.com/sarowar-alam/3-tier-web-app-auto-scalling.git app
cd app/backend

# Install dependencies
echo "Installing npm dependencies..."
npm install --production

# Create .env file
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

# Wait for database to be ready
echo "Waiting for database to be ready..."
for i in {1..30}; do
    if PGPASSWORD=${DB_PASSWORD} psql -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} -c "SELECT 1" > /dev/null 2>&1; then
        echo "Database is ready!"
        break
    fi
    echo "Waiting for database... (attempt $i/30)"
    sleep 10
done

# Run migrations (only if not already run)
echo "Running database migrations..."
MIGRATION_LOCK="/var/www/.migration_lock"
if [ ! -f "$MIGRATION_LOCK" ]; then
    echo "Running migrations for the first time..."
    for migration in migrations/*.sql; do
        echo "Running migration: $migration"
        PGPASSWORD=${DB_PASSWORD} psql -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} -f $migration || echo "Migration may have already run: $migration"
    done
    sudo touch $MIGRATION_LOCK
    echo "Migrations completed and locked"
else
    echo "Migrations already run (lock file exists)"
fi

# Start application with PM2
echo "Starting application with PM2..."
pm2 delete all || true
pm2 start ecosystem.config.js --env production
pm2 save

# Enable PM2 startup
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u ec2-user --hp /home/ec2-user

echo "========================================="
echo "Backend Deployment Complete: $(date)"
echo "========================================="
echo "Application running on port 3000"
echo "PM2 Status:"
pm2 status
