# GMVex API Reference

## Core Concepts

### Path local space vs. world placement

Every `gmvex_path` has two separate coordinate systems that are easy to
conflate:

- **Local/command space** - the raw coordinates passed to
  `gmvex_path_add_rect`, `gmvex_path_add_circle`, `gmvex_path_moveto`, etc.
  `path.bbox` is always computed from this space, *never* adjusted by the
  path's own transform.
- **World placement** - `path.tmatrix`, a 6-element `[a,b,c,d,e,f]` affine
  matrix (`x'=a·x+c·y+e, y'=b·x+d·y+f`), plus `tox`/`toy` tracking the
  pivot point last used. Set via `gmvex_path_set_transform`. Applied only
  at draw time via the GPU world matrix; never baked into `path.bbox` or
  `path.subpaths` automatically. The `x`/`y`/`rot`/`xscale`/`yscale`/
  `shear_x`/`shear_y` parameters passed to `gmvex_path_set_transform` are
  compiled into `tmatrix` and not retained individually - there is no way
  to read back what rotation a path was last set to, only the resulting
  matrix.

**This distinction is the single most common source of bugs in this
framework.** Two systems in particular ignore world placement entirely
and expect local-space coordinates:

- **`gmvex_path_boolean`** operates purely on each input path's raw local
  geometry. If two paths need boolean-combining based on where they're
  *positioned* in the world, their transforms must be baked in first via
  `gmvex_path_apply_transform_all`, otherwise two paths built with
  identical local geometry but different placement are treated as
  perfectly coincident, producing degenerate near-zero-area results.
- **Mask content** (`gmvex_path_set_mask`, and everything built on top of
  it) is positioned relative to the *target's* local/command space, not
  world space and not the mask path's own arbitrary origin. A mask circle
  meant to sit at the center of a target rectangle built via
  `gmvex_path_add_rect(target, 0, 0, 200, 200)` goes at local `(100,100)`, 
  the center of that local box, regardless of whatever placement the
  target itself has been given.

### Fill-time performance model

Fills use a two-pass GPU stencil techniqe: first mark covered pixels via
stencil incr/decr (nonzero winding) or invert (even-odd), then a covering
rectangle writes color wherever the stencil is nonzero. Strokes are
directly triangulated, no stencil pass needed. All draw functions cache
their vertex buffers (`path.vbuff`/`path.vbuff_cw`/`path.stroke_vbuff`) and
only rebuild on `path.dirty`, a relevant parameter change (stroke width,
join, cap), or a change to `global.gmvex_tolerance` since the geometry was
last built.

### GPU/draw state discipline

Every draw function in `GMVex_Draw.gml` and `GMVex_Gradient.gml` snapshots
the GPU/draw state it's about to touch and restores it exactly before
returning, stencil enable, colorwrite, z-write, stencil func/ref/fail/
depth-fail/pass, draw color/alpha, and the world matrix. Calling any
`gmvex_*_draw*` function is safe to interleave with other rendering code
or other frameworks without leaking state.

---

## Setup

### `gmvex_init()`
Call once, before using anything else in the framework. Creates the two
shared vertex formats every path uses (`global.gmvex_vformat_pos`,
position only, used for the stencil-marking passes during fill; and
`global.gmvex_vformat_full`, position + colour + texcoord, used for
strokes and anything shader-driven) and sets the default curve-flattening
tolerance to `0.5`.

### `gmvex_set_tolerance(tol)`
Sets `global.gmvex_tolerance`, the flatness threshold curves are recursively
subdivided against when building renderable geometry (smaller = smoother
curves, more points, more triangles). Also governs round join/cap
subdivision granularity in strokes (see *Stroke Drawing* below) - the
angular step is solved from tolerance and the actual radius being drawn,
not a fixed step count, so thicker strokes and finer tolerance both
produce more segments. Affects every path the next time it's drawn or
rebuilt, correctly triggers a rebuild on that next draw for an
already-built, currently-clean path, tracked separately for a path's fill
geometry and its stroke geometry since they're cached independently.

