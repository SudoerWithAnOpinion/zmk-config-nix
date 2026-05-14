include <includes.scad>

// --- SETTINGS ---
$font = "Cyber Alert";
$font_size = 6;
$extra_legend_size=4;
$total_depth = 4;  // Low profile height (Choc standard is ~3-4mm)
$top_tilt = 0;       // Keeps it perfectly flat for a high-tech look

// --- PRISTINE BLOCK SETTINGS ---
$width_difference = 0;   // Removes the side taper (makes walls vertical)
$height_difference = 0;  // Removes the front/back taper
$bottom_radius = 0;      // Removes the rounded "lip" at the bottom
$corner_radius = 0;      // Removes KeyV2 top corner rounding
$top_skew = 0;           // Ensures the top isn't shifted
$dish_type = "none";     // Perfectly flat top surface

$cyberpunk_corner_cut = 4;     // Size of diagonal corner trims (mm)
$key_half_extent = 9.5;          // Approximate half-width/height of a 1u key (mm)
$corner_cut_height = 20;         // Tall enough to cut fully through any generated part
$cyberpunk_cut_all_corners = false; // true = chamfer all 4 corners on every key
$cyberpunk_corner_flip_all = true; // true = use opposite corners for all keys
$cyberpunk_corner_flip_keys = [];   // Optional per-key flip list: [[row,col], ...] (0-based)
//$cyberpunk_corner_flip_keys = [     // Corne split map: right half flipped, left half normal
//  [0,5], [0,6], [0,7], [0,8], [0,9],
//  [1,5], [1,6], [1,7], [1,8], [1,9],
//  [2,4], [2,5], [2,6],
//  [3,2], [3,3]
//];

$stem_support_type = "disable"; // Disable stem supports (printing flat)
$inset_legend_depth = 0.4; // 0.4mm deep (exactly 2 layers at 0.2mm height)

legends = [
//  // Left
//  ["Q1", "W2", "E3", "R4", "T5"], 
//  ["A!", "S@", "D#", "F$", "G%"],
//  ["Z=", "X-", "C+", "V{", "B}"],
//  ["./svg/lower.svg","./svg/command.svg","./svg/option.svg","./svg/shift.svg","./svg/control.svg",],
//  // Right
//  ["Y6", "U7", "I8", "O9", "P0"],
//  [ "H^", "J&", "K*", "L(", ";):", ["'","|","\""] ],
//  [ "N[", "M]", ",<;", ".>:", "/?\\"],
//  ["./svg/raise.svg","./svg/command.svg","./svg/option.svg","./svg/shift.svg","./svg/control.svg",],
//  
//  [
//    "./svg/command.svg","./svg/option.svg","./svg/shift.svg","./svg/control.svg",
//  ],
//  [
//    "./svg/raise.svg","./svg/lower.svg", 
//    "./svg/delete.svg", "./svg/backspace.svg",
//  ]
  [
    ["/", "\\", "?"], ",;<", ".:>"
  ],
//  [ ["`", "", "~"] ]
];
// Maps rows to a color theme [key, legends]
$colorMap = [
  ["#0F0F0F", "Orange"],["#0F0F0F", "Orange"],
  ["#0F0F0F", "Orange"],["#0F0F0F", "Orange"],
  ["#0F0F0F", "Orange"],["#0F0F0F", "Orange"],
  ["#0F0F0F", "Orange"],
  ["#0F0F0F", "Orange"],
  ["#0F0F0F", "Orange"],
  ["#0F0F0F", "Orange"],
];
$sublegendSettingsMap = [
  // Primary Size, Upper Size, Lower Size, Lower Offset, Upper Offset
  [$font_size,3.5,4, [1,1], [1,-1]],
  [$font_size,3.5,4, [1,1], [1,-1]],
  [$font_size,3.5,4, [1,1], [1,-1]],
  [$font_size,3.5,4, [1,1], [1,-1]],
  [$font_size,3.5,4, [1,1], [1,-1]],
  [$font_size,3.5,4, [1,1], [1,-1]],
  [$font_size,3.5,4, [1,1], [1,-1]],
  [10,4,10, [1,1], [1,-1]],
];
// ... your settings and legends array here ...

function key_in_flip_list(row, col, flip_keys = $cyberpunk_corner_flip_keys) =
  len([for (p = flip_keys) if (len(p) >= 2 && p[0] == row && p[1] == col) 1]) > 0;

function should_flip_corner(row, col) =
  $cyberpunk_corner_flip_all || key_in_flip_list(row, col);

