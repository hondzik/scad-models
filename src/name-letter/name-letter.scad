// name-letter - big first letter of a name with the whole name inlaid across it
//
// Two parts: `letter` (big capital with a pocket for the name) and `name` (the inlay, glue it into the pocket).
// `part = "all"` shows the assembled object in colour (preview only – STL has no colour; print the parts in two colours).
//
// CHANGELOG (newest first; keep `model_version` below in sync)
// 1.0.1 - fix: the name pocket in the letter ignored name_lower_case, so it did not match the inlay
// 1.0.0 - first release: letter + name inlay, assembled coloured preview, presets per name, optional stand (auto/yes/no)

/* [ Settings ] */
name = "Nemo";

/* [ First Letter ] */
first_letter_font = "Times New Roman:style=Bold";
first_letter_height = 200;
first_letter_depth = 50;
// preview colour only
first_letter_color = "#c0392b";

/* [ Stand ] */
// thin base plate under the middle of the big letter; auto = only for letters without a flat bottom (C, G, O, S, U, ...)
stand = "auto"; // [auto, yes, no]
// width of the base plate along X [mm]
stand_width = 80;
// thickness of the base plate below the letter [mm]
stand_thickness = 3;
// how far the plate reaches up into the letter [mm] (the letter bottom is not exactly at -height/2 – font dependent)
stand_overlap = 5;

/* [ Name ] */
name_font = "Script MT Bold:style=Regular";
name_height = 80;
name_depth = 15;
// write the name in lower case (both the inlay and its pocket in the big letter)
name_lower_case = true;
// preview colour only
name_color = "#f5f5f5";

/* [ Fit ] */
// gap around the name inlay [mm]
clearance = 0.2;

/* [ Hidden ] */
$fn = 100;
parts = ["letter", "name"];
part = "all";
preview_part = "all";   // part rendered for the assembled preview image (see scripts/build-stl.mjs)
model_version = "1.0.1";

// Převod jednoho kódu znaku na malé písmeno
function lowerCode(k) =
    (k >= 65 && k <= 90)                     ? k + 32 :   // A–Z
    (k >= 192 && k <= 222 && k != 215)       ? k + 32 :   // À–Þ (bez ×)
    (k >= 256 && k <= 303 && k % 2 == 0)     ? k + 1  :   // Ā–į
    (k >= 306 && k <= 311 && k % 2 == 0)     ? k + 1  :   // Ĳ–ķ
    (k >= 313 && k <= 328 && k % 2 == 1)     ? k + 1  :   // Ĺ–ň
    (k >= 330 && k <= 375 && k % 2 == 0)     ? k + 1  :   // Ŋ–ŷ
    (k == 376)                               ? 255    :   // Ÿ → ÿ
    (k >= 377 && k <= 382 && k % 2 == 1)     ? k + 1  :   // Ź–ž
    (k >= 913 && k <= 937 && k != 930)       ? k + 32 :   // řečtina Α–Ω
    (k >= 1040 && k <= 1071)                 ? k + 32 :   // azbuka А–Я
    (k >= 1024 && k <= 1039)                 ? k + 80 :   // azbuka Ѐ–Џ
    k;

// Převod jednoho kódu znaku na velké písmeno
function upperCode(k) =
    (k >= 97 && k <= 122)                    ? k - 32 :   // a–z
    (k >= 224 && k <= 254 && k != 247)       ? k - 32 :   // à–þ (bez ÷)
    (k == 255)                               ? 376    :   // ÿ → Ÿ
    (k >= 257 && k <= 303 && k % 2 == 1)     ? k - 1  :   // ā–į
    (k >= 307 && k <= 311 && k % 2 == 1)     ? k - 1  :   // ĳ–ķ
    (k >= 314 && k <= 328 && k % 2 == 0)     ? k - 1  :   // ĺ–ň
    (k >= 331 && k <= 375 && k % 2 == 1)     ? k - 1  :   // ŋ–ŷ
    (k >= 378 && k <= 382 && k % 2 == 0)     ? k - 1  :   // ź–ž
    (k == 962)                               ? 931    :   // ς → Σ
    (k >= 945 && k <= 969)                   ? k - 32 :   // řečtina α–ω
    (k >= 1072 && k <= 1103)                 ? k - 32 :   // azbuka а–я
    (k >= 1104 && k <= 1119)                 ? k - 80 :   // azbuka ѐ–џ
    k;

