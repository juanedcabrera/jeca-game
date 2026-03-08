# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Cabrera Harvest** — A family farm adventure / educational game built with Godot 4.3 (GDScript). Deployed as a web app (WASM) via nginx + Docker, with Supabase backend for auth and cloud saves. Designed as a PWA for iPhone home screens.

## Architecture

### Autoload Singletons (global managers, always loaded)
- **PlayerData** (`autoload/player_data.gd`) — In-memory player state: coins, inventory, farm tiles (4×3 grid), animals, progress tracking. Emits signals: `coins_changed`, `inventory_changed`, `day_advanced`.
- **GameManager** (`autoload/game_manager.gd`) — Scene routing (name→path mapping), spawn point tracking, UI helpers (`make_button()`, `make_label()`, `show_message()`).
- **Supabase** (`autoload/supabase.gd`) — JWT auth (email/password), cloud save sync (3 slots per account via upsert), session caching at `user://supabase_session.json`. Dev mode uses `http://127.0.0.1:54321`; production needs URL/key update in this file.

### Scenes (`scenes/`)
Each scene is standalone, coordinating through autoload singletons. Key scenes:
- `farm.gd` (761 LOC) — Main gameplay: player movement, tile management, crop growth. Uses inner classes `FarmTileDrawer`, `PlayerDrawer`.
- `math_mines.gd` — Cave minigame: solve 5 math problems (addition/subtraction) at ore veins.
- `literacy_library.gd` — Reading minigame: word cards at bookshelves.
- `juarez_market.gd` — Buy/sell crops and items.
- `house_interior.gd` — Sleeping advances day.
- `login_screen.gd` / `start_screen.gd` / `character_creation.gd` — Auth and onboarding flow.

### Backend
- **Database**: Single `public.save_slots` table with RLS (users access only their own rows). Schema in `deploy/supabase_setup.sql`.
- **Sync model**: Local file is source of truth; Supabase is async cloud cache. Game works offline.

## Development

### Local setup
```bash
supabase start          # Local Supabase on localhost:54321
# Open project in Godot 4.3+, press F5 to run
supabase stop           # When done
```

### Export & build
```bash
# Godot web export (headless)
godot4 --headless --export-release "Web" deploy/web_export/index.html

# Docker build
cd deploy/ && docker build -t cabrera-harvest:latest .
```

### CI/CD
GitHub Actions (`.github/workflows/deploy.yml`) triggers on push to `main`:
1. Installs Godot 4.3 + export templates (cached)
2. Exports game as Web
3. Builds Docker image → pushes to `ghcr.io/juanedcabrera/jeca-game:latest`
4. Triggers Dokploy webhook for auto-redeploy

### No automated tests
Testing is manual. Local save data lives at `~/.local/share/godot/app_userdata/Cabrera Harvest/`.

## Key Technical Details

- **Resolution**: 960×540 (16:9, mobile-friendly), stretch mode `canvas_items`
- **Renderer**: OpenGL Compatibility (required for web export)
- **nginx CORS headers** (`deploy/nginx.conf`): `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp` are required for Godot 4 WASM/SharedArrayBuffer
- **Art assets**: Pixelwood Valley tileset (sprites: 59×49px) committed to repo for CI export
- **GDScript only**: No external package dependencies

## Agent System

Specialized AI agents for game development live in `.claude/agents/`. Each agent has a markdown prompt file and reads shared context from `.claude/agents/context/`.

### Usage

To use an agent, delegate via Claude Code's Agent tool:
```
Read /home/juan/projects/jeca-game/.claude/agents/[agent].md for your instructions, then: [task]
```

For complex features, use the **orchestrator** — it plans, delegates to subagents in the right order, and reviews results:
```
Read /home/juan/projects/jeca-game/.claude/agents/orchestrator.md for your instructions, then: [feature request]
```

### Available Agents

| Agent | File | Use For |
|-------|------|---------|
| **Orchestrator** | `orchestrator.md` | Multi-step features, coordinates other agents |
| **Scene Builder** | `scene-builder.md` | New walkable locations (follows scene skeleton pattern) |
| **Minigame Designer** | `minigame-designer.md` | New educational minigames (quiz overlay pattern) |
| **Economy Balancer** | `economy-balancer.md` | Validate coin rewards, item costs, progression |
| **Backend Schema** | `backend-schema.md` | Add persistent data across player_data/supabase/SQL |
| **QA Reviewer** | `qa-reviewer.md` | Code review, consistency checks, bug detection |
| **Art (Procedural)** | `art-procedural.md` | Enhance GDScript `_draw()` visuals and effects |
| **Art (Blender)** | `art-blender.md` | Generate sprite sheets via Blender Python scripts |

### Shared Context Files

Agents read from `.claude/agents/context/`:
- `patterns.md` — Scene skeleton, player setup, collision, quiz overlay patterns
- `economy-data.md` — All coin values, costs, earning rates, balance issues
- `file-map.md` — Every file with purpose, sync requirements
- `sprite-catalog.md` — All sprite paths, dimensions, usage
- `blender-pipeline.md` — Blender scripting conventions, output specs

### Blender Pipeline

Sprite generation scripts live in `tools/blender/`. Run with:
```bash
blender --background --python tools/blender/generate_[asset].py
```
Output goes to `generated_sprites/`. Requires Blender 4.x and Pillow.
