# zbminir2-cord-switch

Rectangular two-part enclosure for a Sonoff ZBMINIR2 module with a cable passage and clamp on both short sides. Superseded by the round variant `zbminir2-cord-floor-switch`.

## ⚠️ Safety and disclaimer

This enclosure holds a **mains-voltage** device. Read this before building it.

- **Use at your own risk.** The models are provided as-is, without any warranty. The author accepts no responsibility for damage, injury or fire. This is a printed mechanical enclosure, **not a certified electrical product**; the wiring itself must be done only by a qualified person and according to the local regulations.
- **Polarity (switching the phase, not the neutral).** The ZBMINIR2 should interrupt the **phase (live)** conductor, not the neutral. To keep the polarity correct, use a plug that can only be inserted one way, e.g. the **SHUKUO E** type plug (if it conforms to your local standards), and always verify with a tester that the switched conductor is really the phase.
- **Always unplug the appliance from the socket** before changing bulbs or touching anything connected to the cord, even when the switch is off — a switch that is "off" may still leave a conductor live.
- **Use a suitable filament.** For a mains enclosure a flame-retardant material is recommended, e.g. a **PETG V0 certified** filament (UL 94 V-0). The rating usually applies only to the tested thickness range, colours and print settings of the manufacturer's report, so check the datasheet and print with solid walls.

## Parts

| Part | Description | Print |
|---|---|---|
| `base` | Lower half: floor, screw posts, cable clamp blocks, bottom ZBMINIR frame with ribs | outer face down |
| `lid` | Upper half with the LED, reset and switch holes and the top ZBMINIR frame | flipped, outer face down |
| `clamp` | Cable clamp plate (2 M3 screws) | groove down, **print 2×** |

Previews of every part are generated into `dist/zbminir2-cord-switch/v<version>/images/` and shown in the main [README](../../README.md).

## Notes

- The changelog is in the header of [`zbminir2-cord-switch.scad`](zbminir2-cord-switch.scad).
