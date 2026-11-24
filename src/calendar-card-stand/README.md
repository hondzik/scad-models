# calendar-card-stand

Parametric stand for a pack of cards (e.g. a card calendar of 148 × 105 mm cards, 13 mm thick): a tray that holds the pack at its bottom edge and a separate prop that tilts it to a chosen angle. An all-in-one variant with both parts fused together is included.

## Parts

| Part | Description | Print |
|---|---|---|
| `holder` | The tray for the card pack: floor, thin front wall with a small lock lip, open at the top and on both sides. Grooves in its back and bottom edge take the tongues of the prop | back face down |
| `prop` | Two triangular ribs joined by a base plate with a tail. The holder leans on the ramp of the ribs, a stop at the bottom keeps it from sliding down | standing on the base plate |
| `all-in-one` | `holder` and `prop` fused into one solid in the assembled pose (no grooves, no clearance) | standing on the base plate, supports needed under the front wall of the holder |

Previews of every part are generated into `dist/calendar-card-stand/v<version>/images/` and shown in the main [README](../../README.md).

## Assembly

1. Print `holder` and `prop` (or just `all-in-one`).
2. Put the `holder` on the ramp of the `prop`: the two tongues of the ribs go into the grooves in the back of the holder and into its bottom edge (1 mm deep, 0.2 mm clearance), so the holder cannot slide sideways or down.
3. Insert the card pack from the top.

The tilt is given by `stand_angle` – the angle of the card plane from the table (90° = upright, smaller = more leaning back, default 60°). The prop is cut off at `prop_cut_height` (default 50 mm above the table); the upper part of the holder is then supported only by the cards and the ramp below it.

## Key parameters

- `card_width`, `card_height`, `card_pack_thickness`, `card_corner_radius` – size of the cards and of the pack.
- `stand_clearance`, `wall_thickness`, `thin_wall`, `lock` – clearance around the cards, floor and front wall thickness, lock lip.
- `stand_angle` – tilt of the stand (see above).
- `prop_cut_height` – height of the prop above the table (`0` = the ramp reaches the top of the holder).
- `prop_rib_width`, `prop_rib_inset` – width of the two ribs and their distance from the ends of the holder.
- `prop_base_thickness`, `prop_base_tail` – base plate thickness and length of the tail behind the prop (stability); `prop_tail_fillet` rounds the inner corners between the tail and the plate.
- `prop_stop_height`, `prop_toe` – the stop at the bottom of the ramp.
- `prop_tongue_depth`, `prop_tongue_width`, `prop_fit_clearance` – the tongues that sink into the holder and the room of the grooves around them.

## Presets

`calendar-card-stand.json` has two presets that decide what is built; the files are named `calendar-card-stand-<preset>-<part>.stl`:

| Preset | Builds |
|---|---|
| `2-part` | `holder` and `prop` as separate parts |
| `all-in-one` | only `all-in-one` (both fused into one solid) |

The preset carries a `parts` list (see `scripts/build-stl.mjs`), so only the listed parts are built for it. Run `npm run build -- calendar-card-stand` (all presets) or `npm run build -- calendar-card-stand --preset="2-part"`.

## Notes

- Preview modes: the default (`part = "all"`) shows every part side by side, `part = "assembly"` shows the holder (orange) tilted on the prop.
- Changing `stand_angle` changes the depth of the prop (a lower angle makes it deeper). Check that the tail is long enough for a stable stand.
- The changelog is in the header of [`calendar-card-stand.scad`](calendar-card-stand.scad).
