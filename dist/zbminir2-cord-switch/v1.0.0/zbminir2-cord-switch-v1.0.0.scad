// CHANGELOG (newest first; parsed by scripts/build-stl.mjs – format: "// <version> - <summary>", indented lines continue the entry)
// 1.0.0 - Initial versioned release: rectangular two-part enclosure; "base" is the lower half and "lid" the upper half
//

// ==========================================================
// FULLY PARAMETRIC ENCLOSURE – PARTS LAID OUT SIDE BY SIDE (Z=0)
// ==========================================================

/* [Exact inner dimensions] */
inner_x = 75;       // Inner length
inner_y = 40;       // Inner width
inner_z = 19;       // Total inner height (between floor and ceiling)

/* [Construction] */
wall = 2.5;          // Wall thickness (all sides)
radius_3d = 4.0;     // 3D rounding of all edges (pebble shape)

/* [Fasteners (M3)] */
screw_hole_thread = 2.8; // Hole for a self-tapping M3 screw
screw_hole_clear = 3.2;  // M3 clearance hole
head_d = 6.0;            // M3 screw head diameter
head_depth = 2.0;        // Screw head recess depth
post_d = 7.5;            // Corner screw post diameter

/* [Cable passage] */
wire_r = 3.0;         // Cable RADIUS (passage on the short side, in the parting plane)

/* [Cable clamp (2x M3)] */
clamp_x = post_d - 0.2 - wall/2; // Clamp block/plate length along the cable (front flush with the corner posts)
clamp_t = 5;          // Clamp plate thickness (printed plate)
screw_offset = 4;     // Distance of the screw axis from the cable edge (in Y)
squeeze = 0.3;        // How much smaller the clamp groove is than the cable (clamping force)
screw_depth = 8;      // Threaded hole depth in the block (M3x12 = 5 plate + 8 block - margin)
clamp_w = 2 * (wire_r + screw_offset + 3.2); // Block/clamp width

/* [ZBMINIR module] */
relay_x = 39.5;       // Module size along the cable (X) before rotation
relay_y = 33;         // Module size across (Y) before rotation
relay_z = 16.8;       // Module height
relay_r = 4;          // Module vertical edge radius
relay_clearance = 0.3;// Printing clearance on each side of the module
frame_gap = 2;        // Gap between the frame and the clamp block (room to bend cables under the module)
frame_wall = 1.2;     // Frame wall thickness
frame_bottom_h = 6;   // Bottom frame height above the floor (module sits on the ribs)
frame_top_h = 3;      // Top frame depth below the ceiling
frame_corner = 6;     // Length of retained corners on the end faces (wire window in between)
rib_h = 2;            // Rib height under the module (cable passage)
rib_w = 2;            // Rib width
rib_count = 2;        // Number of ribs (evenly across the width, min. 2 = edge ribs)

/* [Indicator LED (hole in the lid above the module)] */
led_d = 1.5;          // Hole diameter
// View of the lid from INSIDE with the module at the top (cable-input side = top):
//   "top side" of the module = edge next to the input cable (min X), "left edge" = edge with max Y.
led_from_top = 15;    // Distance from the top side of the module (from the input cable, along X)
led_from_left = 4;    // Distance from the left edge of the module (along Y, from the max-Y edge)
reset_d = 1.0;        // Reset button hole diameter
reset_from_top = 7;   // Distance from the top side of the module (from the input cable, along X)
reset_from_left = 4;  // Distance from the left edge of the module (along Y, from the max-Y edge)

/* [Switch] */
switch_d = 19.4;      // Switch hole diameter
switch_from_zbminir2 = 15;   // Distance of the switch centre from the ZBMINIR module (along X)

/* [Lock tolerance] */
lock_clearance = 0.2; // Clearance for smooth closing
$fn = 60;             // Circle / arc facet count


// Derived dimensions
outer_x = inner_x + 2 * wall;
outer_y = inner_y + 2 * wall;
outer_z = inner_z + 2 * wall;
outer_half_z = outer_z / 2;

// ZBMINIR module: frame cavity and position (the frame starts frame_gap behind the clamp block at x = 0)
// The module is rotated by 90°: the longer side (relay_x) lies along Y, the shorter (relay_y) along X.
// The Y size is clipped to inner_y (the longer module side is almost as wide as the enclosure).
relay_ox = relay_y + 2 * relay_clearance;
relay_oy = min(relay_x + 2 * relay_clearance, inner_y);
frame_x0 = wall + clamp_x + frame_gap;   // outer edge of the frame
// Actual module edges (without clearance)
relay_xmax = frame_x0 + frame_wall + relay_clearance + relay_y;   // right side (max X)
relay_ymax = outer_y/2 + relay_x/2;                               // top edge (max Y)
relay_xmin = frame_x0 + frame_wall + relay_clearance;             // left side (min X, next to the input cable)
relay_ymin = outer_y/2 - relay_x/2;                               // bottom edge (min Y)
led_x = relay_xmin + led_from_top;
led_y = relay_ymax - led_from_left;

