// laskakit-wled-case - slim case for a LaskaKit ESP32 WLED controller board, redrawn natively from a downloaded mesh
//
// Based on the LaskaKit ESPwled slim case: https://github.com/LaskaKit/ESPwled/tree/main/3D/slimcase.3mf
// (the original mesh is redrawn here as a parametric OpenSCAD model; see that repository for the original design and its license)
//
// Two parts: `case` (open box with smooth walls, a free standing post, wall posts, openings in one long wall, a cable tunnel with a
// floor hole and ears for heat-set inserts) and `lid` (plate with a rebate that fits into the box and the tunnel and pads over the
// ears with countersunk M3 holes). Print both with the outer face on the bed. The lid is turned over onto the box and screwed
// to the heat-set inserts in the ears.
// `part = "all"` shows both parts side by side. Origin of both parts is the outer corner (X along the width, Y along the length).
// Only the wall thickness is a parameter (it applies to the side walls, the floor and the lid plate); the inner dimensions of the box
// (23.6 x 51.72 x 11 mm) and everything inside it stay fixed, so the outer size grows with the wall.
//
// CHANGELOG (newest first; parsed by scripts/build-stl.mjs - format: "// <version> - <summary>", indented lines continue the entry)
// 1.0.0 - first release: 12 mm high case with cable tunnel, M3 heat-set insert ears and USB-C recess, plus lid with countersunk M3 pads

/* [Walls] */
// thickness of all walls: side walls, floor and lid plate (the inner dimensions stay the same) [mm]
wall = 2.1; // [1.5 : 0.1 : 4]
nut_type = "M3"; // ["M2", "M2.5", "M3", "M4", "M5", "M6"]

/* [Tunnel */
tunnel_width = 16; // width of the cable tunnel [mm]
tunnel_length = 63.28; // length of the cable tunnel [mm] (55 + the 8.28 mm cut from the box, see `trim`)
tunnel_hole_width = 6; // width of the hole for the cable tunnel [mm]

/* [Hidden] */
$fn = 48;
parts = ["case", "lid"];
part = "all";
model_version = "1.0.0";
preview_part = "assembled"; // part rendered for the assembled preview image (see scripts/build-stl.mjs)
preview_camera = [55, 0, -125]; // looks at the left wall with the USB-C opening

assert(wall >= 1.5, "wall must be at least 1.5 mm");

// fixed inner dimensions of the box [width (X), length (Y), height above the floor (Z)]
// the box is shorter by `trim` than the original 60 mm: its tunnel end is as far behind the PCB supports as the other end
trim = 8.28; // = 13.5 (supports - tunnel end) - (60 - 54.78) (supports - far end)
inner = [23.6, 60 - trim, 11]; // 11 + the floor (wall 1.5) = 12.5 mm total height of the box

// everything below is given in inner coordinates (0,0 = inner corner above the floor); the modules shift it by the wall
post_b_in = [6.64, 35.62 - trim]; // free standing post
wall_posts_in = [[0.3, 13.5 - trim], [0.3, 54.78 - trim], [23.3, 13.5 - trim], [23.3, 54.78 - trim]];

// https://www.prusa3d.com/content/wysiwyg/fotky/cnc-k/sizes_chart.png
// nut dimensions: [name, hole diameter, minimal wall thickness]
// Minimal height is the height of the nut + 1 mm
NUTS = [
    ["M2", 3.2, 1.3],
    ["M2.5", 4.0, 1.6],
    ["M3", 4.45, 2], // original 1.6
    ["M4", 5.6, 2.1],
    ["M5", 6.4, 2.6],
    ["M6", 8.0, 3.3]
];

// Modules and functions below use no global variables except NUTS: everything is passed as parameters.

function nut(type) =
    let (i = search([type], NUTS)[0])
    assert(i != [], str("Unknown nut type: ", type))
    NUTS[i];

function nutHoleDiameter(type) =
    let (n = nut(type))
    n[1] + 2 * n[2];

// inner coordinates -> outer coordinates
function at(p, wall) = [p[0] + wall, p[1] + wall];

module rrect_x(y0, y1, z0, z1, r, wall, floor_t, depth) {
    // rounded rectangle in the YZ plane (inner coordinates) cut into the left wall from the outer face, `depth` mm deep
    translate([-1, wall, floor_t]) rotate([90, 0, 90]) linear_extrude(depth + 1)
        hull() for (y = [y0 + r, y1 - r], z = [z0 + r, z1 - r]) translate([y, z]) circle(r);
}

module post(p, bottom, top, d) {
    eps = 0.01;
    translate([p[0], p[1], bottom - eps]) cylinder(d = d, h = top - bottom + eps);
}

