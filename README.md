# Cabrera Harvest

A family farm adventure and educational game built with Godot 4. Players manage a farm, solve math problems, practice letter recognition, and trade at a village market — all while earning coins and watching their crops grow.

Designed for children and families. Runs as a web app (WASM) and can be installed as a PWA on iPhones.

**Made with love by the Cabrera Family**

---

## Game Overview

Players sign into a family account and choose one of three save slots. Each player creates a character (boy or girl), names them, and begins their adventure on the Cabrera Farm — inherited from Grandma Rosa.

The gameplay loop:
1. **Earn coins** by solving math problems at the Math Mines or matching letters at the Literacy Library
2. **Spend coins** at the Juarez Market to buy seeds, livestock, and tools
3. **Grow crops** on your 4x3 farm grid — till, plant, water, and harvest
4. **Tend animals** in the barn pen for daily coin income
5. **Sleep** in your farmhouse bed to advance the day (crops grow overnight if watered)

---

## Scenes

### Login Screen
The entry point. Players sign in or create a family account using email and password. One account supports up to 3 players through save slots. Authentication is handled through Supabase.

### Start Screen (Save Slot Selection)
After signing in, players see three save slot cards. Each card shows the player's name, avatar, current day, and coin count. Players can:
- **Play** an existing save
- **Start a New Game** in an empty slot
- **Delete** a save
- **Sign Out**

Cloud saves sync automatically from Supabase when this screen loads.

### Character Creation
New players choose their gender (boy or girl) and enter a name (up to 14 characters). A live animated preview shows the selected character. Pressing "Begin Your Adventure!" creates the save and enters the farmhouse for the intro sequence.

### House Interior
The player's farmhouse. On the first visit, an intro dialogue from Grandma Rosa teaches the basics:
- Math Mines are to the north for earning coins
- Literacy Library is to the east for letter practice and fertilizer rewards
- Juarez Market is to the south for buying supplies
- Sleep in bed to save and advance the day

**Interactions:**
- **Bed** — Sleep to advance to the next day. Crops grow overnight if watered. Game auto-saves.
- **Door** — Exit to the farm.

### Farm (Main Scene)
The central hub connecting all locations. The farm features:

**Farm Grid (4x3 = 12 tiles):**
Each tile has a lifecycle: Empty -> Tilled -> Planted -> Ready to Harvest
- **Till** empty soil with your hand
- **Plant** seeds (sunflower, carrot, or strawberry) in tilled soil
- **Water** planted crops with the water jug (crops must be watered each day to grow)
- **Harvest** ready crops for coins

**Crop Economics:**
| Crop | Seed Cost | Growth Time | Harvest Value |
|------|-----------|-------------|---------------|
| Sunflower | 5 coins | 2 days | 8 coins |
| Carrot | 8 coins | 3 days | 5 coins |
| Strawberry | 12 coins | 4 days | 12 coins |

**Tool Bar (bottom of screen):**
Switch tools with buttons or keyboard shortcuts (1-5):
1. Hand (till soil)
2. Water Jug (water crops)
3. Sunflower Seeds
4. Carrot Seeds
5. Strawberry Seeds

**Buildings & Zones:**
- **Farmhouse** (west) — Enter with [E] to sleep and save
- **Barn & Animal Pen** (east) — Tend animals with [E] for 2 coins per animal per day
- **Well** (decorative, between house and farm)

**Exit Paths (walk into them to travel):**
- **North** — Math Mines
- **East** — Literacy Library
- **South** — Juarez Market

### Math Mines
A cave environment with two interactive ore veins. Players walk around and approach ore to start a quiz.

**Gold Ore (Addition):**
- 5 problems per session
- Random single-digit addition (e.g., 3 + 7 = ?)
- 5 multiple-choice answers
- **+2 coins** per correct answer
- Visual dot helper for counting

**Purple Ore (Subtraction):**
- 5 problems per session
- Subtraction with numbers up to 12 (e.g., 9 - 4 = ?)
- 5 multiple-choice answers
- **+3 coins** per correct answer
- Visual dot helper with crossed-out dots for subtraction

