# zbminir2-cord-floor-switch

Round two-part enclosure for a Sonoff ZBMINIR2 module with a cable passage and clamp on both ends, plus a floor-switch button with a spring-loaded cap.

## ⚠️ Safety and disclaimer

This enclosure holds a **mains-voltage** device. Read this before building it.

- **Use at your own risk.** The models are provided as-is, without any warranty. The author accepts no responsibility for damage, injury or fire. This is a printed mechanical enclosure, **not a certified electrical product**; the wiring itself must be done only by a qualified person and according to the local regulations.
- **Polarity (switching the phase, not the neutral).** The ZBMINIR2 should interrupt the **phase (live)** conductor, not the neutral. To keep the polarity correct, use a plug that can only be inserted one way, e.g. the **SHUKUO E** type plug (if it conforms to your local standards), and always verify with a tester that the switched conductor is really the phase.
- **Always unplug the appliance from the socket** before changing bulbs or touching anything connected to the cord, even when the switch is off — a switch that is "off" may still leave a conductor live.
- **Use a suitable filament.** For a mains enclosure a flame-retardant material is recommended, e.g. a **PETG V0 certified** filament (UL 94 V-0). The rating usually applies only to the tested thickness range, colours and print settings of the manufacturer's report, so check the datasheet and print with solid walls.

## Parts

| Part | Description | Print |
|---|---|---|
| `base` | Lower half: floor, screw posts, cable clamp blocks, bottom ZBMINIR frame with ribs, corner feet for the switch base | outer face down |
| `lid` | Upper half: top ZBMINIR frame, LED / reset / switch holes, guide sleeve around the switch hole | flipped, outer face down |
| `clamp` | Cable clamp plate (2 M3 screws) | groove down, **print 2×** |
| `cap` | Button cap with spring guide and a stop band | rounded top down, open side up |

Previews of every part are generated into `dist/zbminir2-cord-floor-switch/v<version>/images/` and shown in the main [README](../../README.md).

## Assembly

1. Insert the `cap` into the `lid` hole **from inside** (from below). The body passes through the hole freely, the thin band around the open end stops against the rim of the hole, so the cap can never fall out upwards. The spring pushes the cap against that stop.
2. Put the spring on the spring guide, place the switch base into the corner feet of `base` and close the halves.
3. Screws go from below through `base` into the blind threaded holes of `lid` (they never break through the ceiling).
4. Cables run through the passages on both ends, pressed by the `clamp` plates.

## Key parameters

- `inner_d`, `inner_z` – inner diameter and height. Extra height (above what the module needs) goes **under** the module: the ribs and the bottom frame grow with `inner_z`, the module always touches the lid ceiling (`module_top_gap = 0`).
- `relay_*`, `frame_*`, `rib_*` – ZBMINIR module size, clearance and frames.
- `led_*`, `reset_*` – indicator and reset holes, measured from the module edges.
- `switch_d`, `switch_from_zbminir2`, `switch_base_*`, `switch_foot_*`, `switch_guide_*` – the switch hole, its feet and guide sleeve.
- `cap_*`, `spring_*` – the button cap.

Top-level `assert`s guard the fit (switch inside the round cavity, module frame inside the cavity, module height). If every part suddenly fails to render after a parameter change, read the assert message.

## Notes

- Posts of the two halves are at `post_angle` from the cable axis; the clamp plate is clipped by the inner circle so it follows the round wall.
- The changelog is in the header of [`zbminir2-cord-floor-switch.scad`](zbminir2-cord-floor-switch.scad).
