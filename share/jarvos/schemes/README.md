# Palette data

`jarvos/default/dark.json` preserves the existing JarvOS palette.
The other colour tables are retained from Caelestia CLI 1.1.0's distributed
scheme data, under the project's GPL-3.0-only license. Their names preserve
upstream theme attribution. No Caelestia executable or Python module is used.

JarvOS owns palette selection, persistence and wallpaper integration in
`lib/desktop.py`. Dynamic Material colours use the pre-existing JarvOS
`generate_colors_material.py` and the independent materialyoucolor library.
