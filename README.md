# Emergency Dispatch

This project is a Godot-based emergency response management game inspired by the call-handling and dispatch flow of 911 Operator.

The goal is not to make a pure driving game or a pure visual novel. The goal is to make a dispatch simulator where the player reads the map, answers incoming emergency calls, decides how to respond, and sends the correct unit to the scene under pressure.

## What We Are Trying To Make

We are building a playable dispatch loop with these core pieces:

- A city map with roads, patrol routes, and moving service vehicles.
- Random emergency incidents that appear near roads as active map alerts.
- Clickable incident markers that open a live call handling panel.
- A caller transcript that plays out over time instead of showing everything instantly.
- A player response step before dispatch.
- Difficulty-based input modes:
	- Easy mode uses multiple-choice responses.
	- Advanced or profressional mode uses typed responses with NLP-style evaluation.
- Unit dispatch decisions based on the actual emergency type.
- Different timing and outcome pressure based on incident severity and response quality.
- A rule that the player cannot close the call until emergency services have arrived.

In short: this is a map-based emergency communication and dispatch simulator with light incident management, not a combat game and not a traditional tycoon game.

## Intended Player Loop

1. Watch the map for a new emergency marker.
2. Click the marker to answer the call.
3. Read the live transcript and understand the situation.
4. Give an appropriate response to the caller.
5. Dispatch the correct emergency unit.
6. Wait for services to arrive and resolve the incident.
7. Close the call and prepare for the next emergency.

## Current Direction

The current prototype is focused on proving the gameplay loop inside Godot:

- Fire, medical, and criminal incidents.
- Dispatch options such as fire truck, ambulance, police, and rescue.
- Scenario generation with structured transcript and response evaluation.
- A guidebook or manual panel for quick emergency response reference.
- A patrol-map presentation so the game feels like a live operations board.

Later versions can deepen this with better scenario generation, smarter NLP evaluation, unit availability, consequences for poor dispatching, and broader city management systems.

## Project Structure

- Main playable scene: `scenes/maps/route_scene.tscn`
- Main menu scene: `scenes/ui/main_menu.tscn`
- Map assets: `assets/maps/`
- Runtime map scripts: `scripts/maps/`
- Vehicle systems: `scripts/vehicles/`
- Dispatch and scenario systems: `scripts/systems/`
- Route and gameplay data: `data/`

## Current Status

This is an active prototype. The main priority is making the emergency-call-to-dispatch loop solid, readable, and fun before expanding into larger simulation systems.
