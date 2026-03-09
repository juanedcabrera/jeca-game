# Economy Data Reference

All coin values and item data extracted from the codebase. This is the source of truth for balancing.

**Design principle:** Math and reading are ALWAYS the primary way to earn coins. Farming is a fun reward loop but cannot replace education.

## Starting Conditions

- Coins: 10
- Inventory: 1 water jug, 0 of everything else
- Farm: 12 empty tiles (4x3 grid)
- Animals: none
- Day: 1

## Earning Sources

### Math Mines (`math_mines.gd`)
| Activity | Coins/Correct | Problems/Session | Max Coins/Session |
|----------|---------------|------------------|-------------------|
| Gold Ore (Addition) | 3 | 5 | 15 |
| Purple Ore (Subtraction) | 4 | 5 | 20 |
| Emerald Ore (Multiplication) | 5 | 5 | 25 |
| Diamond Ore (Division) | 6 | 5 | 30 |

Sessions are unlimited — player can mine again immediately after results.

**Progressive unlocking:** Addition always available. Subtraction after 15 addition solved. Multiplication after 15 subtraction solved. Division after 15 multiplication solved.

**Age-based difficulty:** 5 tiers (4-5, 6-7, 8-9, 10-11, 12+) determine number ranges.

### Literacy Library (`literacy_library.gd`)
| Reward | Amount | Condition |
|--------|--------|-----------|
| Coins | 3/correct | Per correct answer (all activity types) |
| Fertilizer | 1 | Every 5 total words read (`words_read % 5 == 0`) |

5 rounds per session, max 15 coins/session. Sessions unlimited.

### Farming (`player_data.gd` harvest_tile)
| Crop | Seed Cost | Growth Days | Harvest Value | Net Profit | ROI/Day |
|------|-----------|-------------|---------------|------------|---------|
| Sunflower | 5 | 2 | 6 | +1 | 0.5/day |
| Carrot | 8 | 3 | 10 | +2 | 0.67/day |
| Strawberry | 12 | 4 | 16 | +4 | 1.0/day |

All crops are mildly profitable. Farming supplements math/reading income but cannot replace it.

**Sprinkler** (40 coins, permanent): Auto-waters all planted crops at start of each new day.
**Fertilizer** (15 coins or earned from reading, consumable): Use on a watered crop to boost growth by +1 day.

### Animal Tending (`farm.gd` _tend_animals)
| Animal | Purchase Cost | Daily Income | Food Cost | Net/Day | Days to ROI |
|--------|---------------|--------------|-----------|---------|-------------|
| Chicken | 15 | 2 | 8 (shared) | varies | ~12 |
| Pig | 20 | 3 | 8 (shared) | varies | ~10 |
| Cow | 30 | 5 | 8 (shared) | varies | ~8 |

Animals earn coins when player tends them (press [E] near pen). Once per day, requires 1 Animal Food (cost 8). One food feeds all animals. Max 3 animals (pen capacity).

Example: 3 cows = 15 coins - 8 food = 7 net/day.

### Summary: Earning Rates
- **Best coins:** Math division (30 coins/session, ~2 min) — requires solving problems
- **Good coins:** Math addition (15/session), Reading (15/session)
- **Supplemental:** Animals (2-7 net coins/day depending on animals owned)
- **Supplemental:** Crop farming (~6 coins/day with 12 sunflower tiles, requires sprinkler)

**Math/reading sessions give 2-5x more coins per minute than passive farming.**

## Spending Sinks

### Seeds (`juarez_market.gd` SHOP_ITEMS.seeds)
| Item ID | Display Name | Cost |
|---------|-------------|------|
| `sunflower_seeds` | Sofi's Sunflower Seeds | 5 |
| `carrot_seeds` | Sofi's Carrot Seeds | 8 |
| `strawberry_seeds` | Sofi's Strawberry Seeds | 12 |

### Livestock (`juarez_market.gd` SHOP_ITEMS.livestock)
| Item ID | Display Name | Cost |
|---------|-------------|------|
| `chicken` | Lucas's Chicken | 15 |
| `pig` | Lucas's Pig | 20 |
| `cow` | Lucas's Cow | 30 |

Max 3 animals (pen capacity).

### Supplies (`juarez_market.gd` SHOP_ITEMS.tools — sold by Abuelo)
| Item ID | Display Name | Cost |
|---------|-------------|------|
| `sprinkler` | Sprinkler | 40 |
| `fertilizer` | Fertilizer | 15 |
| `animal_food` | Animal Food | 8 |

## Inventory Item IDs (exact strings)

From `player_data.gd` default inventory:
```
water_jug, sunflower_seeds, carrot_seeds, strawberry_seeds, fertilizer, sprinkler, animal_food
```

Animal types (stored in `animals` array, not inventory):
```
chicken, pig, cow
```

## Progression Timeline (estimated)

- **Day 1:** Start with 10 coins. Do 1-2 math sessions (+15-30 coins). Buy sunflower seeds.
- **Day 2-3:** Farm sunflowers, do math/reading for coins. Save for first animal.
- **Day 5-7:** Can afford a chicken (15 coins). Start earning supplemental income.
- **Day 8-12:** Multiple animals, farm running. Saving for sprinkler (40 coins).
- **Day 15+:** Sprinkler purchased. Economy supplements math but doesn't replace it.

## Balance Invariant

**Math/reading must always be the fastest way to earn coins.** If passive farming ever exceeds ~50% of a math session's income per equivalent time, the economy needs rebalancing.
