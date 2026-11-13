// CHANGELOG (newest first; parsed by scripts/build-stl.mjs – format: "// <version> - <summary>", indented lines continue the entry)
// 1.0.0 - Initial versioned release: filament cutting holder with 90° and angled cutter slots, chamfered edges and magnet holes
//

/* [ Dimensions ] */
width = 15;
height = 15;
length = 50;

/* [ Corners ] */
corner_size = 1;

/* [ Filament width ] */
filament_width = 2.2;

/* [ Cutter thickness ] */
cutter_thickness = 1;

/* [ Cutter slot lead-in ] */
// size of the 45° lead-in chamfer at the slot opening (0 = none)
slot_chamfer = 1;

/* [ Angles ] */
// slot angles relative to the 90-degree slot (90 = identical to it), first one is nearest to the far end
angles = [45, 30];
// distance of the first angled slot from the end of the block
angled_slot_offset = 10;
// gap between neighbouring angled slots (measured along the filament axis)
angled_slot_gap = 10;

/* [ Magnets ] */
// number of magnet holes in the bottom face (1 = centered, 2 = thirds, ...)
magnet_count = 2;
magnet_diameter = 4;
// depth of the holes
magnet_depth = 2;
// extra diameter for fit
magnet_clearance = 0.1;

/* [ Circle resolution ] */
$fn = 50;

/* [Hidden] */
// List of parts of this model – each item = one STL file. Every name needs a branch in render_part().
parts = ["holder"];
// Which part to render: "all" = preview, otherwise a name from `parts` (set by the build script via -D).
part = "all";
model_version = "1.0.0";

// rectangle w x h with all four corners chamfered by c
module chamfered_rect(w, h, c) {
    polygon(points = [
        [c, 0], [w - c, 0], [w, c], [w, h - c],
        [w - c, h], [c, h], [0, h - c], [0, c]
    ]);
}

// width of angled slot i measured along the filament axis
function angled_slot_w(i) = cutter_thickness / sin(angles[i]);

// z (along the length) of the lower-z edge of angled slot i on the filament axis.
// The first slot ends angled_slot_offset before the far end, the others follow
// towards the middle of the block with angled_slot_gap between them.
function angled_slot_z(i) = i == 0
    ? length - angled_slot_offset - angled_slot_w(0)
    : angled_slot_z(i - 1) - angled_slot_gap - angled_slot_w(i);

// straight vertical cutter slot centered on the origin (thickness along z, running along x,
// depth along y from the top face) with lead-in chamfers
module slot_cut(len) {
    t = cutter_thickness;
    depth = height/2 + filament_width;
    c = slot_chamfer;
    e = 0.01;
    rotate([90, 0, 90]) linear_extrude(height = len, center = true) {
        polygon(points = [
            [-e,    -t/2 - c - e],
            [c,     -t/2],
            [depth, -t/2],
            [depth,  t/2],
            [c,      t/2],
            [-e,     t/2 + c + e]
        ]);
    }
}

// the 90-degree slot turned around the vertical axis so that it meets the filament axis at
// angle a (a = 90 gives exactly the 90-degree slot); zs = z of its lower-z edge on the
// filament axis. The slot leans towards z = length with growing x.
module angled_slot(a, zs) {
    w = cutter_thickness / sin(a);
    translate([width/2, 0, zs + w/2]) rotate([0, a - 90, 0]) slot_cut(width / sin(a) + 2);
}

// Print orientation: flipped so that the magnet holes face up, flat on Z=0
module holder() {
    translate([0, -height, height]) rotate([90, 0, 0]) difference() {
        // basic shape of the holder: long edges chamfered by the profile itself,
        // the edges around both end faces by intersecting with two more chamfered prisms
        intersection() {
            linear_extrude(height = length) {
                difference() {
                    // square with chamfered corners
                    chamfered_rect(width, height, corner_size);
                    // filament hole centered in the square
                    translate([width/2, height/2]) circle(d = filament_width);
                }
            };
            // end edges running along x
            rotate([90, 0, 90]) linear_extrude(height = width) chamfered_rect(height, length, corner_size);
            // end edges running along y
            translate([0, height, 0]) rotate([90, 0, 0]) linear_extrude(height = height) chamfered_rect(width, length, corner_size);
        }
        // filament cylinders at both ends
        translate([width/2, height/2, 0]) {
            cylinder(h = filament_width*2, r1 = filament_width, r2 = filament_width/2);
        }
        translate([width/2, height/2, length - filament_width*2]) {
            cylinder(h = filament_width*2, r2 = filament_width, r1 = filament_width/2);
        }

        // 90-degree cutter slot
        angled_slot(90, 8);

        // angled cutter slots on the same side, near the far end, in the order of `angles`
        for (i = [0 : len(angles) - 1]) {
            angled_slot(angles[i], angled_slot_z(i));
        }

        // magnet holes in the bottom face (local y = height), evenly spread along the length
        if (magnet_count > 0) {
            for (i = [1 : magnet_count]) {
                translate([width/2, height - magnet_depth, length * i / (magnet_count + 1)])
                    rotate([-90, 0, 0])
                        cylinder(d = magnet_diameter + magnet_clearance, h = magnet_depth + 0.01);
            }
        }
    }
}

module render_part(p) {
    if (p == "holder") holder();
    else assert(false, str("Unknown part: ", p));
}

if (part == "all") {
    // Preview: all parts
    for (p = parts) render_part(p);
} else {
    render_part(part);
}
