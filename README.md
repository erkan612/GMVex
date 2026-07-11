# GMVex

Native implementation of vector graphics in GameMaker.

## Features

- Path building with beziers, arcs and splines
- Fill, stroke, and gradient rendering (flat, linear, and radial gradient, including on strokes)
- Hierarchical transforms and groups
- Boolean operations (union, intersection, difference)
- Masking and clip-path, including multi-shape and objectBoundingBox units
- TrueType font rendering with kerning and ligature support
- SVG import (still being improved, so it does have some limitations)
- Dash patterns
- Hit testing

## Quick Example

```gml
// Create
gmvex_init();

shape = gmvex_path_create();
gmvex_path_add_rounded_rect(shape, 0, 0, 200, 150, 20);
gmvex_path_set_transform(shape, 50, 50);

mask = gmvex_path_create();
gmvex_path_add_circle(mask, 0, 0, 70);
gmvex_path_set_transform(mask, 100, 75); // centered in shape's own local space
gmvex_path_set_mask(shape, mask);

// Draw
gmvex_fill_draw_gradient_masked(
    shape, gmvex_gradient.LINEAR,
    0, 75, 200, 75,
    [[0, make_color_rgb(155, 89, 255), 1], [1, make_color_rgb(0, 224, 255), 1]]
);

// Cleanup
gmvex_path_destroy(shape); // also frees the attached mask
```

<img width="237" height="219" alt="sample1" src="https://github.com/user-attachments/assets/8ab9f000-ab10-43ae-ba72-c47c0bb94bdc" />

---

```gml
// Create
gmvex_init();

var disc = gmvex_path_create();
gmvex_path_add_circle(disc, 150, 150, 80);

var bite = gmvex_path_create();
gmvex_path_add_circle(bite, 205, 150, 80);

crescent = gmvex_path_boolean(disc, bite, gmvex_bool.A_NOT_C);
gmvex_path_destroy(disc);
gmvex_path_destroy(bite);

// Draw
gmvex_fill_draw_gradient(
    crescent, gmvex_gradient.RADIAL,
    170, 140, 90, 0,
    [[0, make_color_rgb(255, 220, 130), 1], [1, make_color_rgb(255, 110, 40), 1]]
);
gmvex_stroke_draw(crescent, 3, make_color_rgb(255, 240, 200), 0.8);

// Cleanup
gmvex_path_destroy(crescent);
```

<img width="242" height="224" alt="sample2" src="https://github.com/user-attachments/assets/4f8883e9-9717-408f-9505-a0477c8caee1" />

---

