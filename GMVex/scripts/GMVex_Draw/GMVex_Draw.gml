function gmvex_fill_draw(path, col, alpha) {
    if (path.dirty) gmvex_path_rebuild(path);
    if (path.vbuff == -1 && path.vbuff_cw == -1) return;

    var mat = gmvex_path_get_matrix(path);
    var prev_mat = matrix_get(matrix_world);
    matrix_set(matrix_world, mat);

    gpu_set_stencil_enable(true);
    gpu_set_colorwriteenable(false, false, false, false);
    gpu_set_zwriteenable(false);
    gpu_set_stencil_func(cmpfunc_always);
    gpu_set_stencil_ref(0);

    if (path.winding == gmvex_winding.EVENODD) {
        gpu_set_stencil_fail(stencilop_keep);
        gpu_set_stencil_depth_fail(stencilop_keep);
        gpu_set_stencil_pass(stencilop_invert);
        if (path.vbuff != -1) vertex_submit(path.vbuff, pr_trianglelist, -1);
    } else {
        gpu_set_stencil_fail(stencilop_keep);
        gpu_set_stencil_depth_fail(stencilop_keep);
        gpu_set_stencil_pass(stencilop_incr);
        if (path.vbuff != -1) vertex_submit(path.vbuff, pr_trianglelist, -1);
        gpu_set_stencil_pass(stencilop_decr);
        if (path.vbuff_cw != -1) vertex_submit(path.vbuff_cw, pr_trianglelist, -1);
    }

    gpu_set_colorwriteenable(true, true, true, true);
    gpu_set_stencil_func(cmpfunc_notequal);
    gpu_set_stencil_ref(0);
    gpu_set_stencil_fail(stencilop_zero);
    gpu_set_stencil_depth_fail(stencilop_zero);
    gpu_set_stencil_pass(stencilop_zero);

    draw_set_color(col);
    draw_set_alpha(alpha);
    draw_rectangle(path.bbox[0], path.bbox[1], path.bbox[2], path.bbox[3], false);
    draw_set_alpha(1);

    gpu_set_stencil_enable(false);
    gpu_set_zwriteenable(true);

    matrix_set(matrix_world, prev_mat);
}

function gmvex_stroke_vertex(vb, x, y, col, a, u = 0, v = 0) {
    vertex_position_3d(vb, x, y, 0);
    vertex_colour(vb, col, a);
    vertex_texcoord(vb, u, v);
}

function gmvex_stroke_draw(path, width, col, alpha, join_mode = gmvex_join.BEVEL, cap_mode = gmvex_cap.BUTT, miter_limit = 4) {
    if (path.dirty) gmvex_path_rebuild(path);

    var needs_rebuild = !variable_struct_exists(path, "stroke_vbuff")
        || path.stroke_vbuff == -1
        || !variable_struct_exists(path, "stroke_width") || path.stroke_width != width
        || !variable_struct_exists(path, "stroke_join")  || path.stroke_join != join_mode
        || !variable_struct_exists(path, "stroke_cap")   || path.stroke_cap != cap_mode
        || (variable_struct_exists(path, "stroke_dash_dirty") && path.stroke_dash_dirty);

    if (needs_rebuild) {
        if (variable_struct_exists(path, "stroke_vbuff") && path.stroke_vbuff != -1) {
            vertex_delete_buffer(path.stroke_vbuff);
        }

        var hw = width / 2;
        var vb = vertex_create_buffer();
        vertex_begin(vb, global.gmvex_vformat_full);

        var has_dash = variable_struct_exists(path, "dash_array") && array_length(path.dash_array) > 0;
        var dash_norm = has_dash ? gmvex_dash_normalize_array(path.dash_array) : [];
        var dash_offset = variable_struct_exists(path, "dash_offset") ? path.dash_offset : 0;

        var placeholder_col = c_white;
        var placeholder_alpha = 1;

        for (var s = 0; s < array_length(path.flat_subpaths); s++) {
            var sub    = path.flat_subpaths[s];
            var pts    = sub.points;
            var closed = sub.closed;
            if (array_length(pts) < 2) continue;

            if (!has_dash) {
                gmvex_stroke_emit_polyline(vb, pts, closed, placeholder_col, placeholder_alpha, join_mode, cap_mode, miter_limit, hw);
            } else {
                var seg_count = closed ? array_length(pts) : array_length(pts) - 1;
                var total_len = 0;
                for (var i = 0; i < seg_count; i++) {
                    var p0 = pts[i]; var p1 = pts[(i + 1) mod array_length(pts)];
                    total_len += point_distance(p0[0], p0[1], p1[0], p1[1]);
                }

                var intervals = gmvex_dash_build_intervals(total_len, dash_norm, dash_offset);
                for (var iv = 0; iv < array_length(intervals); iv++) {
                    var a = intervals[iv][0], b = intervals[iv][1];
                    var chunk = gmvex_stroke_extract_range(pts, closed, a, b);
                    chunk = gmvex_stroke_dedupe_points(chunk);
                    if (array_length(chunk) >= 2) {
                        gmvex_stroke_emit_polyline(vb, chunk, false, placeholder_col, placeholder_alpha, join_mode, cap_mode, miter_limit, hw);
                    }
                }
            }
        }

        vertex_end(vb);
        vertex_freeze(vb);

        path.stroke_vbuff = vb;
        path.stroke_width = width;
        path.stroke_join  = join_mode;
        path.stroke_cap   = cap_mode;
        path.stroke_dash_dirty = false;
    }

    var mat = gmvex_path_get_matrix(path);
    var prev_mat = matrix_get(matrix_world);
    matrix_set(matrix_world, mat);

    shader_set(GMVEX_SOLID_COLOR);
    shader_set_uniform_f(shader_get_uniform(GMVEX_SOLID_COLOR, "u_color"),
        color_get_red(col)/255, color_get_green(col)/255, color_get_blue(col)/255, alpha);

    gpu_set_zwriteenable(false);
    vertex_submit(path.stroke_vbuff, pr_trianglelist, -1);
    gpu_set_zwriteenable(true);

    shader_reset();

    matrix_set(matrix_world, prev_mat);
}