---

## Path Construction & Editing

A `gmvex_path` stores each subpath as a sequence of drawing commands
(`gmvex_cmd.MOVETO/LINETO/QUADTO/CUBICTO`) in **local/command space**, see
*Path local space vs. world placement* above. Nothing here touches the
GPU; geometry only becomes renderable once `gmvex_path_rebuild` flattens
curves into line segments and builds vertex buffers (done automatically,
lazily, by every draw/hit-test function via the `path.dirty` flag).

### `gmvex_path_create()`
Returns a new, empty path struct.

### `gmvex_path_destroy(path)`
Frees the path's vertex buffers (fill, fill-CW, stroke) and, if a mask is
attached, its cached mask surface and recursively destroys the mask
content path too. Safe to call on a path that was never drawn (no vbuffs
ever built) or never masked.

### `gmvex_path_moveto(path, x, y)` / `gmvex_path_lineto(path, x, y)`
Start a new subpath / extend the current one with a straight line.
`lineto` before any `moveto` on a fresh path implicitly starts one.

### `gmvex_path_quadto(path, cx, cy, x, y, easing_fn = -1)`
Quadratic Bézier curve to `(x,y)` via control point `(cx,cy)`. Internally
elevated to a cubic before flattening (quadratic and cubic curves share
one flattening code path). `easing_fn`, if given, is a callable taking a
`0`–`1` progress value and returning a remapped `0`–`1` value, the curve
is walked in a fixed 24 steps using the eased parameter instead of
adaptive recursive subdivision.

### `gmvex_path_cubicto(path, c1x, c1y, c2x, c2y, x, y, easing_fn = -1)`
Cubic Bézier curve via two control points. Same easing behavior as
`gmvex_path_quadto`.

### `gmvex_path_splineto(path, x, y)`
Adds a Catmull-Rom spline control point. The first call after a `moveto`
establishes the spline's start; each subsequent call adds another point
the curve passes through. Internally converted to a chain of cubic Bézier
segments at rebuild time (standard Catmull-Rom-to-Bézier tangent
construction, using a 1/6 tangent scale).

### `gmvex_path_close(path)`
Marks the current subpath as closed (its last point connects back to its
first). Required for correct fills, an open subpath can still be
stroked, but `gmvex_path_rebuild`'s fill triangulation and the hit-test
functions both key off `closed` to know whether to wrap the point loop.

### `gmvex_path_set_winding(path, mode)`
Sets `gmvex_winding.EVENODD` or `.NONZERO` (the default). Determines which
GPU stencil technique `gmvex_fill_draw`/`_masked`/`_gradient*` use, see
*Fill-time performance model* above.

### `gmvex_path_rebuild(path)`
Flattens every subpath's curves into line-segment point loops
(`path.flat_subpaths`), computes `path.bbox` from those flattened points,
and builds the fill vertex buffer(s), `path.vbuff` (CCW/primary) and
`path.vbuff_cw` (CW, only populated for `NONZERO` winding when clockwise
triangles exist). Called automatically by every draw and hit-test
function when `path.dirty` is true; rarely needs to be called directly,
except when you need `path.bbox`/`path.flat_subpaths` populated *before*
any draw call happens (e.g. for a manual pixel-space calculation).

Paths whose `subpaths` is empty but which already have real
`flat_subpaths` content - the output of `gmvex_path_merge` or
`gmvex_path_boolean`, or a clone of either - are handled correctly: the
flatten-from-subpaths step is skipped (there is nothing to derive it
from) and only the vertex buffers get rebuilt from the existing flattened
points.

---

## Shape Primitives

Convenience builders on top of the primitives above, all in local/command
space, none touch world placement.