reset_x = relay_xmin + reset_from_top;
reset_y = relay_ymax - reset_from_left;
switch_x = relay_xmax + switch_from_zbminir2;   // switch centre: behind the module (away from the input cable)
assert(switch_x + switch_d/2 <= outer_x - wall, "The switch does not fit into the enclosure length");
assert(relay_x <= inner_y, "ZBMINIR does not fit the width (inner_y)");
assert(inner_z - rib_h - relay_z >= 0, "ZBMINIR does not fit the height (inner_z, rib_h, relay_z)");


// --- PARTS AND EXPORT (read by the build script: npm run build) ---

/* [Hidden] */
// List of parts of this model – each item = one STL file. Every name needs a branch in render_part().
parts = ["base", "lid", "clamp"];
// Which part to render: "all" = all side by side (preview), otherwise a name from `parts` (set by the build script via -D).
part = "all";
// Version of this model: bump it on every release (npm run release); the changelog above documents it
model_version = "1.0.0";

// One part in its print position (on Z=0, outer face down)
module render_part(p) {
    if (p == "base")
        // lower half (base), the outer face is already on Z=0
        base();
    else if (p == "lid")
        // upper half (lid) flipped outer face down; y = 0 … outer_y
        rotate([180, 0, 0])
            translate([0, -outer_y, -outer_z])
                lid();
    else if (p == "clamp")
        // cable clamp, groove down (print 2x)
        translate([0, clamp_w/2, 0])
            clamp();
    else
        assert(false, str("Unknown part: ", p));
}

if (part == "all") {
    // Preview: all parts side by side
    render_part("base");
    translate([0, outer_y + 15, 0]) render_part("lid");
    for (i = [0, 1])
        translate([i * (clamp_x + 10), -clamp_w - 10, 0])
            render_part("clamp");
} else {
    render_part(part);
}


// --- MAIN GEOMETRY GENERATORS ---

// Basic 2D rounded-rectangle outline
module profile_2d(x, y, r) {
    hull()
        for (px = [r, x - r], py = [r, y - r])
            translate([px, py]) circle(r=r);
}

// Fully rounded 3D block ("pebble")
module rounded_block(x, y, z, r) {
    hull()
        for (px = [r, x - r], py = [r, y - r], pz = [r, z - r])
            translate([px, py, pz]) sphere(r=r);
}

// Places children in the four inner corners (screw posts)
module all_corners() {
    offset_x = wall + post_d/2 - 0.2;
    offset_y = wall + post_d/2 - 0.2;

    translate([offset_x - wall/2, offset_y - wall/2, 0]) children();
    translate([outer_x - offset_x + wall/2, offset_y - wall/2, 0]) children();
    translate([offset_x - wall/2, outer_y - offset_y + wall/2, 0]) children();
    translate([outer_x - offset_x + wall/2, outer_y - offset_y + wall/2, 0]) children();
}


// Cable passage: in the middle of the short side (x = 0), in the parting plane -> a half circle in each half
module cable_passage() {
    translate([0, outer_y/2, outer_half_z])
        rotate([0, 90, 0])
            cylinder(d=wire_r*2, h=outer_x);
}


// Repeats children() on both short sides (the second one is mirrored about the middle in X)
module at_both_ends() {
    children();
    translate([outer_x, 0, 0]) mirror([1, 0, 0]) children();
}

// Positions of the clamp screw axes relative to the cable axis (in Y)
module clamp_screws() {
    for (s = [-1, 1])
        translate([wall + clamp_x/2, outer_y/2 + s * (wire_r + screw_offset), outer_half_z])
            children();
}

// Solid block in base() under the cable (cable_passage() cuts the groove into it)
module clamp_block() {
    at_both_ends()
        translate([wall - 0.5, outer_y/2 - clamp_w/2, wall - 0.5])
            cube([clamp_x + 0.5, clamp_w, outer_half_z - wall + 0.5]);
}

// Threaded holes (M3 into plastic) in the block
module clamp_holes() {
    at_both_ends()
        clamp_screws()
            translate([0, 0, -screw_depth])
                cylinder(d=screw_hole_thread, h=screw_depth + 1);
}

// Separate clamp plate (printed groove down); in the assembly it sits on the block in the parting plane
module clamp() {
    l = clamp_x - 0.2;
    difference() {
        translate([0, -clamp_w/2, 0])
            cube([l, clamp_w, clamp_t]);
        // Cable groove (slightly smaller => clamps)
        translate([-1, 0, 0]) rotate([0, 90, 0])
            cylinder(r=wire_r - squeeze, h=l + 2);
        // Through holes and head recesses
        for (s = [-1, 1])
            translate([clamp_x/2 - 0.2, s * (wire_r + screw_offset), 0]) {
                translate([0, 0, -1]) cylinder(d=screw_hole_clear, h=clamp_t + 2);
                translate([0, 0, clamp_t - head_depth])
                    cylinder(d=min(head_d, l - 0.4), h=head_depth + 1);
            }
    }
}


