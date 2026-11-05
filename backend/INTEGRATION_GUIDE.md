# SafeScape 2.0 / The Right Call: Website & Cloud Profile Integration Guide

This guide details how **The Right Call** Godot game integrates with a web platform (such as **SafeScape**), retrieving player profiles and saving game progress to the cloud based on their active session.

---

## Architecture Overview

```
+-----------------------------------------------------------------------------------+
|  WEBSITE HOST / BROWSER WRAPPER (e.g., https://safescape.gov.ph/kids/the-right-call) |
|                                                                                   |
|  1. Authenticates player profile (Session / Cookies / Token)                      |
|  2. Embeds Godot game in <iframe> with query parameters:                          |
|     <iframe src="/games/the-right-call/index.html?user_id=101&player_name=Officer+Santos">
|                                                                                   |
|     +-----------------------------------------------------------------------+     |
|     |  GODOT 4 WEB INSTANCE (index.html, index.wasm, index.pck)            |     |
|     |                                                                       |     |
|     |  - CloudSaveManager reads:                                            |     |
|     |      user_id = URLSearchParams("user_id")                             |     |
|     |      player_name = URLSearchParams("player_name")                     |     |
|     |  - Loads Cloud Stats:                                                 |     |
|     |      GET /api/games/right-call/load?user_id=101                       |     |
|     |  - When call completes or game won:                                   |     |
|     |      window.parent.postMessage({                                      |     |
|     |        type: 'RIGHT_CALL_SAVE',                                       |     |
|     |        payload: { user_id, score, calls_handled, ... }                |     |
|     |      }, '*');                                                         |     |
|     +-----------------------------------------------------------------------+     |
|                                                                                   |
|  3. Window Message Listener (Parent):                                             |
|     window.addEventListener('message', (event) => { ... })                        |
|                                                                                   |
|  4. Cloud Forwarder (Parent -> Backend):                                          |
|     POST /api/games/right-call/save                                               |
+-----------------------------------------------------------------------------------+
                                   |
                                   v
+-----------------------------------------------------------------------------------+
|  CLOUD BACKEND API (Node.js Express / Python FastAPI / PHP / Next.js)             |
|                                                                                   |
|  - GET  /api/games/right-call/load?user_id=101 -> Returns profile & high score    |
|  - POST /api/games/right-call/save             -> Persists stats to DB (200 OK)   |
+-----------------------------------------------------------------------------------+
```

---

## 1. Godot Implementation

### Autoload Configuration (`project.godot`)
```ini
[autoload]
GameState="*res://scripts/systems/game_state.gd"
AudioManager="*res://scripts/systems/audio_manager.gd"
CloudSaveManager="*res://scripts/systems/cloud_save_manager.gd"
```

### Script: `res://scripts/systems/cloud_save_manager.gd`
- **Automatic Environment Detection**:
  - In Web builds: parses `user_id` and `player_name` via `JavaScriptBridge.eval("new URLSearchParams(window.location.search)...")`.
  - In Desktop/Editor builds: safely degrades to local simulation without throwing Web errors.
- **Loading Profile Progress**:
  - Automatically queries `GET /api/games/right-call/load?user_id=<user_id>` via `HTTPRequest`.
  - Emits `progress_loaded(Dictionary)` and syncs data with `GameState`.
- **Saving Progress**:
  - `save_progress(current_score, calls_handled, successful, failed, scenario_id, is_won)`
  - Dispatches `window.parent.postMessage({ type: 'RIGHT_CALL_SAVE', payload }, '*')`.

### Where to Call in Godot
- **When an emergency call finishes** (in `route_scene.gd` `_complete_current_call`):
  ```gdscript
  CloudSaveManager.save_progress(
      _total_score,
      1,
      1 if is_success else 0,
      0 if is_success else 1,
      scenario_id,
      false
  )
  ```
- **When the player beats the game** (in `route_scene.gd` `_show_shift_review`):
  ```gdscript
  CloudSaveManager.save_progress(
      _total_score,
      0,
      0,
      0,
      "call_boss_scenario",
      true
  )
  ```

---

## 2. Website Frontend Implementation

### HTML Embedding with User Profile
```html
<!-- Embed the Godot Game inside your page (e.g. /kids/the-right-call) -->
<div class="game-wrapper" style="position: relative; width: 100%; aspect-ratio: 16/9;">
  <iframe
    id="the-right-call-game"
    src="/games/the-right-call/index.html?user_id=101&player_name=Officer+Santos"
    style="width: 100%; height: 100%; border: none;"
    allow="autoplay; fullscreen"
  ></iframe>
</div>
```

### JavaScript Message Listener (Host Page)
```javascript
window.addEventListener('message', async (event) => {
  // Check for the Right Call save message type
  if (!event.data || event.data.type !== 'RIGHT_CALL_SAVE') {
    return;
  }

  const payload = event.data.payload;
  console.log('[SafeScape] Received RIGHT_CALL_SAVE:', payload);

  try {
    const response = await fetch('/api/games/right-call/save', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(payload)
    });

    if (response.ok) {
      const result = await response.json();
      console.log('[SafeScape] Cloud save verified:', result);
    } else {
      console.error('[SafeScape] Save returned HTTP status:', response.status);
    }
  } catch (error) {
    console.error('[SafeScape] Network error sending save:', error);
  }
});
```

---

## 3. Backend Endpoints Specification

### 1. `GET /api/games/right-call/load?user_id=:id`
- **Query Parameter**: `user_id` (String/Integer)
- **Response Format (200 OK)**:
```json
{
  "user_id": 101,
  "player_name": "Officer Juan Santos",
  "high_score": 500,
  "total_calls_handled": 12,
  "successful_calls": 11,
  "failed_calls": 1,
  "completed_scenarios": ["call_kitchen_fire", "call_electrical_hazard"]
}
```

### 2. `POST /api/games/right-call/save`
- **Request Body (JSON)**:
```json
{
  "user_id": 101,
  "score": 550,
  "calls_handled": 13,
  "successful_calls": 12,
  "failed_calls": 1,
  "completed_scenarios": ["call_kitchen_fire", "call_electrical_hazard", "call_traffic_accident"],
  "is_won": false
}
```
- **Response Format (200 OK)**:
```json
{
  "status": "saved",
  "user_id": 101,
  "high_score": 550
}
```

---

## 4. Phase 4 Manual Browser Test

To verify that the postMessage listener and cloud save API write are working:
1. Log in to SafeScape as any user.
2. Open DevTools Console (**F12**) on `/kids/the-right-call`.
3. Dispatch a test event:
```javascript
window.postMessage({
  type: 'RIGHT_CALL_SAVE',
  payload: {
    score: 500,
    calls_handled: 2,
    successful_calls: 2,
    failed_calls: 0,
    completed_scenarios: ['test_call_01'],
    is_won: false
  }
}, '*');
```
4. Verify in the Network tab that `POST /api/games/right-call/save` returns status **200 OK** and `'saved'`.