- **`gmvex_path_add_rect(path, x, y, w, h)`** - closed rectangle.
- **`gmvex_path_add_rounded_rect(path, x, y, w, h, rx, ry = -1)`** -
  rounded rectangle; `ry` defaults to `rx` if omitted. Corner radii are
  clamped to half the rectangle's width/height so they can't overlap.
- **`gmvex_path_add_ellipse(path, cx, cy, rx, ry)`** /
  **`gmvex_path_add_circle(path, cx, cy, r)`** - closed ellipse/circle,
  built from two 180° arcs.
- **`gmvex_path_add_line(path, x1, y1, x2, y2)`** - a single open (never
  closed) two-point subpath.
- **`gmvex_path_add_polyline(path, points)`** - open multi-point line from
  an array of `[x,y]` pairs.
- **`gmvex_path_add_polygon(path, points)`** - same as `add_polyline`, but
  closed.

### `gmvex_path_arcto(path, rx, ry, x_axis_rotation, large_arc_flag, sweep_flag, x, y)`
Elliptical arc from the current point to `(x,y)`, using the same
parameterization as SVG's own `A` path command, anyone familiar with SVG
path syntax already knows this signature. Internally a direct
endpoint-to-center conversion, split into cubic Bézier segments (max 90°
of arc per segment for accuracy). Degenerate cases handled explicitly:
zero radius falls back to a straight line, and a zero-length arc (start
equals end) is a no-op.

---

## Transforms & Baking

See *Path local space vs. world placement* above for the core distinction
this section builds on.

### `gmvex_path_set_transform(path, x, y, rot = 0, xscale = 1, yscale = 1, origin_x = 0, origin_y = 0, shear_x = 0, shear_y = 0)`
Builds `path.tmatrix`, the path's world placement, applied only via the
GPU matrix at draw time. `origin_x`/`origin_y` is a pivot point (in local
space) that rotation/scale are applied around before translation.
`shear_x`/`shear_y` (degrees) compose as if shear were part of the scale
step, applied to the point before rotation/translate/pivot - matching
SVG's own ordering when several transform functions are listed together
in one `transform` attribute. `shear_y` applies before `shear_x` when
both are nonzero.

**This function only produces a proper (non-degenerate) matrix for
rotation, uniform-or-nonuniform scale, translation, and shear in any
combination.** It cannot represent true perspective/projective distortion
(the kind where parallel edges converge toward a vanishing point and a
far edge appears shorter than a near one) - that needs a 3×3 matrix and a
per-point division that has no equivalent here, or in SVG's own transform
syntax. For a shape that needs to look like it's leaning against another
already-sheared surface (a common technique in flat 2.5D/isometric-style
art), shear is the right tool; for a shape that needs to visibly recede
in true perspective, it is not, and there's no built-in feature that is -
see the caveat under `gmvex_path_apply_scale`/`_rotation` below for what
happens when a sheared path additionally needs baking, which is a
related but separate limitation.

### `gmvex_path_get_matrix(path)`
Builds and returns the GameMaker transform matrix from `path.tmatrix`.
Returns an identity matrix if the path has never had a transform set at
all (no `tmatrix` field exists), every draw function relies on this
fallback rather than requiring `gmvex_path_set_transform` to always be
called first.

### `gmvex_path_apply_position(path)` / `gmvex_path_apply_rotation(path)` / `gmvex_path_apply_scale(path)`
**Baking functions** - permanently write the current position (or
rotation, or scale) component of `path.tmatrix` into the path's actual
command coordinates, then reset that component to its identity value.
`apply_position` correctly accounts for whatever rotation/scale is
*still* in effect at the moment it's called (un-rotating/un-scaling the
translation before baking it in), so call order matters if baking
components individually.

