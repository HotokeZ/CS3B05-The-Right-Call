"""
SafeScape 2.0 - The Right Call Cloud Backend (Python / FastAPI)
Implements:
  1. GET  /api/games/right-call/load?user_id=101
  2. POST /api/games/right-call/save
  3. Static file hosting for Godot Web export & web wrapper

Run with:
  pip install fastapi uvicorn
  python server_python.py
"""

import json
import os
from datetime import datetime
from typing import List, Optional
from fastapi import FastAPI, Query, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import RedirectResponse
from pydantic import BaseModel

app = FastAPI(title="SafeScape 2.0 Cloud Backend")

# Enable CORS for browser iframe postMessage communication
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

DB_FILE = os.path.join(os.path.dirname(__file__), "cloud_database.json")

def load_db():
    if not os.path.exists(DB_FILE):
        initial = {
            "users": {
                "101": {
                    "user_id": 101,
                    "player_name": "Officer Juan Santos",
                    "high_score": 450,
                    "total_calls_handled": 5,
                    "successful_calls": 4,
                    "failed_calls": 1,
                    "completed_scenarios": ["call_kitchen_fire"],
                    "is_won": False
                }
            }
        }
        with open(DB_FILE, "w", encoding="utf-8") as f:
            json.dump(initial, f, indent=2)
        return initial
    with open(DB_FILE, "r", encoding="utf-8") as f:
        return json.load(f)

def save_db(data):
    with open(DB_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)

class SavePayload(BaseModel):
    user_id: int
    score: int
    calls_handled: int
    successful_calls: int
    failed_calls: int
    completed_scenarios: List[str] = []
    is_won: bool = False

@app.get("/api/games/right-call/load")
def load_progress(user_id: str = Query(..., description="Logged-in User ID")):
    if not user_id or user_id == "guest":
        return {
            "high_score": 0,
            "total_calls_handled": 0,
            "successful_calls": 0,
            "failed_calls": 0,
            "completed_scenarios": []
        }

    db = load_db()
    users = db.setdefault("users", {})
    record = users.get(user_id)

    if record:
        return {
            "user_id": record.get("user_id", int(user_id) if user_id.isdigit() else 0),
            "player_name": record.get("player_name", f"Dispatcher_{user_id}"),
            "high_score": record.get("high_score", 0),
            "total_calls_handled": record.get("total_calls_handled", 0),
            "successful_calls": record.get("successful_calls", 0),
            "failed_calls": record.get("failed_calls", 0),
            "completed_scenarios": record.get("completed_scenarios", [])
        }

    # If new user
    new_user = {
        "user_id": int(user_id) if user_id.isdigit() else 0,
        "player_name": f"Dispatcher_{user_id}",
        "high_score": 0,
        "total_calls_handled": 0,
        "successful_calls": 0,
        "failed_calls": 0,
        "completed_scenarios": [],
        "is_won": False,
        "last_saved": datetime.utcnow().isoformat()
    }
    users[user_id] = new_user
    save_db(db)
    return new_user

@app.post("/api/games/right-call/save", status_code=status.HTTP_200_OK)
def save_progress(payload: SavePayload):
    uid_str = str(payload.user_id)
    if uid_str == "0" or uid_str == "guest":
        return {"status": "saved", "note": "Guest save acknowledged"}

    db = load_db()
    users = db.setdefault("users", {})
    record = users.get(uid_str, {
        "user_id": payload.user_id,
        "player_name": f"User_{payload.user_id}",
        "high_score": 0,
        "total_calls_handled": 0,
        "successful_calls": 0,
        "failed_calls": 0,
        "completed_scenarios": []
    })

    # Update profile metrics
    record["high_score"] = max(record.get("high_score", 0), payload.score)
    record["total_calls_handled"] = max(record.get("total_calls_handled", 0), payload.calls_handled)
    record["successful_calls"] = max(record.get("successful_calls", 0), payload.successful_calls)
    record["failed_calls"] = max(record.get("failed_calls", 0), payload.failed_calls)

    # Merge completed scenarios
    sc_set = set(record.get("completed_scenarios", []))
    sc_set.update(payload.completed_scenarios)
    record["completed_scenarios"] = list(sc_set)

    if payload.is_won:
        record["is_won"] = True
        record["won_at"] = datetime.utcnow().isoformat()

    record["last_saved"] = datetime.utcnow().isoformat()
    users[uid_str] = record
    save_db(db)

    return {
        "status": "saved",
        "user_id": payload.user_id,
        "high_score": record["high_score"]
    }

# Mount static web wrapper
web_wrapper_dir = os.path.join(os.path.dirname(__file__), "web_wrapper")
if os.path.exists(web_wrapper_dir):
    app.mount("/kids/the-right-call", StaticFiles(directory=web_wrapper_dir, html=True), name="wrapper")

# Mount Godot Web export
export_web_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "export", "web"))
if os.path.exists(export_web_dir):
    app.mount("/games/the-right-call", StaticFiles(directory=export_web_dir, html=True), name="game")

@app.get("/")
def index():
    return RedirectResponse(url="/kids/the-right-call/")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
