# JarvOS brand

The mark is a `J` cut out of a rounded tile — the negative space is the letter.
It is monochrome by construction: it inherits `currentColor`, so it takes the
Material You accent on the desktop, the foreground colour on the site, and a
single ink on the console.

| File | Use |
|---|---|
| `jarvos-mark.svg` | primary mark (tile). App icon, favicon, SDDM, GRUB, Setup app |
| `jarvos-mark-mono.svg` | the hook alone, for surfaces that already provide a ground |
| `jarvos-lockup.svg` | mark + wordmark, horizontal. Site header, README, docs |
| `jarvos-mark.txt` | Unicode-block rendering for the installer TUI, motd and fastfetch |
| `png/` | rasters at 512/256/128/64/32/16 |

Rules: keep the tile's corner radius proportional (120/512); never re-letter the
`J` with a font; never add a gradient, outline or shadow; below 32 px use the
tile, not the hook. Minimum clear space is one quarter of the tile's width.