module post_hole(p, bottom, top, d) {
    translate([p[0], p[1], bottom]) cylinder(d = d, h = top);
}

// 2D outline of an ear for a nut / heat-set insert: circle around the hole plus a rectangle towards the wall (it is at +Y)
module nutOutline(type) {
    outer_d = nutHoleDiameter(type);
    circle(d = outer_d);
    translate([0, outer_d / 4]) square([outer_d, outer_d / 2], center = true);
}

module nutHole(type, height) {
    linear_extrude(height) difference() {
        nutOutline(type);
        circle(d = nut(type)[1]);
    }
}

// positions of the ears: [x, y, rotation] - two at the far end of the box and two at the end of the tunnel (the ears overlap the wall by eps)
function ear_spots(nut_r, width, length, wall, tunnel_width, tunnel_length, eps = 0.01) = [
    // far end of the box (the ears next to the tunnel were removed)
    [-nut_r + eps, length - nut_r, -90],
    [nut_r + width - eps, length - nut_r, 90],
    // both sides of the tunnel, ear centres 20 mm from the end of the tunnel
    for (side = [-1, 1])
        [width / 2 + side * ((tunnel_width / 2 + wall) + nut_r - eps), -tunnel_length + 20, 90 * side]
];

// places the children at the ears
module at_ears(spots) {
    for (sp = spots) translate([sp[0], sp[1]]) rotate([0, 0, sp[2]]) children();
}

module case(wall, inner, post_b_in, wall_posts_in, nut_type, tunnel_width, tunnel_length, tunnel_hole_width, trim, lid_rim_h = 1, lid_gap = 0.1, post_d = 4.5, screw_hole_d = 1.9, recess_wall = 0.5, recess_h = 7, recess_r = 3.5) {
    eps = 0.01;
    floor_t = wall;
    width = inner[0] + 2 * wall;
    length = inner[1] + 2 * wall;
    height = inner[2] + floor_t;
    post_b = at(post_b_in, wall);
    wall_posts = [for (p = wall_posts_in) at(p, wall)];
    post_top = floor_t + 2.7;
    hole_z = max(0.4, floor_t - 0.8); // bottom of the screw holes in the posts
    nut_r = nutHoleDiameter(nut_type) / 2;
    difference() {
        union() {
            difference() {
                cube([width, length, height]);
                // cavity
                translate([wall, wall, floor_t]) cube([inner[0], inner[1], height]);
                // (cut here, before the ears are added, so the cutters do not nick the ears that stand next to the wall)
                // recess on the outer face of the left wall around the openings, leaving recess_wall of the wall (the rounded ends are
                // centred on the two round holes, the recess is centred on the USB-C opening)
                rrect_x(19.59 - trim - recess_r, 35.85 - trim + recess_r, 5.9 - recess_h / 2, 5.9 + recess_h / 2, recess_r, wall, floor_t, wall - recess_wall);
                // openings in the left long wall: slot (10 x 4.2) and two round holes
                rrect_x(22.75 - trim, 32.75 - trim, 3.8, 8.0, 1.25, wall, floor_t, wall + 1);
                for (y = [19.59 - trim, 35.85 - trim]) translate([-1, y + wall, floor_t + 5.3]) rotate([0, 90, 0]) cylinder(d = 3, h = wall + 2);
            }
            // posts (clipped by the outer outline)
            intersection() {
                cube([width, length, height]);
                union() {
                    post(post_b, floor_t, post_top, post_d);
                    for (p = wall_posts) post(p, floor_t, post_top, post_d);
                }
            }
            // straight cable tunnel attached to the near short wall: floor, two side walls and an end wall of the same height as the box
            translate([(width - tunnel_width) / 2 - wall, -tunnel_length, 0]) difference() {
                cube([tunnel_width + 2 * wall, tunnel_length + wall, height]);
                translate([wall, wall, floor_t]) cube([tunnel_width, tunnel_length + 1, height]);
            }
            // ears for the heat-set inserts
            at_ears(ear_spots(nut_r, width, length, wall, tunnel_width, tunnel_length)) nutHole(nut_type, height);
        }
        post_hole(post_b, hole_z, post_top, screw_hole_d);
        for (p = wall_posts) post_hole(p, hole_z, post_top, screw_hole_d);
        // cable opening in the near short wall: centred, tunnel_width wide, from the floor up to the top
        translate([(width - tunnel_width) / 2, -1, floor_t]) cube([tunnel_width, wall + 2, height]);
        // rectangular hole through the tunnel floor (full inner width) right in front of the end wall
        translate([(width - tunnel_width) / 2, -tunnel_length + wall, -1]) cube([tunnel_width, tunnel_hole_width, floor_t + 2]);
    }
}