function toLower(s) = len(s) == 0 ? "" : chr([for (c = s) lowerCode(ord(c))]);
function toUpper(s) = len(s) == 0 ? "" : chr([for (c = s) upperCode(ord(c))]);

module formatted3DText(str, height, depth, font, clearance = 0, lower_case = false) {
    linear_extrude(height = depth)
    offset(delta = clearance)
    resize([0, height], auto = true)
    text(lower_case ? toLower(str) : str, size = height, font = font, halign = "center", valign = "center");
}

name_z = first_letter_depth - name_depth;   // Z of the inlay in the assembled object (flush with the top)

// Accented capitals -> base letter (the big letter is drawn without diacritics: Č -> C, Ř -> R, ...).
// Add more groups here when needed; characters not listed stay unchanged.
base_map = [
    ["A", "ÀÁÂÃÄÅĀĂĄǍ"], ["C", "ĆĈĊČÇ"], ["D", "ĎĐ"], ["E", "ÈÉÊËĒĔĖĘĚ"], ["G", "ĜĞĠĢǦ"], ["H", "ĤĦ"],
    ["I", "ÌÍÎÏĨĪĬĮİ"], ["J", "Ĵ"], ["K", "Ķ"], ["L", "ĹĻĽĿŁ"], ["N", "ŃŅŇÑ"], ["O", "ÒÓÔÕÖØŌŎŐǑ"],
    ["R", "ŔŖŘ"], ["S", "ŚŜŞŠȘ"], ["T", "ŢŤȚŦ"], ["U", "ÙÚÛÜŨŪŬŮŰŲǓ"], ["W", "Ŵ"], ["Y", "ÝŶŸ"], ["Z", "ŹŻŽ"],
];
function base_letter(c) =
    let (hit = [for (g = base_map) if (len(search(c, g[1])) > 0) g[0]])
    len(hit) > 0 ? hit[0] : c;

// Capitals that cannot stand upright on their own (round or pointed bottom) – `stand = "auto"` adds the base plate
// for them. Greek / Cyrillic are not covered, use stand = "yes" for them.
stand_letters = "CGJOQSUV";
first_capital = base_letter(toUpper(name[0]));
needs_stand = len(search(first_capital, stand_letters)) > 0;
use_stand = stand == "yes" || (stand == "auto" && needs_stand);
assert(stand == "auto" || stand == "yes" || stand == "no", "stand must be auto, yes or no");

// thin plate under the bottom edge of the letter, centred on X=0; the top overlaps the letter by stand_overlap so it fuses
// (the letter is vertically centred, so its lowest point is at Y = -first_letter_height / 2)
module stand_plate() {
    translate([-stand_width / 2, -first_letter_height / 2 - stand_thickness, 0])
        cube([stand_width, stand_thickness + stand_overlap, first_letter_depth]);
}

// the big capital (without diacritics) with a pocket (opened to the top) for the name, `clearance` around the inlay,
// plus the optional stand plate
module letter_part() {
    difference() {
        union() {
            formatted3DText(first_capital, first_letter_height, first_letter_depth, first_letter_font);
            if (use_stand) stand_plate();
        }
        translate([0, 0, name_z]) formatted3DText(name, height = name_height, depth = name_depth + 1, font = name_font, clearance = clearance, lower_case = name_lower_case);
    }
}

// the inlay: the whole name (lower case when name_lower_case), print orientation = flat on Z=0.
// The pocket in letter_part() is cut from the same text, so both must be called with the same lower_case.
module name_part() {
    formatted3DText(name, height = name_height, depth = name_depth, font = name_font, lower_case = name_lower_case);
}

module render_part(p) {
    if (p == "letter") letter_part();
    else if (p == "name") name_part();
    else if (p == "all") {
        color(first_letter_color) letter_part();
        translate([0, 0, name_z]) color(name_color) name_part();
    }
    else assert(false, str("unknown part: ", p));
}

render_part(part);