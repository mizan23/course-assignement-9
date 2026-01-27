#!/bin/bash
# Backend Golden AMI Preparation Script
# This script installs all prerequisites for the Node.js backend
# Run this once to create the Golden AMI

set -e

echo "========================================="
echo "Backend Golden AMI Setup - Prerequisites"
echo "========================================="

# Update system
echo "Updating system packages..."
sudo dnf update -y

# Install Node.js 20
echo "Installing Node.js 20..."
sudo dnf install -y nodejs npm

# Verify Node.js installation
node --version
npm --version

# Install PM2 globally
echo "Installing PM2 globally..."
sudo npm install -g pm2

# Install PostgreSQL client (for running migrations)
echo "Installing PostgreSQL client..."
sudo dnf install -y postgresql15

# Install git
echo "Installing git..."
sudo dnf install -y git

# Create application directory
echo "Creating application directory..."
sudo mkdir -p /var/www
sudo chown ec2-user:ec2-user /var/www

# Install CloudWatch agent (optional but recommended)
echo "Installing CloudWatch agent..."
sudo dnf install -y amazon-cloudwatch-agent

# Configure PM2 to start on boot
echo "Configuring PM2 startup..."
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u ec2-user --hp /home/ec2-user

echo "========================================="
echo "Backend Golden AMI Setup Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Create AMI from this instance"
echo "2. Use deploy-backend.sh as user-data when launching from this AMI"
