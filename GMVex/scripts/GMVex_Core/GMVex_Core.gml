function gmvex_init() {
    vertex_format_begin();
    vertex_format_add_position_3d();
    global.gmvex_vformat_pos = vertex_format_end();

    vertex_format_begin();
    vertex_format_add_position_3d();
    vertex_format_add_colour();
    vertex_format_add_texcoord();
    global.gmvex_vformat_full = vertex_format_end();

    global.gmvex_tolerance = 0.5;
}

function gmvex_set_tolerance(tol) {
    global.gmvex_tolerance = tol;
}