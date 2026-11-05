/**
 * SafeScape 2.0 - The Right Call Cloud Backend (Node.js / Express)
 * Implements:
 *   1. GET  /api/games/right-call/load?user_id=101
 *   2. POST /api/games/right-call/save
 *   3. Static file serving for web wrapper & Godot export
 */

const express = require('express');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 3000;
const DB_FILE = path.join(__dirname, 'cloud_database.json');

// Middleware
app.use(express.json());

// Enable CORS for cross-origin iframes
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
  res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  // Essential headers for SharedArrayBuffer / Godot web threads if needed
  res.header('Cross-Origin-Opener-Policy', 'same-origin');
  res.header('Cross-Origin-Embedder-Policy', 'require-corp');
  if (req.method === 'OPTIONS') return res.sendStatus(200);
  next();
});

// Load / Save JSON database helper
function loadDatabase() {
  if (!fs.existsSync(DB_FILE)) {
    const defaultData = {
      users: {
        "101": {
          user_id: 101,
          player_name: "Officer Juan Santos",
          high_score: 450,
          total_calls_handled: 5,
          successful_calls: 4,
          failed_calls: 1,
          completed_scenarios: ["call_kitchen_fire"],
          is_won: false,
          last_saved: new Date().toISOString()
        },
        "202": {
          user_id: 202,
          player_name: "Cadet Maria Reyes",
          high_score: 300,
          total_calls_handled: 3,
          successful_calls: 3,
          failed_calls: 0,
          completed_scenarios: ["call_electrical_hazard"],
          is_won: false,
          last_saved: new Date().toISOString()
        }
      }
    };
    fs.writeFileSync(DB_FILE, JSON.stringify(defaultData, null, 2));
    return defaultData;
  }
  return JSON.parse(fs.readFileSync(DB_FILE, 'utf-8'));
}

function saveDatabase(data) {
  fs.writeFileSync(DB_FILE, JSON.stringify(data, null, 2));
}

// ── 1. GET /api/games/right-call/load?user_id=101 ─────────────────────────
app.get('/api/games/right-call/load', (req, res) => {
  const userId = req.query.user_id;

  if (!userId || userId === 'guest') {
    return res.json({
      high_score: 0,
      total_calls_handled: 0,
      successful_calls: 0,
      failed_calls: 0,
      completed_scenarios: []
    });
  }

  const db = loadDatabase();
  const userRecord = db.users[userId];

  if (userRecord) {
    console.log(`[Cloud Load] Found profile for user_id=${userId}:`, userRecord);
    return res.json({
      user_id: userRecord.user_id,
      player_name: userRecord.player_name,
      high_score: userRecord.high_score || 0,
      total_calls_handled: userRecord.total_calls_handled || 0,
      successful_calls: userRecord.successful_calls || 0,
      failed_calls: userRecord.failed_calls || 0,
      completed_scenarios: userRecord.completed_scenarios || []
    });
  }

  // Create new profile if not found
  console.log(`[Cloud Load] Creating new profile for user_id=${userId}`);
  const newRecord = {
    user_id: parseInt(userId) || 0,
    player_name: `Dispatcher_${userId}`,
    high_score: 0,
    total_calls_handled: 0,
    successful_calls: 0,
    failed_calls: 0,
    completed_scenarios: [],
    is_won: false,
    last_saved: new Date().toISOString()
  };
  db.users[userId] = newRecord;
  saveDatabase(db);

  res.json(newRecord);
});

// ── 2. POST /api/games/right-call/save ────────────────────────────────────
app.post('/api/games/right-call/save', (req, res) => {
  const payload = req.body;
  console.log("[Cloud Save] Received payload:", payload);

  const userId = String(payload.user_id || '0');
  if (userId === '0' || userId === 'guest') {
    return res.json({ status: 'saved', note: 'Guest progress acknowledged without persistent DB write' });
  }

  const db = loadDatabase();
  const existing = db.users[userId] || {
    user_id: parseInt(userId),
    player_name: `User_${userId}`,
    high_score: 0,
    total_calls_handled: 0,
    successful_calls: 0,
    failed_calls: 0,
    completed_scenarios: []
  };

  // Update metrics according to profile
  existing.high_score = Math.max(existing.high_score || 0, payload.score || 0);
  existing.total_calls_handled = Math.max(existing.total_calls_handled || 0, payload.calls_handled || 0);
  existing.successful_calls = Math.max(existing.successful_calls || 0, payload.successful_calls || 0);
  existing.failed_calls = Math.max(existing.failed_calls || 0, payload.failed_calls || 0);
  
  // Merge completed scenarios
  if (Array.isArray(payload.completed_scenarios)) {
    const scSet = new Set([...(existing.completed_scenarios || []), ...payload.completed_scenarios]);
    existing.completed_scenarios = Array.from(scSet);
  }

  if (payload.is_won) {
    existing.is_won = true;
    existing.won_at = new Date().toISOString();
  }

  existing.last_saved = new Date().toISOString();
  db.users[userId] = existing;
  saveDatabase(db);

  console.log(`[Cloud Save] Successfully saved profile for user_id=${userId}. High Score: ${existing.high_score}`);

  res.status(200).json({
    status: 'saved',
    user_id: existing.user_id,
    high_score: existing.high_score,
    total_calls: existing.total_calls_handled
  });
});

// ── 3. Static Hosting for Web Portal & Godot Export ──────────────────────
app.use('/kids/the-right-call', express.static(path.join(__dirname, 'web_wrapper')));
app.use('/games/the-right-call', express.static(path.join(__dirname, '..', 'export', 'web')));

app.get('/', (req, res) => {
  res.redirect('/kids/the-right-call');
});

// Start Server
app.listen(PORT, () => {
  console.log(`====================================================`);
  console.log(` SafeScape Cloud Server running at http://localhost:${PORT}`);
  console.log(` Game Web Wrapper: http://localhost:${PORT}/kids/the-right-call`);
  console.log(` API Endpoints:`);
  console.log(`   GET  /api/games/right-call/load?user_id=101`);
  console.log(`   POST /api/games/right-call/save`);
  console.log(`====================================================`);
});
