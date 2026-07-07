# GMVex API Reference

## Initialization

```gml
gmvex_init();
```

Initializes the GMVex system. Must be called before using any GMVex functions.

```gml
gmvex_set_tolerance(tol);
```

Sets the curve flattening tolerance. Lower values produce smoother curves at the cost of more vertices.

---

## Path Creation & Building

```gml
var path = gmvex_path_create();
```

Creates a new empty path.

```gml
gmvex_path_destroy(path);
```

Frees all resources associated with a path.

### Path Commands

```gml
gmvex_path_moveto(path, x, y);
gmvex_path_lineto(path, x, y);
gmvex_path_quadto(path, cx, cy, x, y, easing_fn);
gmvex_path_cubicto(path, c1x, c1y, c2x, c2y, x, y, easing_fn);
gmvex_path_splineto(path, x, y);          // Catmull-Rom spline
gmvex_path_close(path);
```

Builds path geometry. `easing_fn` can be a function that remaps t (0..1).

```gml
gmvex_path_set_winding(path, mode);
```

Sets winding rule: `gmvex_winding.EVENODD` or `gmvex_winding.NONZERO`.

```gml
gmvex_path_rebuild(path);
```

Flattens curves and builds vertex buffers. Called automatically when `dirty` is true.

### Shape Primitives

```gml
gmvex_path_add_rect(path, x, y, w, h);
gmvex_path_add_rounded_rect(path, x, y, w, h, rx, ry);
gmvex_path_add_ellipse(path, cx, cy, rx, ry);
gmvex_path_add_circle(path, cx, cy, r);
gmvex_path_add_line(path, x1, y1, x2, y2);
gmvex_path_add_polyline(path, points);
gmvex_path_add_polygon(path, points);
gmvex_path_arcto(path, rx, ry, x_axis_rotation, large_arc_flag, sweep_flag, x, y);
```

Adds geometric primitives to a path.

---

## Transforms

```gml
gmvex_path_set_transform(path, x, y, rot, xscale, yscale, origin_x, origin_y);
```

Sets a transform on a path. All parameters are optional except x,y.

```gml
gmvex_path_apply_transform_all(path);
gmvex_path_apply_position(path);
gmvex_path_apply_rotation(path);
gmvex_path_apply_scale(path);
```

Applies stored transforms directly to path coordinates.

```gml
var m = gmvex_path_get_matrix(path);
```

Returns the transformation matrix for the path.

```gml
gmvex_apply_transform_offset_command(cmd, dx, dy);
gmvex_apply_transform_scale_command(cmd, scale_x, scale_y);
gmvex_apply_transform_rotate_command(cmd, deg);
gmvex_apply_transform_walk(path, offset_fn, scale_fn, rotate_fn);
```

Low-level transform utilities for modifying path commands directly.

---

## Groups

```gml
var group = gmvex_group_create();
gmvex_group_add_path(group, path);
gmvex_group_add_group(group, child_group);
gmvex_group_set_transform(group, x, y, rot, xscale, yscale, origin_x, origin_y);
gmvex_group_resolve_transforms(group);
```

Groups allow hierarchical transforms. Call `gmvex_group_resolve_transforms()` to apply all group transforms to member paths.

```gml
gmvex_group_compose_point(acc, px, py);
gmvex_group_compose_accumulated(acc, group);
```

Internal functions for composing nested transforms.

---

## Rendering

### Fills

```gml
gmvex_fill_draw(path, col, alpha);
gmvex_fill_draw_gradient(path, type, p0x, p0y, p1x, p1y, stops);
gmvex_fill_draw_masked(path, col, alpha);
```

- `type`: `gmvex_gradient.LINEAR` or `gmvex_gradient.RADIAL`
- `stops`: Array of `[position, color, alpha]` (max 8 stops)
- `gmvex_fill_draw_masked()` uses a mask set with `gmvex_path_set_mask()`

### Strokes

```gml
gmvex_stroke_draw(path, width, col, alpha, join_mode, cap_mode, miter_limit);
```

- `join_mode`: `gmvex_join.BEVEL`, `gmvex_join.ROUND`, `gmvex_join.MITER`
- `cap_mode`: `gmvex_cap.BUTT`, `gmvex_cap.ROUND`, `gmvex_cap.SQUARE`

```gml
gmvex_stroke_set_dash(path, dash_array, dash_offset);
```

Sets dash pattern. Array length must be even; odd arrays are doubled automatically.

```gml
gmvex_stroke_vertex(vb, x, y, col, a, u, v);
```

Adds a vertex to a stroke vertex buffer.

### Stroke Geometry Helpers

