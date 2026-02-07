// Load environment variables FIRST
require('dotenv').config();

const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const { Pool } = require('pg');

const app = express();

/* -------------------- Middleware -------------------- */
app.use(cors());
app.use(bodyParser.json());

/* -------------------- Database -------------------- */
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  ssl: false
});

pool.on('connect', () => {
  console.log('✅ Connected to PostgreSQL');
});

pool.on('error', (err) => {
  console.error('❌ PostgreSQL error:', err);
  process.exit(1);
});

/* -------------------- Routes -------------------- */
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'OK' });
});

app.get('/', (req, res) => {
  res.json({ message: 'BMI Backend API is running' });
});

/* -------------------- Start Server -------------------- */
const PORT = process.env.PORT || 3000;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Backend running on port ${PORT}`);
});

/* -------------------- how to run -------------------- 

pm2 delete bmi-backend
pm2 start src/server.js --name bmi-backend
pm2 save

-------------------- Start Server -------------------- */