`apply_scale` and `apply_rotation` both correctly preserve a reflection
(a negative scale factor along one axis - a Y-axis flip is the common
case, frequently produced by PDF-to-SVG export pipelines compensating
for PDF's inverted coordinate system) when baking.

**Neither function can bake true (non-orthogonal) shear.** Both are
built around a rotation-times-scale decomposition of `tmatrix` with no
third term for shear; a path whose matrix contains genuine shear (as
opposed to a reflection, which these functions do handle) passes through
either function's early-return check untouched, its shear component
simply remains sitting in `tmatrix` rather than being folded into the
path's actual point coordinates. This matters specifically because
`gmvex_path_boolean`, `gmvex_path_merge`, and clip-path/mask resolution
during SVG import all rely on baking to put two shapes into a shared
coordinate space before doing point-level geometry math on them - a
sheared shape going through any of those will have its shear silently
absent from that math, even though the same shape renders with its shear
completely correctly via a plain `gmvex_fill_draw`/`_stroke_draw` call,
since those apply `tmatrix` as a single GPU matrix with no decomposition
involved at all.

### `gmvex_path_apply_transform_all(path)`
Bakes all three components in one call, in scale → rotate → position
order. **This is the function to call before `gmvex_path_boolean`** if two
paths need to be combined based on where they're actually positioned in
the world, see the boolean-ops caveat below for what happens if this
step is skipped. Subject to the same true-shear limitation described
under `gmvex_path_apply_scale`/`_rotation` above.

---

## Groups

A `gmvex_group` composes transforms across a hierarchy of paths and nested
child groups, useful for moving/rotating/scaling a whole collection of
shapes together without touching each one's own transform individually.

### `gmvex_group_create()`
Returns a new, empty group with an identity transform.

### `gmvex_group_add_path(group, path)` / `gmvex_group_add_group(group, child_group)`
Adds a path or nested group as a member.

### `gmvex_group_set_transform(group, x, y, rot = 0, xscale = 1, yscale = 1, origin_x = 0, origin_y = 0, shear_x = 0, shear_y = 0)`
Same parameter shape as `gmvex_path_set_transform`, including the same
`shear_x`/`shear_y` parameters, for the group as a whole.

**Has no visible effect until `gmvex_group_resolve_transforms` is called
again** if paths have already been added to the group or it has already
been resolved once - this call only updates `group.gtmatrix` itself, it
does not walk the hierarchy and push the new value into member paths'
own `tmatrix`. That is a separate, required step; see
`gmvex_group_resolve_transforms` immediately below.

### `gmvex_group_resolve_transforms(group, ancestor_acc = undefined)`
**Must be called (recursively walks the whole hierarchy) before drawing**
for a group's transform to actually reach its member paths, nothing
about groups is automatic at draw time. On first resolve, each member
path's *own* original transform is cached (the same "snapshot once,
always derive from the snapshot" pattern used throughout this framework's
mask system) so repeated calls compose correctly against the path's true
authored position rather than compounding on top of whatever the previous
resolve already wrote. Recurses into nested groups, composing rotation
(additive), scale (multiplicative), and position (through the parent's
own rotation/scale) at each level. Correctly composes shear too, since
this composition is plain matrix multiplication with no decomposition
step involved.

---

## Hit Testing

Pure geometry, no GPU calls, safe to call from any context including
outside a Draw event. Both functions take **world-space** coordinates and
internally transform them into the path's local space via `path.tmatrix`
(plus `tox`/`toy`), correctly handling rotation and shear, so there's no
need to pre-transform the point yourself.

**Known limitation:** both functions' bounding-box early-out check
compares the incoming point directly against `path.bbox` before doing
the inverse-transform. `path.bbox` is local-space; the incoming point is
world-space per the functions' own contract. For a path with a nonzero
position, this can reject a valid hit that falls outside the local-space
bbox's numeric range even when the transformed point genuinely falls
inside the shape.

### `gmvex_path_hit_test_fill(path, px, py)`
Returns whether world point `(px,py)` falls inside the path's filled
area, respecting `path.winding` (even-odd or nonzero winding-number test,
matching exactly how the same path would rasterize via `gmvex_fill_draw`).
Fast bbox rejection before the full point-in-polygon test.

