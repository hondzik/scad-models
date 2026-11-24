// CHANGELOG (newest first; parsed by scripts/build-stl.mjs – format: "// <version> - <summary>", indented lines continue the entry)
// 1.0.1 - presets 2-part (holder + prop) and all-in-one, coloured preview of the assembled stand; fix: cube() in holder() called with wrong arguments (same geometry, no warning)
// 1.0.0 - Initial versioned release: card holder plus a separate prop that tilts it to stand_angle, the prop cut off at prop_cut_height, plus an all-in-one variant with both fused together
//

/* [ Card dimmensions ] */
card_width = 148;
card_height = 105;
card_corner_radius = 5;
card_pack_thickness = 13;

/* [ Stand dimensions ] */
wall_thickness = 3;
// angle of the card plane from the table (90 = upright, smaller = more leaning back)
stand_angle = 60;
stand_clearance = 0.5;

thin_wall = 2;
lock = 0.5;

/* [ Prop ] */
// width of each of the two ribs
prop_rib_width = 8;
// distance of the ribs from the ends of the holder
prop_rib_inset = card_corner_radius;
// thickness of the base plate joining the ribs
prop_base_thickness = 3;
// height of the stop the bottom edge of the holder rests against (measured from the ramp)
prop_stop_height = 6;
// how far the stop reaches below the bottom edge of the holder (along the ramp)
prop_toe = 3;
// height of the prop above the table (0 = the prop reaches up to the top of the holder)
prop_cut_height = 50;
// how deep the prop sinks into the holder: tongues on the ramp (sides) and on the stop (bottom edge)
prop_tongue_depth = 1;
// width of the tongue on each rib (centered on the rib)
prop_tongue_width = 4;
// extra room of the grooves in the holder around the tongues
prop_fit_clearance = 0.2;
// length of the tail of the base plate behind the back of the prop
prop_base_tail = 20;
// radius of the rounded inner corners between the tail and the base plate (0 = sharp)
prop_tail_fillet = 5;

$fn=50;

/* [Hidden] */
// List of parts of this model – each item = one STL file. Every name needs a branch in render_part().
parts = ["holder", "prop", "all-in-one"];
// Which part to render: "all" = all side by side (preview), "assembly" = holder tilted on the prop,
// otherwise a name from `parts` (set by the build script via -D).
part = "all";
preview_part = "assembly"; // part rendered for the assembled preview image (see scripts/build-stl.mjs)
preview_camera = [80, 0, 75]; // camera rotation (x, y, z) of the preview image (see scripts/build-stl.mjs)
preview_color_1 = "#e67e22"; // preview colours only (STL has no colour)
preview_color_2 = "#3498db";
model_version = "1.0.1";

// ---- derived values (definition order matters) ----
holder_width = card_width + stand_clearance;
holder_length = card_height + thin_wall + stand_clearance;
// x positions of the two ribs of the prop and offset of the tongue inside a rib
prop_rib_xs = [prop_rib_inset, holder_width - prop_rib_inset - prop_rib_width];
tongue_dx = (prop_rib_width - prop_tongue_width) / 2;
assert(prop_tongue_width <= prop_rib_width, "prop_tongue_width must not exceed prop_rib_width");
// height of the bottom edge of the holder above the table (the stop of the prop reaches down to the table)
ramp_lift = prop_toe * sin(stand_angle);
// length of the ramp = length of the holder along the card plane that is left after the cut
ramp_length = prop_cut_height > 0
    ? min(holder_length, (prop_cut_height - ramp_lift) / sin(stand_angle))
    : holder_length;
assert(ramp_length > prop_stop_height, "prop_cut_height is too low for the stop of the prop");

// Point on the plane of the holder's back face, in the side view of the prop (y = away from the viewer,
// z = up). s = distance from the bottom edge of the holder along the card plane, n = distance in
// front of the plane (towards the viewer). The ramp surface of the prop is n = 0, the bottom edge of the
// holder (s = 0) is lifted so that the stop reaches exactly down to the table.
function ramp_pt(s, n) = [
    s * cos(stand_angle) - n * sin(stand_angle),
    prop_toe * sin(stand_angle) + s * sin(stand_angle) + n * cos(stand_angle)
];

module rounded_rectangle(x, y, radius) {
    union() {
        translate([radius, 0, 0]) square([x-2*radius, y]);
        translate([0, radius, 0]) square([x, y-2*radius]);
        corners = [[radius, radius], [radius, y-radius], [x-radius, radius], [x-radius, y-radius]];
        for (corner = corners) {
            translate([corner[0], corner[1], 0]) circle(radius);
        }
    }
}

module rounded_block(x, y, z, radius) {
    linear_extrude(height = z)
        rounded_rectangle(x, y, radius);
}

// The card holder in its print orientation (back face on Z=0).
// grooves = false leaves the back face solid (used by the all-in-one part, where the tongues of the
// prop grow into the holder).
module holder(grooves = true) {
    difference() {
        // Base block with clearance and lock
        rounded_block(
            holder_width,
            card_height + thin_wall + stand_clearance,
            card_pack_thickness + wall_thickness + stand_clearance + lock,
            card_corner_radius
        );
        // Subtract the inner block for - space for cards
        translate([0,  thin_wall + stand_clearance, wall_thickness]) rounded_block(
            holder_width,
            card_height + 100,
            card_pack_thickness + stand_clearance,
            card_corner_radius
        );
        // Subtract the inner block - create lock
        translate([0,  thin_wall + stand_clearance+lock, wall_thickness+lock]) rounded_block(
            holder_width,
            card_height + 100,
            card_pack_thickness + stand_clearance,
            card_corner_radius
        );
        // remove small edges
        translate([0,  thin_wall + stand_clearance + card_corner_radius, wall_thickness]) cube([holder_width, 10, 10]);
        // L-shaped grooves for the tongues of the prop: along the back face and into the bottom edge
        if (grooves) for (x = prop_rib_xs) {
            translate([x + tongue_dx - prop_fit_clearance, -1, -1]) {
                // back face, open at the bottom edge, runs up the whole length
                cube([prop_tongue_width + 2 * prop_fit_clearance,
                      holder_length + 2,
                      1 + prop_tongue_depth + prop_fit_clearance]);
                // bottom edge (the stop of the prop)
                cube([prop_tongue_width + 2 * prop_fit_clearance,
                      1 + prop_tongue_depth + prop_fit_clearance,
                      1 + prop_stop_height + prop_fit_clearance]);
            }
        }
    }
}

