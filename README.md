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
gmvex_set_tolerance(0.1); // 0.5 by default
var path = gmvex_path_create();
gmvex_path_moveto(path, 0, 0);
gmvex_path_lineto(path, 100, 0);
gmvex_path_quadto(path, 50, 50, 100, 100);
gmvex_path_close(path);

// Draw
gmvex_fill_draw(path, c_red, 1);

// Cleanup
gmvex_path_destroy(path);
```

## Limitations/Constraints

- TrueType fonts only (no CFF or OTF)
- No text rendering without font files
- No shear support in SVG transforms
- Gradient stops limited to 8