### `gmvex_path_hit_test_stroke(path, px, py, stroke_width, tolerance = 4)`
Returns whether world point `(px,py)` falls within `stroke_width/2 +
tolerance` of the path's outline (distance-to-segment test against every
flattened edge). `tolerance` exists to make thin strokes easier to click/
tap than their exact rendered width would allow.

---

## Dash Patterns

### `gmvex_stroke_set_dash(path, dash_array, dash_offset = 0)`
Sets a dash pattern for subsequent stroke draws. `dash_array` is an
array of on/off lengths (SVG `stroke-dasharray` semantics, an odd-length
array is automatically duplicated to make it even, same rule SVG itself
uses). `dash_offset` shifts where the pattern starts along the stroke's
length. Marks `path.stroke_dash_dirty`, which every stroke-drawing
function checks to know whether its cached stroke vertex buffer needs
rebuilding.

Every stroke-drawing function (`gmvex_stroke_draw` and all its masked/
gradient variants) checks for `path.dash_array` automatically, dashing
isn't a separate draw call, it's a property of the path that the normal
stroke functions respect if present.

---

## Fill Drawing

### `gmvex_fill_draw(path, col, alpha)`
Flat-color fill. Rebuilds if `path.dirty`, including when only
`global.gmvex_tolerance` has changed since the path was last built. No-op
if the path has no renderable geometry.

### `gmvex_fill_draw_masked(path, col, alpha)`
Flat-color fill with per-pixel alpha multiplied by an attached mask's
luminance (see **Masking** below). Falls back to `gmvex_fill_draw` if no
mask is attached or the mask surface couldn't be built, never silently
draws nothing.

### `gmvex_fill_draw_gradient(path, type, p0x, p0y, p1x, p1y, stops)`
Linear or radial gradient fill (`type` is `gmvex_gradient.LINEAR` or
`.RADIAL`). **`p0x/p0y/p1x/p1y` must be in the path's local/command space**
- not world coordinates. The gradient shader compares these against raw
pre-matrix vertex positions, the same convention as everything else in this
framework. Passing world-space coordinates here is the single most common
mistake when using this function directly, easy to make even knowing the
rule, since nothing about the call signature hints at which space is
expected. The symptom is every pixel clamping to a single stop color
instead of interpolating, since the projected `t` value ends up
permanently out of the `[0,1]` range.

`stops` is an array of `[position, color, alpha]` triples, position `0`–`1`.
**Maximum 32 stops.** This ceiling comes directly from the gradient
shaders' own fixed-size uniform arrays (`uniform vec4 u_stopColor[32]` /
`uniform float u_stopPos[32]`) - every gradient fill uploads the full
32-slot array per draw call regardless of how many stops that particular
gradient actually has, so this is a fixed per-draw-call cost paid even by
a basic 2-3 stop gradient.