// Frame for ZBMINIR (stands on z = 0, height v). The end walls have a wire window in the middle.
module relay_frame(v) {
    ox = relay_ox + 2 * frame_wall;
    oy = relay_oy + 2 * frame_wall;
    difference() {
        // Outer outline (rounded concentrically with the cavity)
        translate([frame_x0, outer_y/2 - oy/2, 0])
            linear_extrude(height = v)
                profile_2d(ox, oy, relay_r + frame_wall);
        // Module cavity with rounded vertical edges
        translate([frame_x0 + frame_wall, outer_y/2 - relay_oy/2, -1])
            linear_extrude(height = v + 2)
                profile_2d(relay_ox, relay_oy, relay_r);
        // Windows in the end walls (only corners of length frame_corner remain)
        translate([frame_x0 - 1, outer_y/2 - (relay_oy - 2*frame_corner)/2, -1])
            cube([ox + 2, relay_oy - 2*frame_corner, v + 2]);
    }
}

// Ribs under the module (along X) – cables run between them
module relay_ribs() {
    for (i = [0 : rib_count - 1])
        translate([frame_x0 + frame_wall,
                   outer_y/2 - relay_oy/2 + i * (relay_oy - rib_w) / (rib_count - 1),
                   wall - 0.5])
            cube([relay_ox, rib_w, rib_h + 0.5]);
}


// --- MODULE: LOWER HALF ---
module base() {
    lock_h = 1.5;

    difference() {
        union() {
            // Lower shell
            difference() {
                intersection() {
                    rounded_block(outer_x, outer_y, outer_z, radius_3d);
                    cube([outer_x, outer_y, outer_half_z]);
                }
                translate([wall, wall, wall])
                    cube([inner_x, inner_y, outer_half_z + 1]);
            }

            // Protruding perimeter lock tongue
            translate([0, 0, outer_half_z])
                linear_extrude(height = lock_h)
                    difference() {
                        offset(delta = -wall/2 - lock_clearance/2) profile_2d(outer_x, outer_y, radius_3d);
                        offset(delta = -wall) profile_2d(outer_x, outer_y, radius_3d);
                    }

            // Corner posts
            intersection() {
                translate([wall, wall, wall]) cube([inner_x, inner_y, outer_half_z]);
                all_corners() cylinder(d=post_d, h=outer_half_z + lock_h);
            }

            // Cable clamp blocks
            clamp_block();

            // Bottom frame and ribs for ZBMINIR
            translate([0, 0, wall - 0.5]) relay_frame(frame_bottom_h + 0.5);
            relay_ribs();
        }

        clamp_holes();

        union() {
            cable_passage();
            translate([wall/2, outer_y/2-wire_r, outer_half_z+wire_r*2])
                rotate([0, 90, 0])
                    cube([wire_r*2, wire_r*2, outer_x-wall]);
        }

        // Through holes for screws from below + head recesses in the floor
        all_corners() {
            translate([0, 0, -1])
                cylinder(d=screw_hole_clear, h=outer_half_z + lock_h + 2);
            translate([0, 0, -1])
                cylinder(d=head_d, h=head_depth + 1);
        }
    }
}


// --- MODULE: UPPER HALF ---
module lid() {
    lock_h = 1.7;
    base_tongue_h = 1.5; // height of the tongue/posts in base() – the lid posts rest on them

    difference() {
        union() {
            // Upper shell
            difference() {
                intersection() {
                    rounded_block(outer_x, outer_y, outer_z, radius_3d);
                    translate([0, 0, outer_half_z]) cube([outer_x, outer_y, outer_z]);
                }
                // Inner cavity
                translate([wall, wall, outer_half_z - 1])
                    cube([inner_x, inner_y, (inner_z/2) + 1]);
                // Lock groove
                translate([0, 0, outer_half_z - 0.1])
                    linear_extrude(height = lock_h)
                        difference() {
                            offset(delta = -wall/2 + lock_clearance/2) profile_2d(outer_x, outer_y, radius_3d);
                            offset(delta = -wall - 1) profile_2d(outer_x, outer_y, radius_3d);
                        }
            }

            // Corner posts
            intersection() {
                translate([wall, wall, outer_half_z]) cube([inner_x, inner_y, outer_z]);
                all_corners()
                    translate([0, 0, outer_half_z + base_tongue_h])
                    cylinder(d=post_d, h=outer_half_z - base_tongue_h - 1);
            }

            // Top frame for ZBMINIR (hangs from the ceiling)
            translate([0, 0, outer_z - wall - frame_top_h])
                relay_frame(frame_top_h + 0.5);
        }

        cable_passage();

        // Indicator LED hole through the ceiling
        translate([led_x, led_y, outer_z - wall - 1])
            cylinder(d=led_d, h=wall + 2);

        // Reset button hole through the ceiling
        translate([reset_x, reset_y, outer_z - wall - 1])
            cylinder(d=reset_d, h=wall + 2);

        // Round hole for the switch/button through the ceiling (centre switch_from_zbminir2 behind the module)
        translate([switch_x, outer_y/2, outer_z - wall - 1])
            cylinder(d=switch_d, h=wall + 2);

        // Blind threaded holes for screws (must not break through the ceiling)
        all_corners()
            translate([0, 0, outer_half_z - 1])
                cylinder(d=screw_hole_thread, h=outer_z - 1.5 - (outer_half_z - 1));
    }
}