After completing 5 problems, a results screen shows coins earned and total problems solved. Players can mine again or return to the farm.

### Literacy Library
An interior library with bookshelves. Players walk to a bookshelf and press [E] to start a letter-matching game.

**Gameplay:**
- 5 rounds per session (randomly selected from 26 letters)
- A large uppercase letter is displayed (e.g., "A")
- 3 lowercase options are shown — pick the matching one
- **+2 coins** per correct answer
- **Bonus:** Every 5 letters matched earns a free Fertilizer item

Results screen shows total letters matched, coins, and fertilizer count. Players can read more or return to the farm.

### Juarez Market
A village market with three NPC shopkeepers, each at their own stall. Walk up to an NPC and press [E] to open their shop.

**Sofi (Seeds):**
| Item | Cost |
|------|------|
| Sunflower Seeds | 5 coins |
| Carrot Seeds | 8 coins |
| Strawberry Seeds | 12 coins |

**Lucas (Livestock):**
| Item | Cost | Daily Income |
|------|------|--------------|
| Chicken | 15 coins | 2 coins/day |
| Pig | 20 coins | 3 coins/day |
| Cow | 30 coins | 5 coins/day |

**The Merchant (Tools):**
| Item | Cost | Effect |
|------|------|--------|
| Water Jug | Free | Water crops (you start with one) |
| Sprinkler | 40 coins | Auto-waters all crops each day |
| Fertilizer | 15 coins | Speeds up crop growth by 1 day |

The shop overlay has tabs for each category, shows current inventory, and the player's coin balance updates in real time.

---

## Controls

| Key | Action |
|-----|--------|
| W/A/S/D or Arrow Keys | Move |
| E | Interact (talk, till, plant, water, harvest, enter buildings) |
| 1-5 | Select tool (Hand, Water, Sunflower, Carrot, Strawberry) |
| Escape | Pause menu (Save & Exit or Resume) |

---

## Technical Stack

- **Engine:** Godot 4.3 (GDScript)
- **Backend:** Supabase (PostgreSQL + Auth + REST API)
- **Deployment:** Docker (nginx Alpine) via Dokploy
- **CI/CD:** GitHub Actions — auto-builds and deploys on push to main
- **Art:** Pixelwood Valley pixel art tileset (59x49px sprites)
- **Resolution:** 960x540 (16:9, mobile-friendly)

---

## Project Structure

```
autoload/               Global singletons (always loaded)
  player_data.gd        Player state, inventory, farm grid, save/load
  game_manager.gd       Scene routing, spawn points, UI helpers
  supabase.gd           Auth, cloud save sync, HTTP client

scenes/                 Game scenes
  login_screen.gd       Email/password auth
  start_screen.gd       Save slot selection (3 slots per account)
  character_creation.gd Name + gender selection
  farm.gd               Main farm gameplay, crop management
  house_interior.gd     Intro dialogue, sleeping, day advancement
  math_mines.gd         Addition & subtraction quiz minigame
  literacy_library.gd   Letter recognition minigame
  juarez_market.gd      NPC shops for seeds, livestock, tools

deploy/                 Deployment files
  Dockerfile            nginx Alpine + web export
  nginx.conf            CORS headers, WASM MIME types, caching
  supabase_setup.sql    Database schema + RLS policies
  README.md             Deployment instructions
```

---

## Development

### Local Setup
```bash
# Start local Supabase (auth + database)
supabase start

# Open in Godot 4.3+, press F5 to run

# Stop Supabase when done
supabase stop
```

### Build & Deploy
```bash
# Export for web
godot4 --headless --export-release "Web" deploy/web_export/index.html

# Build Docker image
cd deploy && docker build -t cabrera-harvest:latest .
```

See [deploy/README.md](deploy/README.md) for full deployment instructions including Supabase cloud setup, Dokploy configuration, and iOS PWA installation.
