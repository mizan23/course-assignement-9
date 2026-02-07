#!/bin/bash
set -e

LOG_FILE="/var/log/frontend-deploy.log"
exec > >(tee -a ${LOG_FILE}) 2>&1

echo "========================================="
echo "Frontend deployment started: $(date)"
echo "========================================="

# ✅ Backend Internal ALB (already created)
BACKEND_ALB_URL="http://internal-bmi-backend-alb-2130460227.eu-west-1.elb.amazonaws.com"

# Go to existing frontend code (NO GIT)
cd /var/www/3-tier-web-app-auto-scalling/frontend

# Ensure API uses relative path
cat > src/api.js << 'EOF'
import axios from 'axios';

export default axios.create({
  baseURL: '/api',
});
EOF

# Install & build
npm install
npm run build

# NGINX CONFIG
sudo tee /etc/nginx/conf.d/frontend.conf > /dev/null <<EOF
server {
    listen 80;
    server_name _;
    root /var/www/3-tier-web-app-auto-scalling/frontend/dist;
    index index.html;

    location / {
        try_files \$uri /index.html;
    }

    location /health {
        return 200 "healthy";
        add_header Content-Type text/plain;
    }

    location /api/ {
        proxy_pass ${BACKEND_ALB_URL}/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Restart nginx
sudo nginx -t
sudo systemctl restart nginx

echo "========================================="
echo "Frontend deployment complete"
echo "========================================="