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