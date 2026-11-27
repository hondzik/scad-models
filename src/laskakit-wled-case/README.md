# laskakit-wled-case

Slim case with a lid for the LaskaKit ESP32 WLED controller board, redrawn as a parametric OpenSCAD model. Based on the LaskaKit ESPwled slim case: <https://github.com/LaskaKit/ESPwled/tree/main/3D/slimcase.3mf>

## Parts

- `case` – open box with smooth walls, four screw posts on the walls, one free standing post, an opening (10 × 4.2 mm) and two round holes (Ø 3 mm) in one long wall, a cable tunnel with a floor hole and ears for heat-set inserts.
- `lid` – plate with a rebate rim that fits into the box, pads over the ears with countersunk M3 holes.

Both parts are printed with the outer face on the bed.

## Assembly

Turn the lid over onto the box: the lid is screwed to the heat-set inserts in the ears.

## Notes

- The model was redrawn from the original mesh; the volume of both parts differs from the original by less than 0.5 %. The original files are kept in `_ref/` for comparison only.

## Parameters

Only the wall thickness (`wall`, default 1.5 mm) is a parameter. It applies to the side walls, the floor and the lid plate. The inner dimensions of the box (23.6 × 51.72 × 11 mm) and the position of everything inside it (posts, openings, tunnel) stay fixed, so the outer size grows with the wall.