```gml
gmvex_stroke_emit_polyline(vb, pts, closed, col, alpha, join_mode, cap_mode, miter_limit, hw);
gmvex_stroke_dedupe_points(pts, eps);
gmvex_miter_point(segA, segB, shared, hw, miter_limit);
gmvex_miter_point_side2(segA, segB, shared, hw, miter_limit);
gmvex_round_join(vb, shared, segA, segB, hw, col, alpha, u_join);
gmvex_round_fan(vb, cx, cy, x0, y0, x1, y1, radius, col, alpha, u_join, v_val);
gmvex_draw_cap(vb, endpoint, dirx, diry, hw, col, alpha, cap_mode, u_val, ax, ay, bx, by);
```

Low-level stroke geometry functions used by `gmvex_stroke_draw()`.

---

## Dash Patterns

```gml
gmvex_dash_normalize_array(dash_array);
gmvex_dash_build_intervals(total_len, dash_array, dash_offset);
gmvex_stroke_extract_range(pts, closed, start_len, end_len);
```

Core dash pattern utilities. Used internally by `gmvex_stroke_draw()`.

---

## Boolean Operations

```gml
var result = gmvex_path_boolean(path_a, path_c, op);
```

Performs boolean operations on two paths.
- `op`: `gmvex_bool.UNION`, `gmvex_bool.INTERSECTION`, `gmvex_bool.A_NOT_C`, `gmvex_bool.C_NOT_A`

### Internal Boolean Functions

```gml
gmvex_seg_intersect(p1x, p1y, p2x, p2y, p3x, p3y, p4x, p4y, out);
gmvex_bool_point_in_loop(px, py, pts);
gmvex_bool_signed_area(pts);
gmvex_bool_normalize_winding(pts);
gmvex_bool_reverse_loop(pts);
gmvex_bool_build_ring(pts, hits, is_subject_side);
gmvex_bool_split_arcs(ring, other_pts);
gmvex_bool_reverse_arc(arc);
gmvex_bool_stitch_arcs(arcs_a, arcs_c);
gmvex_bool_classify_degenerate(loop_a, loop_c);
gmvex_bool_degenerate_result(loop_a, loop_c, op);
gmvex_bool_loop_pair(loop_a_raw, loop_c_raw, op);
gmvex_bool_op_name(op);
gmvex_bool_rebuild_vbuff_from_flat(path);
```

Low-level boolean operation utilities.

---

## Text

### Font Loading

```gml
var font = gmvex_text_font_load(filename);
gmvex_text_font_destroy(font);
```

Loads a TrueType font file (.ttf). Only TTF outlines are supported (no CFF/OTF).

### Text to Paths

```gml
var paths = gmvex_text_to_paths(font, text, size, x, y, style, line_spacing_extra);
```

Converts text to an array of path objects with `path` and `char` properties.

`style` object:
- `bold`: boolean
- `bold_strength`: number (default 0.02);
- `italic`: boolean
- `italic_shear`: number (default 0.20);
- `halign`: `gmvex_halign.LEFT|CENTER|RIGHT`
- `valign`: `gmvex_valign.TOP|MIDDLE|BASELINE|BOTTOM`
- `letter_spacing`: number

```gml
var path = gmvex_text_char_to_path(font, char_code, size, style);
```

Converts a single character to a path.

### Text Metrics

```gml
var width = gmvex_text_measure_width(font, text, size, letter_spacing);
var height = gmvex_text_get_height(font, text, size, line_spacing_extra);
var size = gmvex_text_get_size(font, text, size, letter_spacing, line_spacing_extra);
```

Returns text dimensions in pixels.

### Text Transform

```gml
gmvex_text_set_transform(text_paths, x, y, rot, xscale, yscale, origin_x, origin_y);
```

Applies a transform to all paths in a text output array.

### Glyph Functions

```gml
gmvex_text_char_to_glyph(font, char_code);
gmvex_text_get_loca_range(font, gid);
gmvex_text_get_advance_width(font, gid);
gmvex_text_get_glyph_contours(font, gid, dx, dy);
gmvex_text_decode_simple_glyph(font, glyph_offset, number_of_contours);
gmvex_text_decode_composite_glyph(font, glyph_offset, dx0, dy0);
```

Low-level font glyph access functions.

### Text Contours

```gml
gmvex_text_offset_contour(pts, amount);
gmvex_text_flatten_contour_points(contour);
gmvex_text_add_contour_to_path(path, contour, scale, origin_x, origin_y, bold_amount, italic_shear);
```

Glyph contour manipulation functions used internally.

### Font Data Reading

```gml
gmvex_text_read_u8(buf, offset);
gmvex_text_read_s8(buf, offset);
gmvex_text_read_u16be(buf, offset);
gmvex_text_read_s16be(buf, offset);
gmvex_text_read_u32be(buf, offset);
gmvex_text_read_tag(buf, offset);
```

Low-level font data reading functions.

---

## SVG Import

```gml
var result = gmvex_svg_import(filename, default_color, font_map, default_font);
```

Imports an SVG file. Returns:
- `group`: Group containing all paths
- `results`: Array of rendering info for each shape
- `doc_width`, `doc_height`: Document dimensions

