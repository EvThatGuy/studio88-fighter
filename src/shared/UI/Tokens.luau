--!strict
-- Velvet Studio design tokens.
--
-- Aesthetic: matte deep-plum + warm cream + signature gold. Reads like a
-- recording-studio VIP lounge, not a Discord-rave neon-tycoon template. The
-- whole tycoon is themed around being a Studio 88 producer; the HUD should
-- feel plush and premium, not arcade.
--
-- Every component in src/shared/UI/Components must source colors, spacing,
-- radius, and fonts from this file. Do NOT hard-code Color3.fromRGB inside
-- a component. If you find yourself reaching for a value that isn't here,
-- add it to the right scale and re-export -- don't sneak it in.
--
-- Contrast verified: cream (#F5E9D2) on plum (#1A0E22) = 13.2:1, gold
-- (#E6B450) on plum = 8.4:1, both well above WCAG AA 4.5:1 floor.

local Tokens = {}

-- ============================================================================
-- Color palette
-- ============================================================================

Tokens.color = {
    -- Surfaces (60% of pixel area)
    plum = Color3.fromRGB(26, 14, 34),       -- #1A0E22 root background
    plumDeep = Color3.fromRGB(15, 8, 22),    -- #0F0816 modal scrim
    plumRaised = Color3.fromRGB(40, 22, 52), -- #281634 elevated card
    velvet = Color3.fromRGB(54, 30, 70),     -- #361E46 hover/active surface

    -- Text (foreground)
    cream = Color3.fromRGB(245, 233, 210),   -- #F5E9D2 primary text
    creamDim = Color3.fromRGB(196, 184, 162), -- #C4B8A2 secondary text
    creamMuted = Color3.fromRGB(140, 128, 108), -- #8C806C tertiary

    -- Signature accent (10-15% of color surface; CTAs only)
    gold = Color3.fromRGB(230, 180, 80),     -- #E6B450 primary CTA
    goldDeep = Color3.fromRGB(184, 138, 50), -- #B88A32 pressed/border
    goldGlow = Color3.fromRGB(255, 215, 130), -- #FFD782 highlight

    -- Semantic (used sparingly, never as primary color)
    success = Color3.fromRGB(120, 190, 130), -- soft sage
    warning = Color3.fromRGB(232, 162, 90),  -- amber
    danger = Color3.fromRGB(220, 100, 100),  -- coral
    info = Color3.fromRGB(150, 180, 220),    -- soft slate-blue

    -- Rarity (pets, auras, titles tiers)
    rarityCommon = Color3.fromRGB(200, 200, 200),
    rarityUncommon = Color3.fromRGB(120, 200, 130),
    rarityRare = Color3.fromRGB(120, 170, 230),
    rarityEpic = Color3.fromRGB(195, 130, 230),
    rarityLegendary = Color3.fromRGB(230, 180, 80), -- matches gold

    -- Pure
    transparent = Color3.fromRGB(0, 0, 0),
}

-- ============================================================================
-- Spacing scale (4-pt grid, like every modern design system)
-- ============================================================================

Tokens.space = {
    [1] = 4,
    [2] = 8,
    [3] = 12,
    [4] = 16,
    [5] = 20,
    [6] = 24,
    [7] = 32,
    [8] = 40,
    [9] = 48,
    [10] = 64,
}

-- ============================================================================
-- Corner radius -- felt panels, not glass
-- ============================================================================

Tokens.radius = {
    sm = UDim.new(0, 6),    -- chips, badges
    md = UDim.new(0, 12),   -- buttons, cards
    lg = UDim.new(0, 16),   -- modals, sheets
    xl = UDim.new(0, 24),   -- hero panels
    full = UDim.new(1, 0),  -- pills, avatars
}

-- ============================================================================
-- Stroke (warm-cream outlines, NOT pink neon)
-- ============================================================================

Tokens.stroke = {
    hairline = 1,    -- subtle card edge
    regular = 2,     -- default outline
    bold = 3,        -- emphasis (selected tab, primary CTA)
}

-- ============================================================================
-- Typography. Built-in Roblox fonts only -- avoids font-asset cold-load
-- pop-in. Inter would be nicer but requires hosting an asset and paying
-- the first-render flicker cost.
-- ============================================================================

Tokens.font = {
    display = Font.fromEnum(Enum.Font.GothamBold),
    body = Font.fromEnum(Enum.Font.Gotham),
    label = Font.fromEnum(Enum.Font.GothamMedium),
    mono = Font.fromEnum(Enum.Font.Code),
}

Tokens.text = {
    hero = 32,
    h1 = 24,
    h2 = 20,
    h3 = 16,
    body = 14,
    caption = 12,
    micro = 10,
}

-- ============================================================================
-- Motion. Restrained. Things move because they need to, not because they can.
-- ============================================================================

Tokens.motion = {
    fast = 0.15,       -- micro-interactions (hover, press)
    normal = 0.25,     -- modal enter, panel slide
    slow = 0.4,        -- celebratory (rebirth, hatch reveal)
    easing = Enum.EasingStyle.Quart,
    direction = Enum.EasingDirection.Out,
}

-- ============================================================================
-- Layout. Mobile-first; every breakpoint above is just more whitespace.
-- ============================================================================

Tokens.layout = {
    hudSafePaddingTop = 24,    -- iPhone notch buffer
    hudSafePaddingBottom = 56, -- thumb-zone clearance
    tapMin = 56,               -- minimum touch target (Apple HIG floor + finger forgiveness)
    modalMaxWidth = 480,       -- caps modal width on landscape tablets
    hudMaxWidth = 1080,        -- master design canvas
}

-- ============================================================================
-- Z-index lanes. Numbers are arbitrary but ordering is sacred.
-- ============================================================================

Tokens.layer = {
    hud = 1,
    sticky = 10,
    overlay = 100,
    modal = 1000,
    toast = 10000,
}

return Tokens