function gmvex_fill_draw_masked(path, col, alpha) {
    var mask_surf = gmvex_mask_ensure_surface(path);
    if (mask_surf == -1) {
        gmvex_fill_draw(path, col, alpha);
        return;
    }

    if (path.dirty) gmvex_path_rebuild(path);
    if (path.vbuff == -1 && path.vbuff_cw == -1) return;

    var mat = gmvex_path_get_matrix(path);
    var prev_mat = matrix_get(matrix_world);
    matrix_set(matrix_world, mat);

    gpu_set_stencil_enable(true);
    gpu_set_colorwriteenable(false, false, false, false);
    gpu_set_zwriteenable(false);
    gpu_set_stencil_func(cmpfunc_always);
    gpu_set_stencil_ref(0);

    if (path.winding == gmvex_winding.EVENODD) {
        gpu_set_stencil_fail(stencilop_keep);
        gpu_set_stencil_depth_fail(stencilop_keep);
        gpu_set_stencil_pass(stencilop_invert);
        if (path.vbuff != -1) vertex_submit(path.vbuff, pr_trianglelist, -1);
    } else {
        gpu_set_stencil_fail(stencilop_keep);
        gpu_set_stencil_depth_fail(stencilop_keep);
        gpu_set_stencil_pass(stencilop_incr);
        if (path.vbuff != -1) vertex_submit(path.vbuff, pr_trianglelist, -1);
        gpu_set_stencil_pass(stencilop_decr);
        if (path.vbuff_cw != -1) vertex_submit(path.vbuff_cw, pr_trianglelist, -1);
    }

    gpu_set_colorwriteenable(true, true, true, true);
    gpu_set_stencil_func(cmpfunc_notequal);
    gpu_set_stencil_ref(0);
    gpu_set_stencil_fail(stencilop_zero);
    gpu_set_stencil_depth_fail(stencilop_zero);
    gpu_set_stencil_pass(stencilop_zero);

    shader_set(GMVEX_MASK_LUMINANCE);
    shader_set_uniform_f(shader_get_uniform(GMVEX_MASK_LUMINANCE, "u_bbox"),
        path.bbox[0], path.bbox[1], path.bbox[2], path.bbox[3]);
    shader_set_uniform_f(shader_get_uniform(GMVEX_MASK_LUMINANCE, "u_color"),
        color_get_red(col)/255, color_get_green(col)/255, color_get_blue(col)/255, alpha);
    texture_set_stage(shader_get_sampler_index(GMVEX_MASK_LUMINANCE, "u_mask"), surface_get_texture(mask_surf));
    draw_rectangle(path.bbox[0], path.bbox[1], path.bbox[2], path.bbox[3], false);
    shader_reset();

    gpu_set_stencil_enable(false);
    gpu_set_zwriteenable(true);

    matrix_set(matrix_world, prev_mat);
}