```gml
// Create
gmvex_init(0.1);

cx = 250;
cy = 220;

// outer ring: boolean subtraction (big disc minus a smaller
// concentric disc), gradient-filled
var ring_outer = gmvex_path_create();
gmvex_path_add_circle(ring_outer, cx, cy, 130);
var ring_inner = gmvex_path_create();
gmvex_path_add_circle(ring_inner, cx, cy, 100);
ring = gmvex_path_boolean(ring_outer, ring_inner, gmvex_bool.A_NOT_C);
gmvex_path_destroy(ring_outer);
gmvex_path_destroy(ring_inner);

// inner disc: gradient fill + circular mask, so the gradient is
// visibly cropped rather than a plain circle
disc = gmvex_path_create();
gmvex_path_add_rect(disc, 0, 0, 200, 200);
gmvex_path_set_transform(disc, cx - 100, cy - 100);
disc_mask = gmvex_path_create();
gmvex_path_add_circle(disc_mask, 0, 0, 95);
gmvex_path_set_transform(disc_mask, 100, 100); // center of disc's own local space
gmvex_path_set_mask(disc, disc_mask);

// eight rays around the ring, each a stroked, gradient-colored
// short line, evenly spaced
rays = [];
for (var i = 0; i < 8; i++) {
    var ang = i * 45;
    var rx0 = cx + lengthdir_x(140, ang), ry0 = cy + lengthdir_y(140, ang);
    var rx1 = cx + lengthdir_x(165, ang), ry1 = cy + lengthdir_y(165, ang);
    var ray = gmvex_path_create();
    gmvex_path_add_line(ray, rx0, ry0, rx1, ry1);
    array_push(rays, ray);
}

// caption: real vector text, not draw_text
caption_font = gmvex_text_font_load("Roboto-Regular.ttf");
if (!is_undefined(caption_font)) {
    caption_paths = gmvex_text_to_paths(caption_font, "GMVex", 42, cx, cy + 220, { halign: gmvex_halign.CENTER }, undefined, false);
}

// Draw
gmvex_fill_draw_gradient(
    ring, gmvex_gradient.RADIAL,
    cx, cy, 130, 0,
    [[0, make_color_rgb(255, 200, 90), 1], [1, make_color_rgb(255, 90, 40), 1]]
);

gmvex_fill_draw_gradient_masked(
    disc, gmvex_gradient.LINEAR,
    0, 100, 200, 100,
    [[0, make_color_rgb(255, 240, 180), 1], [1, make_color_rgb(255, 140, 60), 1]]
);

for (var i = 0; i < 8; i++) {
    var ang = i * 45;
    var rx0 = cx + lengthdir_x(140, ang), ry0 = cy + lengthdir_y(140, ang);
    var rx1 = cx + lengthdir_x(165, ang), ry1 = cy + lengthdir_y(165, ang);
    gmvex_stroke_draw_gradient(
        rays[i], 6, gmvex_gradient.LINEAR,
        rx0, ry0, rx1, ry1, // each ray's own axis: its own start point to its own end point
        [[0, make_color_rgb(255, 210, 120), 1], [1, make_color_rgb(255, 100, 50), 1]]
    );
}

if (!is_undefined(caption_font)) {
    for (var i = 0; i < array_length(caption_paths); i++) {
        gmvex_fill_draw(caption_paths[i].path, make_color_rgb(255, 160, 70), 1);
    }
}

// Cleanup
gmvex_path_destroy(ring);
gmvex_path_destroy(disc); // also frees disc_mask
for (var i = 0; i < array_length(rays); i++) gmvex_path_destroy(rays[i]);
if (!is_undefined(caption_font)) {
    for (var i = 0; i < array_length(caption_paths); i++) gmvex_path_destroy(caption_paths[i].path);
    gmvex_text_font_destroy(caption_font);
}
```

<img width="404" height="423" alt="sample3" src="https://github.com/user-attachments/assets/83c4c226-767f-40c5-b5bd-7532fb2151fe" />

---

```gml
// Create
gmvex_init();

// https://pixabay.com/vectors/soccer-player-game-match-athlete-10345525/
imported = gmvex_svg_import("mohamed_hassan-soccer.svg");
if (is_undefined(imported.group)) {
    show_debug_message("SVG File is not found!");
}

// positions are imported from svg file, so this is
// to make sure that the render starts at top left
// not a must if you are working with your own svg file
var minx = infinity, miny = infinity;
var maxx = -infinity, maxy = -infinity;
for (var i = 0; i < array_length(imported.results); i++) {
    var p = imported.results[i].path;
    if (p.dirty) gmvex_path_rebuild(p);
    minx = min(minx, p.bbox[0]);
    miny = min(miny, p.bbox[1]);
    maxx = max(maxx, p.bbox[2]);
    maxy = max(maxy, p.bbox[3]);
}
for (var i = 0; i < array_length(imported.results); i++) {
    gmvex_path_set_transform(imported.results[i].path, -minx, -miny);
}

// Draw
gmvex_svg_draw_all(imported);

// Cleanup
for (var i = 0; i < array_length(imported.results); i++) gmvex_path_destroy(imported.results[i].path);
```

<img width="706" height="531" alt="sample4" src="https://github.com/user-attachments/assets/3b162579-8108-41dd-b997-8bc8b3798b00" />

---

## Limitations/Constraints

- TrueType fonts only (no CFF or OTF)
- No text rendering without font files
- No shear support in SVG transforms
- Gradient stops limited to 8
