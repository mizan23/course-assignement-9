module.exports = {
  apps: [{
    name: 'bmi-backend',
    script: './src/server.js',
    cwd: '/var/www/app/backend',
    instances: 'max', // Use all available CPU cores for better performance
    exec_mode: 'cluster', // Enable cluster mode for multi-core utilization
    autorestart: true,
    watch: false,
    max_memory_restart: '500M',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true,
    merge_logs: true,
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z'
  }]
};
