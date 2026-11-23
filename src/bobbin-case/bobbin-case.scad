
/* [Bobbin] */
bobbin_type="Class15";

/* [Columns and Counts] */
num_of_columns = 3;
bobbins_in_column = 3;
column_spacing = 2.0;

/* [Lid dimensions] */
lid_height = 7;

/* [Cover] */
cover_thickness = 2;
lock_size = 1;

/* [Hidden]*/
$fn=60;
lid_overlap = lid_height/2;
cover_spacing = lock_size + 0.5; // spacing between cover and holder, lock must 

assert(num_of_columns > 1, "Number of columns must be greater than 1");
assert(num_of_columns == floor(num_of_columns), "Number of columns must be an integer");
assert(bobbins_in_column > 0, "Number of bobbins in column must be greater than 0");
assert(bobbins_in_column == floor(bobbins_in_column), "Number of bobbins in column must be an integer");
assert(column_spacing >= 1, "Column spacing must be greater or equal to 1");
assert(lid_height >= 3, "Lid height must be greater or equal to 3");
assert(cover_thickness >= 2, "Cover thickness must be greater or equal to 2");
assert(lock_size >= 1, "Lock size must be greater or equal to 1");

// diameter, height and central hole diameter of common bobbin types
BOBBIN_TYPES = [
    ["Class15",  20.5, 11.7, 6.0],
    ["Class66",  20.5, 11.5, 6.0],
    ["L",        20.3,  8.9, 6.0],
    ["M",        24.6, 10.8, 7.0],
];

function bobbin_type(name) = 
    let (i = search([name], BOBBIN_TYPES)[0])
    assert(i != [], str("Unknown bobbin type: ", name))
    BOBBIN_TYPES[i];

function bobbin_circle_radius(bobbin_radius, column_spacing, num_of_columns) = 
    (bobbin_radius + (column_spacing)/2)/sin(180/num_of_columns);

function holder_radius(bobbin_radius, column_spacing, columns, overlap, cover_thickness) = 
    let(d = bobbin_circle_radius(bobbin_radius, column_spacing, columns))
    d + bobbin_radius + overlap + cover_thickness;

module lid(radius, height) {
    R = radius - height/2;
    circumference = 2 * PI * R;
    num_of_bals=round(circumference/3);
    union() {
        linear_extrude(height=height) circle(r=R);
        for (c = [0:num_of_bals-1]) {
            angle = 360 * c / num_of_bals;
            translate([R * cos(angle), R * sin(angle), height/2]) sphere(d = height);
        }
    }
}

module bobbin_holder(bobbin_radius, height, columns, spacing) {
    d = bobbin_circle_radius(bobbin_radius, spacing, columns);
    R = d + bobbin_radius - spacing/2;
    linear_extrude(height = height)
        difference() {
            circle(r=R);
            for (c = [0:columns-1]) {
                angle = 360 * c / columns;
                translate([d * cos(angle), d * sin(angle), 0]) circle(r=bobbin_radius);
            }
        }
}

module bobbin_cover(bobbin_radius, height, columns, spacing, wall) {
    d = bobbin_circle_radius(bobbin_radius, spacing, columns);
    R = d + bobbin_radius + spacing/2;
    linear_extrude(height = height + spacing/2)
        difference() {
            circle(r=R + wall);
            circle(r=R);
        }
}

bobbin = bobbin_type(bobbin_type);
bobbin_r = (bobbin[1]/2) * 1.05; // add 5% to bobbin radius for clearance
bobbin_h = bobbin[2] * 1.05; // add 5% to bobbin height for clearance
holder_h = bobbin_h * bobbins_in_column;
lid_r = holder_radius(bobbin_r, column_spacing, num_of_columns, lid_overlap, cover_thickness);

translate([lid_r*1.1, lid_r*1.1, 0]) union() {
    lid(lid_r, lid_height);
    translate([0, 0, lid_height]) bobbin_holder(bobbin_r, holder_h, num_of_columns, column_spacing);
}

translate([lid_r*1.1, -lid_r*1.1, 0]) union() {
    lid(lid_r, lid_height);
    translate([0, 0, lid_height]) bobbin_cover(bobbin_r, holder_h, num_of_columns, column_spacing, cover_thickness);
}