module cyberpunk_corner_profile(cut = $cyberpunk_corner_cut, half_extent = $key_half_extent, h = $corner_cut_height, flip = false, all_corners = $cyberpunk_cut_all_corners) {
  difference() {
    children();

    if (cut > 0) {
      translate([0, 0, -h/2])
      linear_extrude(height = h)
      union() {
        if (all_corners) {
          // Top-left chamfer
          polygon([
            [-half_extent, half_extent],
            [-half_extent + cut, half_extent],
            [-half_extent, half_extent - cut]
          ]);

          // Top-right chamfer
          polygon([
            [half_extent, half_extent],
            [half_extent - cut, half_extent],
            [half_extent, half_extent - cut]
          ]);

          // Bottom-left chamfer
          polygon([
            [-half_extent, -half_extent],
            [-half_extent + cut, -half_extent],
            [-half_extent, -half_extent + cut]
          ]);

          // Bottom-right chamfer
          polygon([
            [half_extent, -half_extent],
            [half_extent - cut, -half_extent],
            [half_extent, -half_extent + cut]
          ]);
        } else {
          if (!flip) {
            // Top-left chamfer
            polygon([
              [-half_extent, half_extent],
              [-half_extent + cut, half_extent],
              [-half_extent, half_extent - cut]
            ]);

            // Bottom-right chamfer
            polygon([
              [half_extent, -half_extent],
              [half_extent - cut, -half_extent],
              [half_extent, -half_extent + cut]
            ]);
          } else {
            // Top-right chamfer (flipped)
            polygon([
              [half_extent, half_extent],
              [half_extent - cut, half_extent],
              [half_extent, half_extent - cut]
            ]);

            // Bottom-left chamfer (flipped)
            polygon([
              [-half_extent, -half_extent],
              [-half_extent + cut, -half_extent],
              [-half_extent, -half_extent + cut]
            ]);
          }
        }
      }
    }
  }
}


for (y = [0:1:len(legends)-1])
for (x = [0:1:len(legends[y])-1]) {
    let(key_val = legends[y][x])
    let(is_svg = len(key_val) > 4 && str(key_val[len(key_val)-4], key_val[len(key_val)-3], key_val[len(key_val)-2], key_val[len(key_val)-1]) == ".svg")

    translate_u(y+1, 0)
    translate_u(0, -x-1) 
    
    // THE MAGIC WRAPPER FOR 3MF PARTS
    union() {
        // PART 1: THE KEYCAP BODY (Color A)
      color($colorMap[y][0]) cyberpunk_corner_profile(flip = should_flip_corner(y, x)) {
        choc() upside_down() {
          if (is_svg) {
            key(inset=true) {
              translate([0, 0, $total_depth-$inset_legend_depth])
              linear_extrude(height = $inset_legend_depth) 
              scale(1.5) import(key_val, center = true);
            }
          } else {
            let($font_size=$sublegendSettingsMap[y][0]) legend(key_val[0], [0,0])
            let($font_size=$sublegendSettingsMap[y][1]) legend(key_val[1], $sublegendSettingsMap[y][3])
            let($font_size=$sublegendSettingsMap[y][2]) legend(key_val[2], $sublegendSettingsMap[y][4])
            key(); // This creates the cap with the legend subtracted
          }
            }
        }

        // PART 2: THE INSET LEGEND (Color B)
        color($colorMap[y][1]) cyberpunk_corner_profile(flip = should_flip_corner(y, x)) {
          choc() upside_down() {
            if (is_svg) {
              // Manually extrude the SVG as a separate part
              translate([0, -9, $total_depth-$inset_legend_depth])
              linear_extrude(height = $inset_legend_depth) 
              scale(1.5) import(key_val, center = true);
            } else {
              // Repeat the legend definitions
              let($font_size=$sublegendSettingsMap[y][0]) legend(key_val[0], [0,0])
              let($font_size=$sublegendSettingsMap[y][1]) legend(key_val[1], $sublegendSettingsMap[y][3])
              let($font_size=$sublegendSettingsMap[y][2]) legend(key_val[2], $sublegendSettingsMap[y][4])
                    
              // Call the actual geometry generator instead of the keycap
              legends(); 
            }
            }
        }
    }
}

//let($file = "./svg/grave_escape.svg") union() {
//  // PART 1: THE KEYCAP BODY (Color A)
//  color("#0F0F0F") 
//  cyberpunk_corner_profile(flip = should_flip_corner(y, x)) {
//    choc() upside_down() {
//      key(inset=true) {
//        translate([0, 0, $total_depth - $inset_legend_depth])
//        linear_extrude(height = $inset_legend_depth) 
//        scale(1.5) import($file, center = true);
//      }
//    }
//  }
//
//  // PART 2: THE INSET LEGEND (Color B)
//  color("Orange") 
//  cyberpunk_corner_profile(flip = should_flip_corner(y, x)) {
//    choc() upside_down() {
//      // Manually extrude the SVG as a separate part
//      translate([0, -9, $total_depth - $inset_legend_depth])
//      linear_extrude(height = $inset_legend_depth) 
//      translate([2.5,-5,0]) scale(1.5) import($file, center = true);
//    }
//  }
//}

//union() {
//  // PART 1: THE KEYCAP BODY (Color A)
//  color("#0F0F0F") 
//  cyberpunk_corner_profile(flip = should_flip_corner(y, x)) {
//    choc() upside_down() {
//      key();
//    }
//  }
//
//}