### `gmvex_fill_draw_gradient_masked(path, grad_type, p0x, p0y, p1x, p1y, stops)`
Gradient fill combined with an attached mask. Same local-space coordinate
rule and 32-stop ceiling as `gmvex_fill_draw_gradient`. Internally renders
the gradient to a small intermediate surface (sized to the path's bbox)
unmasked, then composites through mask luminance, two-pass, not a single
combined shader.

---

## Stroke Drawing

### `gmvex_stroke_draw(path, width, col, alpha, join_mode, cap_mode, miter_limit)`
Flat-color stroke. `join_mode` is `gmvex_join.BEVEL/ROUND/MITER`, `cap_mode`
is `gmvex_cap.BUTT/ROUND/SQUARE`. Respects `path.dash_array`/`dash_offset`
if set. Rebuilds its cached stroke geometry on a width/join/cap change or
a `global.gmvex_tolerance` change since it was last built, tracked
independently of the fill-side cache since stroke geometry lives in its
own separate vertex buffer.

`gmvex_join.ROUND` and `gmvex_cap.ROUND` subdivide their curved geometry
based on `global.gmvex_tolerance` and the actual radius being drawn
(stroke half-width for both caps and round joins), solving for the
angular step that keeps the chord-to-arc deviation within tolerance
rather than using a fixed step count.

### `gmvex_stroke_draw_masked(path, width, col, alpha, join_mode, cap_mode, miter_limit)`
Stroke with mask luminance applied. **Important: mask sizing for strokes is
different from fills.** A stroke sits at the shape's *boundary*, not its
interior, a mask radius that comfortably covers a filled shape's center
can leave the boundary entirely outside the mask's coverage, making the
whole stroke invisible with no error, no warning, and geometry/vbuff/
uniform diagnostics all reporting perfectly healthy. A `r=60` mask circle
centered on a `140×140` rectangle's middle never comes within 10px of the
stroke sitting at that rectangle's edge. Across the coverage spectrum:
too small a radius masks out the entire stroke, a radius reaching only
edge midpoints (not corners) produces a correct partial result, and a
radius exceeding the corner distance shows the full outline. Size mask
geometry to actually reach the stroke's position, not just the fill's
interior. The mask surface itself is sized to the *fill* bbox, not
stroke-width-expanded, stroke pixels outside that range clamp to the
mask's nearest edge value.

### `gmvex_stroke_draw_gradient(path, width, grad_type, p0x, p0y, p1x, p1y, stops, join_mode, cap_mode, miter_limit)`
Gradient-colored stroke. Same local-space coordinate rule and 32-stop
ceiling as the fill gradient functions.

### `gmvex_stroke_draw_gradient_masked(path, width, grad_type, p0x, p0y, p1x, p1y, stops, join_mode, cap_mode, miter_limit)`
Gradient stroke with mask luminance. Same stroke-vs-fill mask sizing caveat
as `gmvex_stroke_draw_masked`.

---

## Masking

### `gmvex_path_set_mask(target_path, mask_content_path)`
Attaches `mask_content_path` as a luminance silhouette mask for
`target_path`. The mask content is force-filled white internally, **this
is a binary silhouette mask, not a true luminance mask.** The mask
content's own fill color, alpha, and any gradient are discarded; only its
*shape* matters. Any area the mask content covers becomes fully visible;
anywhere it doesn't becomes fully transparent. There is no soft-edged or
partial-transparency masking.

### `gmvex_mask_ensure_surface(path)`
Lazily builds/rebuilds the cached mask surface for `path`. Called
internally by every masked draw function, you generally don't need to
call this directly except for debugging (e.g. dumping the raw mask surface
to inspect it independently of how it's being sampled).

### Multi-shape masks
A single `gmvex_path` can represent multiple merged shapes as one mask by
combining their flattened geometry:

```gml
var combined = gmvex_svg_merge_paths_flat([shape_a, shape_b, shape_c]);
gmvex_path_set_mask(target, combined);
```

`gmvex_svg_merge_paths_flat` merges via each input's `flat_subpaths`
(post-flatten point loops), not `subpaths`, this matters because
`gmvex_path_boolean` results only ever populate `flat_subpaths`, so merging
via `subpaths` silently drops any boolean-op-derived input. Deep-copies
point data on merge, so it's safe to merge paths that get mutated
afterward (e.g. by clip-path's own boolean nudge).

**Limitation:** all merged content is forced to `NONZERO` winding
regardless of the individual pieces' own fill-rule, there is no way to
preserve mixed even-odd/nonzero fill-rules across merged mask content.

---

## Clip-Path

### `gmvex_path_boolean(path_a, path_c, op)`
Boolean combine two paths. `op` is `gmvex_bool.UNION/INTERSECTION/
A_NOT_C/C_NOT_A`. **Operates on raw local geometry only, ignores world
placement entirely.** Bake transforms in first with
`gmvex_path_apply_transform_all` if the two paths need to be combined based
on their world positions, or the operation will treat them as if both sat
at their untransformed local origin.

Confirmed working for circle-vs-circle intersection with transforms
correctly baked in first, including the specific failure mode this
produces when the baking step is skipped: two circles positioned apart in
the world but sharing identical local geometry collapse into a
near-zero-area degenerate sliver (a giveaway bbox centered near the
origin instead of near either circle's actual position), not an error or
a crash. Once `gmvex_path_apply_transform_all` is called on both inputs
first, the same two circles produce a correct lens-shaped intersection.
Also confirmed working directly for straight-edge-vs-curved-edge
combinations, such as a rectangle against a circle.

**Boundary of what's reliable: any operand with a non-convex (reflex,
inward-pointing) vertex can produce a "dangling arc end, no matching
start" warning and return an empty result**, even when neither shape is
tangent to the other and neither shares a coincident edge. This happens
because each boundary arc's inside/outside classification is tested
independently, via a single midpoint against the other shape, with no
cross-check against neighboring arcs; near a cluster of intersection
points close together around a reflex vertex, this can produce a set of
kept arcs that don't form a closed loop - a node with two arcs arriving
and none leaving, or the reverse. Two genuinely convex operands (two
circles, or a rectangle and a circle) do not exhibit this regardless of
how much or how little they overlap. If a shape used with this function
might be non-convex, test that specific combination before depending on
it; convex-vs-convex of any curve/line mix is solid.

A tiny fixed epsilon perturbation
(`gmvex_svg_shift_flat_subpaths(baked_c, 0.0173, 0.0091)`) is applied to
one operand immediately before the intersection-finding step, to break
exact numerical coincidence between the two operands before the
intersection math runs. Exactly-coincident or exactly-tangent geometry
(a circle inscribed perfectly inside a square, radius exactly half the
square's width, both centered at the same point, is a clean example) is
a classic degenerate case for polygon-clipping algorithms in general,
because floating-point rounding at the point of exact contact can
inconsistently place a crossing just inside or just outside depending on
which side of the tangent point is being evaluated. This same protection
covers `gmvex_path_boolean` directly, not just paths that arrive via
SVG clip-path import.

---

## SVG Import

### `gmvex_svg_import(filename)`
Full-featured entry point. Returns `{ group, results, doc_width,
doc_height }`. `results` is a flat array of `{ path, fill_color,
fill_alpha, fill_gradient, stroke_color, stroke_width, stroke_alpha,
has_fill, has_stroke, stroke_gradient, join_mode, cap_mode, dash_array,
dash_offset, ... }`.

**Known leak:** `gmvex_svg_import` never destroys its own internal
`gradient_map`/`id_map` after use.

### `gmvex_svg_draw_fill(result)` / `gmvex_svg_draw_stroke(result)`
Convenience draw dispatchers, check `has_fill`/`has_stroke` and
automatically route to the correct underlying draw function (plain,
masked, gradient, or gradient+masked) based on what the result actually
has. Use these instead of calling the underlying draw functions directly
when working with `gmvex_svg_import` results.

### Supported `<mask>`/`<clipPath>` features
- Multiple child shapes (merged, not just the first)
- `maskContentUnits`/`clipPathUnits` = `objectBoundingBox` or
  `userSpaceOnUse` (default)
- Nesting, a mask's content may itself have a `clip-path`, and vice versa,
  up to a depth-16 recursion guard (circular-reference protection)
- **`clip-path`/`mask` on a `<g>` element, applying to everything inside
  it as a group.** The group's own descendants are collected and
  individually clipped/masked against the referenced shape before the
  group's own transform is composed onto them, so clipping composes
  correctly with everything nested inside the clipped group.
  `objectBoundingBox` units are not supported for this group-level case
  (only `userSpaceOnUse`) - a group doesn't have a single unambiguous
  target bounding box the way one leaf shape does.

### Shear transforms
`skewX(angle)` and `skewY(angle)` are parsed and applied correctly, both
directly on a shape or group and composed through nested groups and
`<use>`.

`<use>` referencing an element whose *own* `transform` attribute contains
genuine non-orthogonal shear has that referenced transform dropped
entirely (not just the shear component - the whole thing, including any
rotation/scale bundled into the same matrix) rather than composed. This
is a deliberately conservative fallback in the matrix-decomposition
helper used for this specific composition step - it avoids corrupting the
result rather than mis-composing it, at the cost of dropping the
transform outright when it can't be safely represented. Reflections (a
Y-axis flip, common from PDF-derived SVG exports) composed through
`<use>` are correctly distinguished from genuine shear and compose
normally; only actual non-orthogonal shear hits this fallback.

For the deeper reason shear can still be dropped for boolean ops,
clip-path/mask resolution, and path merging specifically (as opposed to
plain rendering, which is unaffected), see the true-shear limitation
noted under `gmvex_path_apply_scale`/`_rotation` in *Transforms & Baking*
above - clip-path and mask resolution during SVG import both rely on that
same baking step internally, so a shape under a genuinely (non-
orthogonally) sheared ancestor that also needs clip-path or mask
resolution can still be affected, even though the shear composes and
renders correctly for everything else.

### Not supported
- **CFF/OTF outlines** for `<text>`/font-related SVG content, same
  limitation as the font loader below.
- `gmvex_svg_walk_element`/`gmvex_svg_walk_element_grouped` (simpler,
  older entry points) only see gradients/ids within whatever element
  subtree they're handed, not the full document, a `<defs>` sibling
  outside that subtree is invisible to them. Prefer `gmvex_svg_import` for
  anything beyond a self-contained fragment.
- `<tspan>`/text-in-SVG handling, `<symbol>` edge cases, and
  viewBox-scaling interaction with transforms have not been specifically
  stress-tested.

---

## Text / Font Rendering

### `gmvex_text_font_load(filename)`
Loads a **TrueType (`glyf`/`loca`)** font. Returns `undefined` and logs a
message on failure. **CFF outlines are explicitly rejected**, a font file
with a `.otf` extension will load fine if it happens to contain `glyf`/
`loca` data (this loader checks table presence, not the file extension),
but will be rejected if its outlines are CFF-encoded, which is what most
`.otf` files actually contain.

`cmap` subtable formats 0, 4, 6, and 12 are supported (format 4 preferred
when present; format 12 picked up as a fallback for fonts needing full
Unicode beyond the Basic Multilingual Plane). Any other format is rejected
at load time.

Kerning (`kern` table, **format 0 only**, the legacy pair-adjustment
format) and ligatures (`GSUB`, **Lookup Type 4 only**, direct ligature
substitution, no contextual/chaining variants) are parsed automatically if
present; check `font.kern_pairs_offset != -1` and
`array_length(font.liga_lookups) > 0` to know whether a given font actually
has either. **`GPOS`-based kerning is not supported**, most modern fonts
use `GPOS` instead of the legacy `kern` table, so `kern_pairs_offset == -1`
on a contemporary font is expected, not a bug.

### `gmvex_text_to_paths(font, text, size, x, y)`
Lays out `text` and returns an array of `{ path, char, line }`, one entry
per rendered glyph (fewer than the character count if ligatures fired).
Applies kerning and ligature substitution automatically when the loaded
font has the relevant tables. Handles composite glyphs (accented
characters built from a base + mark component) including component-level
scale/rotation transforms.

Note: `italic_shear`, used elsewhere in this pipeline to synthesize a
fake-italic slant when a font has no true italic variant, is unrelated to
the shear transform described above - it shears glyph contour points
directly at build time as plain local-space geometry, not through
`tmatrix`.

### `gmvex_text_measure_width(font, text, size, letter_spacing)`
Returns total advance width, applying the same kerning/ligature logic as
`gmvex_text_to_paths`, required so centered/right-aligned text measures
consistently with how it actually renders.
