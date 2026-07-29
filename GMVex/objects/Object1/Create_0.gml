gmvex_init();

// many editor fails to import this svg file properly
// the file has incomplete shapes/arts outside the bounds
// that is why it looks broken in the outside, thats how its designed.
complex_svg = gmvex_svg_import("yayangart-flowers.svg");
//gmvex_group_set_transform(complex_svg.group, 0, 0, 0, 0.5, 0.5);
//gmvex_group_resolve_transforms(complex_svg.group);