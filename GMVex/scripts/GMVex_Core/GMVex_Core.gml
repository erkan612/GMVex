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

function gmvex_path_create() {
    return {
        subpaths : [],
        current  : -1,
        dirty    : true,
        vbuff    : -1,
        bbox     : [0, 0, 0, 0],
        winding  : gmvex_winding.NONZERO,
    };
}

function gmvex_path_destroy(path) {
    if (path.vbuff != -1) vertex_delete_buffer(path.vbuff);
    path.vbuff = -1;
    if (variable_struct_exists(path, "vbuff_cw") && path.vbuff_cw != -1) vertex_delete_buffer(path.vbuff_cw);
    path.vbuff_cw = -1;
    if (variable_struct_exists(path, "stroke_vbuff") && path.stroke_vbuff != -1) {
        vertex_delete_buffer(path.stroke_vbuff);
    }
}