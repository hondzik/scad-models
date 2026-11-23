# name-letter

Big capital first letter of a name with the whole name inlaid across it. Two parts: `letter` (with a pocket) and `name` (the inlay to glue in); print them in two colours.

## Presets

Every parameter set in `name-letter.json` (except `design default values`) is built as its own variant, e.g. `name-letter-anna-letter.stl`. Add a set in the OpenSCAD Customizer (or edit the JSON) and run `npm run build -- name-letter`; only the new or changed presets are built. `npm run build -- name-letter --preset="Anna"` rebuilds one.

## Colours

`first_letter_color` and `name_color` colour the assembled preview (`part = "all"`, `images/*-preview.png`). STL carries no colour – set the colours per part in the slicer.

## Big letter and stand

The big letter is drawn without diacritics (`Č` → `C`, `Ř` → `R`; table `base_map` in the `.scad`), while the inlay keeps the full name.

`stand` = `auto` / `yes` / `no` adds a thin base plate (`stand_width`, `stand_thickness`) under the middle of the big letter, so letters with a round or pointed bottom (`C G J O Q S U V`) can stand upright. `auto` decides from that list, `yes` / `no` override it (use `yes` for Greek or Cyrillic).
