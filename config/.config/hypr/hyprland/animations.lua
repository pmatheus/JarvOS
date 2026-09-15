hl.config({
    animations = {
        enabled = true,
    },
})

-- ── Curves ──────────────────────────────────────────────────
-- Caelestia core curves — proper physics: decel on enter, accel on exit
hl.curve("specialWorkSwitch", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
hl.curve("emphasizedAccel",   { type = "bezier", points = { { 0.3, 0 },    { 0.8, 0.15 } } })
hl.curve("emphasizedDecel",   { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })

-- Standard Material 3 curves
hl.curve("standard",      { type = "bezier", points = { { 0.2, 0 }, { 0, 1 } } })
hl.curve("standardDecel", { type = "bezier", points = { { 0.0, 0 }, { 0, 1 } } })

-- Expressive curves for fluid, springy motion
hl.curve("spring", { type = "bezier", points = { { 0.15, 1.15 }, { 0.4, 1.0 } } })
hl.curve("snappy", { type = "bezier", points = { { 0.25, 1.0 },  { 0.3, 1.0 } } })
hl.curve("smooth", { type = "bezier", points = { { 0.33, 1.0 },  { 0.68, 1.0 } } })

-- ── Windows ─────────────────────────────────────────────────
-- Springy open, quick close — windows feel alive
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 4, bezier = "spring",          style = "popin 85%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 3, bezier = "emphasizedAccel", style = "popin 85%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "snappy" })

-- ── Layers (panels, drawers, overlays) ──────────────────────
-- Slide + fade for a polished feel
hl.animation({ leaf = "layersIn",   enabled = true, speed = 4, bezier = "emphasizedDecel", style = "slide" })
hl.animation({ leaf = "layersOut",  enabled = true, speed = 3, bezier = "emphasizedAccel", style = "slide" })
hl.animation({ leaf = "fadeLayers", enabled = true, speed = 4, bezier = "smooth" })

-- ── Fades ───────────────────────────────────────────────────
hl.animation({ leaf = "fadeIn",     enabled = true, speed = 4, bezier = "emphasizedDecel" })
hl.animation({ leaf = "fadeOut",    enabled = true, speed = 3, bezier = "emphasizedAccel" })
hl.animation({ leaf = "fadeDim",    enabled = true, speed = 5, bezier = "smooth" })
hl.animation({ leaf = "fadeShadow", enabled = true, speed = 5, bezier = "smooth" })

-- ── Borders ─────────────────────────────────────────────────
hl.animation({ leaf = "border",      enabled = true, speed = 5,  bezier = "standard" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 40, bezier = "smooth", style = "loop" })

-- ── Workspaces ──────────────────────────────────────────────
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "snappy", style = "slidefade 20%" })

-- ── Special Workspaces ──────────────────────────────────────
-- Vertical slide with fade — the signature Caelestia transition
hl.animation({
    leaf    = "specialWorkspace",
    enabled = true,
    speed   = 4,
    bezier  = "specialWorkSwitch",
    style   = "slidefadevert 15%",
})
