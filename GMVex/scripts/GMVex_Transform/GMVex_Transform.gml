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