module lid(wall, inner, nut_type, tunnel_width, tunnel_length, lid_gap = 0.1, lid_rim_h = 1, lid_rim_w = 1.3, screw_d = 3.4, screw_head_d = 6.2) {
    eps = 0.01;
    width = inner[0] + 2 * wall;
    length = inner[1] + 2 * wall;
    lid_t = wall + 0.2; // plate; the inside of the rim is 0.2 mm thinner (= wall)
    m = wall + lid_gap + lid_rim_w; // pocket inset
    tx = (width - tunnel_width) / 2; // X of the inner face of the tunnel wall
    nut_r = nutHoleDiameter(nut_type) / 2;
    spots = ear_spots(nut_r, width, length, wall, tunnel_width, tunnel_length);
    cone_h = (screw_head_d - screw_d) / 2; // 90 degree countersink
    assert(cone_h < lid_t, "the countersink is deeper than the lid plate");
    difference() {
        union() {
            difference() {
                union() {
                    cube([width, length, lid_t]);
                    // rim that fits into the box
                    translate([wall + lid_gap, wall + lid_gap, lid_t - eps])
                        cube([inner[0] - 2 * lid_gap, inner[1] - lid_gap, lid_rim_h + eps]);
                    // extension over the tunnel: plate and rim that fits between the tunnel walls
                    translate([tx - wall, -tunnel_length, 0]) cube([tunnel_width + 2 * wall, tunnel_length + 1, lid_t]);
                    translate([tx + lid_gap, -tunnel_length + wall + lid_gap, lid_t - eps])
                        cube([tunnel_width - 2 * lid_gap, tunnel_length + 1, lid_rim_h + eps]);
                }
                // shallow pocket inside the rim
                translate([m, m, wall]) cube([width - 2 * m, length - 2 * m, lid_rim_h + 2]);
                translate([tx + lid_gap + lid_rim_w, -tunnel_length + m, wall])
                    cube([tunnel_width - 2 * lid_gap - 2 * lid_rim_w, tunnel_length + 1, lid_rim_h + 2]);
            }
            // pads over the ears of the box (the box ears are as high as the box, so the lid lies directly on them)
            at_ears(spots) linear_extrude(lid_t) nutOutline(nut_type);
        }
        // M3 screw holes with countersink (cone) for the flat head, opening to the outer face
        at_ears(spots) {
            translate([0, 0, -1]) cylinder(d = screw_d, h = lid_t + 2);
            translate([0, 0, -eps]) cylinder(d1 = screw_head_d + 2 * eps, d2 = screw_d, h = cone_h + eps);
        }
    }
}

// The LaskaKit ESPwled board (preview only). _ref/ESPwled_v1.stl is the ESPwled_v1.step converted to STL (mm, PCB underside at Z = 1.8, the parts below it reach down to Z = 0,
// USB-C on the +Y edge, long axis along X). It is turned so that the USB-C faces the left wall and the PCB underside lies on the posts
// (the mounting hole is above the free standing post, the PCB corners are above the wall posts).
module board(wall, floor_t, trim) {
    translate([wall + 11.8, wall + 10.96 - trim, floor_t + 0.9]) rotate([0, 0, 90]) import("_ref/ESPwled_v1.stl");
}

// everything put together, coloured (preview only): the lid is turned over onto the box
module assembled(wall, inner, post_b_in, wall_posts_in, nut_type, tunnel_width, tunnel_length, tunnel_hole_width, trim) {
    width = inner[0] + 2 * wall;
    height = inner[2] + wall;
    lid_t = wall + 0.2;
    color("#e67e22") case(wall, inner, post_b_in, wall_posts_in, nut_type, tunnel_width, tunnel_length, tunnel_hole_width, trim);
    color("#1e8449") board(wall, wall, trim);
    color("#3498db", 0.5) translate([width, 0, height + lid_t]) rotate([0, 180, 0]) lid(wall, inner, nut_type, tunnel_width, tunnel_length);
}

module render_part(p) {
    if (p == "case") case(wall, inner, post_b_in, wall_posts_in, nut_type, tunnel_width, tunnel_length, tunnel_hole_width, trim);
    else if (p == "lid") lid(wall, inner, nut_type, tunnel_width, tunnel_length);
    else if (p == "assembled") assembled(wall, inner, post_b_in, wall_posts_in, nut_type, tunnel_width, tunnel_length, tunnel_hole_width, trim);
    else assert(false, str("unknown part: ", p));
}

if (part == "all") {
    render_part("case");
    translate([inner[0] + 2 * wall + 2 * nutHoleDiameter(nut_type) + 5, 0, 0]) render_part("lid"); // clear of the ears of the case
} else {
    render_part(part);
}
