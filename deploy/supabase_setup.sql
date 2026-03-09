-- =============================================================================
-- Cabrera Harvest — Supabase Setup
-- Run this in the Supabase SQL Editor (supabase.com → your project → SQL Editor)
-- =============================================================================

-- 1. Save slots table
CREATE TABLE IF NOT EXISTS public.save_slots (
    id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id               uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    slot_number           int         NOT NULL CHECK (slot_number BETWEEN 0 AND 2),
    player_name           text        NOT NULL DEFAULT 'Friend',
    player_gender         text        NOT NULL DEFAULT 'boy',
    coins                 int         NOT NULL DEFAULT 10,
    day                   int         NOT NULL DEFAULT 1,
    inventory             jsonb       NOT NULL DEFAULT '{}',
    farm_tiles            jsonb       NOT NULL DEFAULT '[]',
    animals               jsonb       NOT NULL DEFAULT '[]',
    math_problems_solved  int         NOT NULL DEFAULT 0,
    math_addition_solved  int         NOT NULL DEFAULT 0,
    math_subtraction_solved int       NOT NULL DEFAULT 0,
    math_multiplication_solved int    NOT NULL DEFAULT 0,
    math_division_solved  int         NOT NULL DEFAULT 0,
    words_read            int         NOT NULL DEFAULT 0,
    intro_seen            boolean     NOT NULL DEFAULT false,
    player_age            int         NOT NULL DEFAULT 0,
    animals_tended_today  boolean     NOT NULL DEFAULT false,
    game_started          boolean     NOT NULL DEFAULT false,
    updated_at            timestamptz NOT NULL DEFAULT now(),

    UNIQUE (user_id, slot_number)
);

-- 1b. Migration: add new columns for existing databases
ALTER TABLE public.save_slots ADD COLUMN IF NOT EXISTS player_age int NOT NULL DEFAULT 0;
ALTER TABLE public.save_slots ADD COLUMN IF NOT EXISTS math_addition_solved int NOT NULL DEFAULT 0;
ALTER TABLE public.save_slots ADD COLUMN IF NOT EXISTS math_subtraction_solved int NOT NULL DEFAULT 0;
ALTER TABLE public.save_slots ADD COLUMN IF NOT EXISTS math_multiplication_solved int NOT NULL DEFAULT 0;
ALTER TABLE public.save_slots ADD COLUMN IF NOT EXISTS math_division_solved int NOT NULL DEFAULT 0;
ALTER TABLE public.save_slots ADD COLUMN IF NOT EXISTS animals_tended_today boolean NOT NULL DEFAULT false;
ALTER TABLE public.save_slots ADD COLUMN IF NOT EXISTS game_started boolean NOT NULL DEFAULT false;

-- Migrate legacy data: credit existing math_problems_solved to addition
UPDATE public.save_slots
SET math_addition_solved = math_problems_solved
WHERE math_problems_solved > 0
  AND math_addition_solved = 0
  AND math_subtraction_solved = 0
  AND math_multiplication_solved = 0
  AND math_division_solved = 0;

-- 2. Auto-update updated_at on every write
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS save_slots_updated_at ON public.save_slots;
CREATE TRIGGER save_slots_updated_at
    BEFORE UPDATE ON public.save_slots
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 3. Row-Level Security: each user can only read/write their own rows
ALTER TABLE public.save_slots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own saves" ON public.save_slots;
CREATE POLICY "Users manage own saves"
    ON public.save_slots
    FOR ALL
    USING  (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