### SVG Rendering

```gml
gmvex_svg_draw_fill(info);
```

Helper to draw a fill from SVG import result, handling gradients automatically.

### SVG Internal Functions

```gml
gmvex_svg_skip_whitespace(str, pos);
gmvex_svg_try_skip_comment(str, pos);
gmvex_svg_parse_attribute(str, pos);
gmvex_svg_parse_element(str, pos);
gmvex_svg_parse_xml(str);
gmvex_svg_is_digit(c);
gmvex_svg_scan_number(str, pos);
gmvex_svg_scan_flag(str, pos);
gmvex_svg_parse_path_data(path, d);
gmvex_svg_parse_color(value, default_color);
gmvex_svg_get_attr(attributes, name, default_value, style_map);
gmvex_svg_element_to_result(element, default_color, gradient_map, id_map);
gmvex_svg_walk_element(element, results, default_color);
gmvex_svg_walk_collect(element, group, results, default_color, gradient_map, id_map, font_map, default_font);
gmvex_svg_matrix_multiply(m1, m2);
gmvex_svg_matrix_identity();
gmvex_svg_parse_transform_function(str, pos);
gmvex_svg_parse_transform_attr(value);
gmvex_svg_decompose_matrix(m);
gmvex_svg_walk_element_grouped(element, default_color);
gmvex_svg_parse_length(value);
gmvex_svg_parse_style_attr(style_str);
gmvex_svg_collect_gradients(element, gradient_map);
gmvex_svg_compute_gradient_coords(path, gradient);
gmvex_svg_collect_ids(element, id_map);
gmvex_svg_resolve_use(element, group, results, default_color, gradient_map, id_map, depth);
gmvex_svg_resolve_text(element, default_color, font_map, default_font);
gmvex_svg_extract_url_id(value);
gmvex_svg_resolve_clip_path(target_path, clip_path_str, id_map, default_color, gradient_map);
gmvex_svg_resolve_mask(target_path, mask_str, id_map, default_color, gradient_map);
```

Low-level SVG parsing and import utilities.

---

## Hit Testing

```gml
var hit = gmvex_path_hit_test_fill(path, px, py);
var hit = gmvex_path_hit_test_stroke(path, px, py, stroke_width, tolerance);
```

Tests if a point is inside the filled area or within the stroke of a path.

```gml
gmvex_point_in_polygon_evenodd(px, py, pts);
gmvex_point_in_polygon_winding_number(px, py, pts);
gmvex_winding_number_contribution(px, py, pts);
gmvex_transform_point_inverse(path, wx, wy);
gmvex_point_segment_distance(px, py, x0, y0, x1, y1);
```

Low-level hit testing utilities.

---

## Masks

```gml
gmvex_path_set_mask(path, mask_path);
gmvex_path_mark_mask_dirty(path);
gmvex_mask_ensure_surface(path);
```

Sets a mask path. The mask defines which parts of the main path are visible (white areas).

---

## Arc Functions

```gml
gmvex_arc_angle(ux, uy, vx, vy);
gmvex_arc_segment_to_cubic(path, cx, cy, rx, ry, phi, theta1, delta_theta);
```

SVG arc conversion utilities. Used internally by `gmvex_path_arcto()`.

---

## Signed Area & Winding

```gml
gmvex_signed_area(pts);
```

Calculates signed area of a polygon. Used for winding direction detection.

---

## Constants

### Enums

```gml
gmvex_cmd      // MOVETO, LINETO, QUADTO, CUBICTO
gmvex_join     // BEVEL, ROUND, MITER
gmvex_cap      // BUTT, ROUND, SQUARE
gmvex_winding  // EVENODD, NONZERO
gmvex_gradient // LINEAR, RADIAL
gmvex_bool     // UNION, INTERSECTION, A_NOT_C, C_NOT_A
gmvex_halign   // LEFT, CENTER, RIGHT
gmvex_valign   // TOP, MIDDLE, BASELINE, BOTTOM
```

---

## Global Variables

```gml
global.gmvex_vformat_pos   // Vertex format: position only
global.gmvex_vformat_full  // Vertex format: position + color + texcoord
global.gmvex_tolerance     // Curve flattening tolerance (default 0.5);
```

GMVex uses these global variables for vertex formats. The shader constants `GMVEX_SOLID_COLOR`, `GMVEX_GRADIENT_LINEAR`, `GMVEX_GRADIENT_RADIAL`, and `GMVEX_MASK_LUMINANCE` must be defined externally.

---

## Worth keeping in mind

- Call `gmvex_init()` before any other GMVex functions.
- Paths must be rebuilt after modification (automatic when `dirty` is true).
- Destroy paths and fonts when no longer needed to prevent memory leaks.
- Some SVG features (CFF fonts, complex clip-paths, shear transforms); have limited support.
- Boolean operations automatically flatten paths before processing.
