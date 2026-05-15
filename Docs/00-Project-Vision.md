# Project Aeloria - Vision & Goals

## Core Vision

Project Aeloria aims to be the definitive **Quality of Life** experience for *Command & Conquer: Red Alert Remastered* for players who love the classic gameplay but want modern conveniences.

## What We Love (Keep and Improve)

- Excellent harvester intelligence (Rampastring-style "last refinery" memory + queue jumping + smart refinery choice)
- Rally points on all production buildings (Barracks/Tent, War Factory, Shipyard/Sub Pen, Helipad, Airfield, Repair Bay)
- A* pathfinding improvements (units no longer stupidly hug cliffs)
- Modern wall building (chain placement)
- Significantly more zoom levels (especially further out)
- General "the game just feels nicer" improvements

## What We Do NOT Want

- Overly aggressive / cheating AI (player explicitly prefers playing against relatively dumb, predictable opponents)
- Major balance overhauls that change the soul of classic Red Alert
- New units or factions (unless extremely well justified later)

## Safety & Revertibility Principles

1. Every significant behavioral change must be documented.
2. We maintain a clean "Vanilla-Plus" profile that is always easy to fall back to.
3. Risky experiments always live in the Experimental profile first.
4. Feature flags / INI toggles are preferred over hard-coded changes when possible.

## Long-term Ambition

Build something so good that it becomes many people's default way to play Red Alert Remastered in 2026+.

## Current Foundation

- Based on Rampastring's excellent "More QoL Improvements" mod
- Full `RedAlert.dll` source modification capability
- Proper development workflow with fast launchers
