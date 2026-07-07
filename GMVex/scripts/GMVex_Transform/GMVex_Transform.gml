function gmvex_path_set_transform(path, x, y, rot = 0, xscale = 1, yscale = 1, origin_x = 0, origin_y = 0) {
    path.tx = x;
    path.ty = y;
    path.trot = rot;
    path.txscale = xscale;
    path.tyscale = yscale;
    path.tox = origin_x;
    path.toy = origin_y;
}

function gmvex_path_get_matrix(path) {
    if (!variable_struct_exists(path, "tx")) return matrix_build_identity();

    var m = matrix_build(
        path.tx, path.ty, 0,
        0, 0, path.trot,
        path.txscale, path.tyscale, 1
    );

    if (path.tox != 0 || path.toy != 0) {
        var pivot = matrix_build(-path.tox, -path.toy, 0, 0,0,0, 1,1,1);
        m = matrix_multiply(pivot, m);
    }

    return m;
}

function gmvex_apply_transform_offset_command(cmd, dx, dy) {
    if (cmd.type == gmvex_cmd.MOVETO || cmd.type == gmvex_cmd.LINETO) {
        cmd.x += dx; cmd.y += dy;
    } else if (cmd.type == gmvex_cmd.QUADTO) {
        cmd.cx += dx; cmd.cy += dy;
        cmd.x += dx; cmd.y += dy;
    } else if (cmd.type == gmvex_cmd.CUBICTO) {
        cmd.c1x += dx; cmd.c1y += dy;
        cmd.c2x += dx; cmd.c2y += dy;
        cmd.x += dx; cmd.y += dy;
    }
}

function gmvex_apply_transform_scale_command(cmd, scale_x, scale_y) {
    if (cmd.type == gmvex_cmd.MOVETO || cmd.type == gmvex_cmd.LINETO) {
        cmd.x *= scale_x; cmd.y *= scale_y;
    } else if (cmd.type == gmvex_cmd.QUADTO) {
        cmd.cx *= scale_x; cmd.cy *= scale_y;
        cmd.x *= scale_x; cmd.y *= scale_y;
    } else if (cmd.type == gmvex_cmd.CUBICTO) {
        cmd.c1x *= scale_x; cmd.c1y *= scale_y;
        cmd.c2x *= scale_x; cmd.c2y *= scale_y;
        cmd.x *= scale_x; cmd.y *= scale_y;
    }
}

function gmvex_apply_transform_rotate_command(cmd, deg) {
    var rad = degtorad(deg);
    var cs = cos(rad), sn = sin(rad);
    if (cmd.type == gmvex_cmd.MOVETO || cmd.type == gmvex_cmd.LINETO) {
        var nx = cmd.x*cs - cmd.y*sn;
        var ny = cmd.x*sn + cmd.y*cs;
        cmd.x = nx; cmd.y = ny;
    } else if (cmd.type == gmvex_cmd.QUADTO) {
        var ncx = cmd.cx*cs - cmd.cy*sn;
        var ncy = cmd.cx*sn + cmd.cy*cs;
        var nx = cmd.x*cs - cmd.y*sn;
        var ny = cmd.x*sn + cmd.y*cs;
        cmd.cx = ncx; cmd.cy = ncy;
        cmd.x = nx; cmd.y = ny;
    } else if (cmd.type == gmvex_cmd.CUBICTO) {
        var nc1x = cmd.c1x*cs - cmd.c1y*sn;
        var nc1y = cmd.c1x*sn + cmd.c1y*cs;
        var nc2x = cmd.c2x*cs - cmd.c2y*sn;
        var nc2y = cmd.c2x*sn + cmd.c2y*cs;
        var nx = cmd.x*cs - cmd.y*sn;
        var ny = cmd.x*sn + cmd.y*cs;
        cmd.c1x = nc1x; cmd.c1y = nc1y;
        cmd.c2x = nc2x; cmd.c2y = nc2y;
        cmd.x = nx; cmd.y = ny;
    }
}

