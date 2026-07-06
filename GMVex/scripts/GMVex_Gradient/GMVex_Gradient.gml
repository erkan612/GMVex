function gmvex_fill_draw_gradient(path, type, p0x, p0y, p1x, p1y, stops) {
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

    var shd = (type == gmvex_gradient.LINEAR) ? GMVEX_GRADIENT_LINEAR : GMVEX_GRADIENT_RADIAL;
    shader_set(shd);

    if (type == gmvex_gradient.LINEAR) {
        shader_set_uniform_f(shader_get_uniform(shd, "u_gradStart"), p0x, p0y);
        shader_set_uniform_f(shader_get_uniform(shd, "u_gradEnd"), p1x, p1y);
    } else {
        shader_set_uniform_f(shader_get_uniform(shd, "u_gradCenter"), p0x, p0y);
        shader_set_uniform_f(shader_get_uniform(shd, "u_gradRadius"), p1x);
    }

    var stop_count = min(array_length(stops), 8);
    var pos_arr = array_create(8, 0);
    var col_arr = array_create(32, 0);
    for (var i = 0; i < stop_count; i++) {
        pos_arr[i] = stops[i][0];
        col_arr[i*4+0] = color_get_red(stops[i][1]) / 255;
        col_arr[i*4+1] = color_get_green(stops[i][1]) / 255;
        col_arr[i*4+2] = color_get_blue(stops[i][1]) / 255;
        col_arr[i*4+3] = stops[i][2];
    }
    shader_set_uniform_i(shader_get_uniform(shd, "u_stopCount"), stop_count);
    shader_set_uniform_f_array(shader_get_uniform(shd, "u_stopPos"), pos_arr);
    shader_set_uniform_f_array(shader_get_uniform(shd, "u_stopColor"), col_arr);

    draw_rectangle(path.bbox[0], path.bbox[1], path.bbox[2], path.bbox[3], false);

    shader_reset();

    gpu_set_stencil_enable(false);
    gpu_set_zwriteenable(true);

    matrix_set(matrix_world, prev_mat);
}