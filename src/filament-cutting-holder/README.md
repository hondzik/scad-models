# filament-cutting-holder

Parametric block with a filament channel for cutting filament at defined angles: a 90° cutter slot at one end, angled slots (by default 60° and 45°) at the other end, chamfered edges and magnet holes in the bottom face.

## Parts

| Part | Description | Print |
|---|---|---|
| `holder` | The whole block | magnet holes up |

## Parameters

| Parameter | Description |
|---|---|
| `width`, `height`, `length` | Outer dimensions of the block |
| `corner_size` | Chamfer of all edges |
| `filament_width` | Diameter of the filament channel |
| `cutter_thickness` | Thickness of the cutter (slot width) |
| `slot_chamfer` | Lead-in chamfer at the slot openings |
| `angles` | Angles of the extra slots relative to the 90° slot (90 = identical to it); the first one is nearest to the far end |
| `angled_slot_offset`, `angled_slot_gap` | Distance of the first angled slot from the end and the gap between angled slots |
| `magnet_count`, `magnet_diameter`, `magnet_depth`, `magnet_clearance` | Magnet holes, evenly spread along the length (1 = centered, 2 = thirds, ...) |

Neighbouring angled slots can overlap near the edge of the block when the gap is small; increase `angled_slot_gap` if that is a problem.