function gmvex_apply_transform_walk(path, offset_fn, scale_fn, rotate_fn) {
    for (var s = 0; s < array_length(path.subpaths); s++) {
        var sp = path.subpaths[s];
        for (var c = 0; c < array_length(sp.commands); c++) {
            var cmd = sp.commands[c];
            if (!is_undefined(offset_fn)) offset_fn(cmd);
            if (!is_undefined(scale_fn)) scale_fn(cmd);
            if (!is_undefined(rotate_fn)) rotate_fn(cmd);
        }
        if (variable_struct_exists(sp, "splinepts")) {
            for (var p = 0; p < array_length(sp.splinepts); p++) {
                var pt = sp.splinepts[p];
                if (!is_undefined(offset_fn)) offset_fn({x: pt[0], y: pt[1]});
            }
        }
    }
}

function gmvex_path_apply_position(path) {
    if (!variable_struct_exists(path, "tx")) return;

    var trot = variable_struct_exists(path, "trot") ? path.trot : 0;
    var txscale = variable_struct_exists(path, "txscale") ? path.txscale : 1;
    var tyscale = variable_struct_exists(path, "tyscale") ? path.tyscale : 1;

    var rad = degtorad(-trot);
    var cs = cos(rad), sn = sin(rad);
    var undo_rot_x = path.tx*cs - path.ty*sn;
    var undo_rot_y = path.tx*sn + path.ty*cs;
    var dx = (txscale != 0) ? undo_rot_x / txscale : 0;
    var dy = (tyscale != 0) ? undo_rot_y / tyscale : 0;

    for (var s = 0; s < array_length(path.subpaths); s++) {
        var sp = path.subpaths[s];
        for (var c = 0; c < array_length(sp.commands); c++) {
            gmvex_apply_transform_offset_command(sp.commands[c], dx, dy);
        }
        if (variable_struct_exists(sp, "splinepts")) {
            for (var p = 0; p < array_length(sp.splinepts); p++) {
                sp.splinepts[p][0] += dx;
                sp.splinepts[p][1] += dy;
            }
        }
    }

    path.tx = 0;
    path.ty = 0;
    path.dirty = true;
    if (variable_struct_exists(path, "stroke_vbuff")) path.stroke_dash_dirty = true;
}

function gmvex_path_apply_rotation(path) {
    if (!variable_struct_exists(path, "trot") || path.trot == 0) return;

    var trot = path.trot;
    for (var s = 0; s < array_length(path.subpaths); s++) {
        var sp = path.subpaths[s];
        for (var c = 0; c < array_length(sp.commands); c++) {
            gmvex_apply_transform_rotate_command(sp.commands[c], trot);
        }
        if (variable_struct_exists(sp, "splinepts")) {
            var rad = degtorad(trot);
            var cs = cos(rad), sn = sin(rad);
            for (var p = 0; p < array_length(sp.splinepts); p++) {
                var px = sp.splinepts[p][0], py = sp.splinepts[p][1];
                sp.splinepts[p][0] = px*cs - py*sn;
                sp.splinepts[p][1] = px*sn + py*cs;
            }
        }
    }

    path.trot = 0;
    path.dirty = true;
    if (variable_struct_exists(path, "stroke_vbuff")) path.stroke_dash_dirty = true;
}

function gmvex_path_apply_scale(path) {
    if (!variable_struct_exists(path, "txscale")) return;
    var sx = path.txscale;
    var sy = variable_struct_exists(path, "tyscale") ? path.tyscale : 1;
    if (sx == 1 && sy == 1) return;

    for (var s = 0; s < array_length(path.subpaths); s++) {
        var sp = path.subpaths[s];
        for (var c = 0; c < array_length(sp.commands); c++) {
            gmvex_apply_transform_scale_command(sp.commands[c], sx, sy);
        }
        if (variable_struct_exists(sp, "splinepts")) {
            for (var p = 0; p < array_length(sp.splinepts); p++) {
                sp.splinepts[p][0] *= sx;
                sp.splinepts[p][1] *= sy;
            }
        }
    }

    path.txscale = 1;
    path.tyscale = 1;
    path.dirty = true;
    if (variable_struct_exists(path, "stroke_vbuff")) path.stroke_dash_dirty = true;
}

function gmvex_path_apply_transform_all(path) {
    gmvex_path_apply_scale(path);
    gmvex_path_apply_rotation(path);
    gmvex_path_apply_position(path);
}