// Side profile of one rib: a right triangle under the ramp (the holder lies on the hypotenuse) with a
// small stop at the bottom that keeps the holder from sliding down. Flat bottom on the table (z = 0).
module prop_profile() {
    top = ramp_pt(ramp_length, 0);
    toe = ramp_pt(-prop_toe, prop_stop_height);
    polygon(points = [
        top,
        [top[0], 0],
        [toe[0], 0],
        toe,
        ramp_pt(0, prop_stop_height),
        ramp_pt(0, 0)
    ]);
}

// Side profile of the L-shaped tongue that sinks into the holder: a strip on the ramp plus a strip on the
// face of the stop. It overlaps the rib by a hair so that the union is solid.
module prop_tongue_profile() {
    d = prop_tongue_depth;
    o = 0.05;
    // end of the strip on the ramp, so that its corner does not rise above the top of the prop
    s_end = ramp_length - d / tan(stand_angle);
    polygon(points = [
        ramp_pt(-o, -o),
        ramp_pt(s_end, -o),
        ramp_pt(s_end, d),
        ramp_pt(d, d),
        ramp_pt(d, prop_stop_height),
        ramp_pt(-o, prop_stop_height)
    ]);
}

// 2D fillet for a concave corner at the origin: the free area is x < 0, y > 0 (the tail side is x = 0,
// the back edge of the plate is y = 0). It overlaps the plate by a hair so that the union is solid.
module tail_fillet(f) {
    difference() {
        translate([-f, -0.01]) square([f, f + 0.01]);
        translate([-f, f]) circle(r = f);
    }
}

// The prop in its print orientation (standing on the table plane Z=0): two ribs joined by a base plate.
// Placed in the same X range as the holder, front of the stand towards -Y.
module prop() {
    toe_y = ramp_pt(-prop_toe, prop_stop_height)[0];
    back_y = ramp_pt(ramp_length, 0)[0];
    for (x = prop_rib_xs) {
        translate([x, 0, 0]) rotate([90, 0, 90]) linear_extrude(height = prop_rib_width) prop_profile();
        translate([x + tongue_dx, 0, 0]) rotate([90, 0, 90]) linear_extrude(height = prop_tongue_width) prop_tongue_profile();
    }
    // base plate, trimmed to the side profile so that it does not poke into the holder at its bottom edge
    union(){
        intersection() {
            translate([prop_rib_inset, toe_y, 0])
                cube([holder_width - 2 * prop_rib_inset, back_y - toe_y, prop_base_thickness]);
            translate([prop_rib_inset, 0, 0]) rotate([90, 0, 90])
                linear_extrude(height = holder_width - 2 * prop_rib_inset) prop_profile();
        }
        // tail behind the prop; centered in X on the holder (and so on the base plate). It starts
        // card_corner_radius inside the plate (so its rounded corners are hidden in it) and reaches
        // prop_base_tail behind the back of the prop.
        tail_w = holder_width / 2;
        tail_x0 = (holder_width - tail_w) / 2;
        translate([tail_x0, back_y - card_corner_radius, 0])
            rounded_block(tail_w, prop_base_tail + card_corner_radius, prop_base_thickness, card_corner_radius);
        // rounded inner corners between the tail and the back edge of the plate
        if (prop_tail_fillet > 0) {
            translate([tail_x0, back_y, 0]) linear_extrude(height = prop_base_thickness) tail_fillet(prop_tail_fillet);
            translate([tail_x0 + tail_w, back_y, 0]) mirror([1, 0, 0])
                linear_extrude(height = prop_base_thickness) tail_fillet(prop_tail_fillet);
        }
    }
}

// The holder tilted onto the ramp of the prop, as it stands on the table
module assembly() {
    color(preview_color_1) prop();
    // render(): the cavity of the holder has the same width as the holder, so its side faces are coplanar and the
    // preview would show them hatched; a rendered mesh does not
    // the translucent holder is drawn last (the preview would hide everything drawn after a translucent object)
    color(preview_color_2, 0.35) translate([0, 0, ramp_lift]) rotate([stand_angle, 0, 0]) render(convexity = 10) holder();
}

// Both parts fused into one solid in the assembled pose (the holder tilted on the prop, standing on the
// table plane Z=0). No grooves, no clearance: the tongues of the prop are part of the holder.
module all_in_one() {
    render(convexity = 10) union() {
        prop();
        translate([0, 0, ramp_lift]) rotate([stand_angle, 0, 0]) holder(grooves = false);
    }
}

module render_part(p) {
    if (p == "holder") holder();
    else if (p == "prop") prop();
    else if (p == "all-in-one") all_in_one();
    else assert(false, str("Unknown part: ", p));
}

if (part == "all") {
    // Preview: all parts side by side, in the order of `parts`
    for (i = [0 : len(parts) - 1])
        translate([i * (holder_width + 15), 0, 0]) render_part(parts[i]);
} else if (part == "assembly") {
    assembly();
} else {
    // (the colour is only for the preview image; STL has no colour)
    color(preview_color_1) render_part(part);
}
