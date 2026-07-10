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

    if (variable_struct_exists(path, "mask_surface") && surface_exists(path.mask_surface)) {
        surface_free(path.mask_surface);
    }
    path.mask_surface = -1;
    if (variable_struct_exists(path, "mask_path") && !is_undefined(path.mask_path)) {
        gmvex_path_destroy(path.mask_path);
    }
	if (variable_struct_exists(path, "gradmask_surf") && surface_exists(path.gradmask_surf)) surface_free(path.gradmask_surf);
}

function gmvex_path_set_mask(path, mask_path) {
    path.mask_path = mask_path;
    path.mask_dirty = true;
    if (!variable_struct_exists(path, "mask_surface")) {
        path.mask_surface = -1;
        path.mask_surface_w = 0;
        path.mask_surface_h = 0;
    }
}

function gmvex_path_mark_mask_dirty(path) {
    if (variable_struct_exists(path, "mask_dirty")) path.mask_dirty = true;
}

function gmvex_path_clone(path) {
    var clone = gmvex_path_create();
    clone.winding = path.winding;

    for (var s = 0; s < array_length(path.subpaths); s++) {
        var sp = path.subpaths[s];
        var new_commands = [];
        for (var c = 0; c < array_length(sp.commands); c++) {
            new_commands[c] = variable_clone(sp.commands[c]);
        }
        var new_sp = { commands: new_commands, closed: sp.closed };
        if (variable_struct_exists(sp, "splinepts")) {
            var new_splinepts = [];
            for (var p = 0; p < array_length(sp.splinepts); p++) {
                new_splinepts[p] = [sp.splinepts[p][0], sp.splinepts[p][1]];
            }
            new_sp.splinepts = new_splinepts;
        }
        array_push(clone.subpaths, new_sp);
    }
    clone.current = path.current;

    if (variable_struct_exists(path, "tx")) {
        gmvex_path_set_transform(clone, path.tx, path.ty, path.trot, path.txscale, path.tyscale, path.tox, path.toy);
    }

    return clone;
}

function gmvex_mask_ensure_surface(path) {
    if (!variable_struct_exists(path, "mask_path") || is_undefined(path.mask_path)) return -1;

    if (path.dirty) gmvex_path_rebuild(path);
    var bbox = path.bbox;
    var needed_w = ceil(max(bbox[2] - bbox[0], 1));
    var needed_h = ceil(max(bbox[3] - bbox[1], 1));

    var needs_rebuild = !surface_exists(path.mask_surface)
        || path.mask_dirty
        || path.mask_surface_w != needed_w
        || path.mask_surface_h != needed_h;

    if (needs_rebuild) {
        if (surface_exists(path.mask_surface)) surface_free(path.mask_surface);
        path.mask_surface = surface_create(needed_w, needed_h);
        path.mask_surface_w = needed_w;
        path.mask_surface_h = needed_h;

        var mp = path.mask_path;

        if (!variable_struct_exists(mp, "mask_orig_tx")) {
            mp.mask_orig_tx      = variable_struct_exists(mp, "tx")      ? mp.tx      : 0;
            mp.mask_orig_ty      = variable_struct_exists(mp, "ty")      ? mp.ty      : 0;
            mp.mask_orig_trot    = variable_struct_exists(mp, "trot")    ? mp.trot    : 0;
            mp.mask_orig_txscale = variable_struct_exists(mp, "txscale") ? mp.txscale : 1;
            mp.mask_orig_tyscale = variable_struct_exists(mp, "tyscale") ? mp.tyscale : 1;
            mp.mask_orig_tox     = variable_struct_exists(mp, "tox")     ? mp.tox     : 0;
            mp.mask_orig_toy     = variable_struct_exists(mp, "toy")     ? mp.toy     : 0;
        }

        surface_set_target(path.mask_surface);
        draw_clear_alpha(c_black, 1);
        gmvex_path_set_transform(
            mp,
            mp.mask_orig_tx - bbox[0], mp.mask_orig_ty - bbox[1],
            mp.mask_orig_trot, mp.mask_orig_txscale, mp.mask_orig_tyscale,
            mp.mask_orig_tox, mp.mask_orig_toy
        );
        if (mp.dirty) gmvex_path_rebuild(mp);
        gmvex_fill_draw(mp, c_white, 1);
        surface_reset_target();

        gmvex_path_set_transform(
            mp,
            mp.mask_orig_tx, mp.mask_orig_ty,
            mp.mask_orig_trot, mp.mask_orig_txscale, mp.mask_orig_tyscale,
            mp.mask_orig_tox, mp.mask_orig_toy
        );

        path.mask_dirty = false;
    }

    return path.mask_surface;
}

function gmvex_path_merge(paths) {
    var combined = gmvex_path_create();
    combined.subpaths = [];
    combined.flat_subpaths = [];
    var minx = infinity, miny = infinity, maxx = -infinity, maxy = -infinity;
    var any = false;

    for (var i = 0; i < array_length(paths); i++) {
        var baked = gmvex_path_clone(paths[i]);
        gmvex_path_apply_transform_all(baked);
        gmvex_path_rebuild(baked);

        for (var s = 0; s < array_length(baked.flat_subpaths); s++) {
            var src_pts = baked.flat_subpaths[s].points;
            var pts_copy = array_create(array_length(src_pts));
            for (var p = 0; p < array_length(src_pts); p++) {
                pts_copy[p] = [src_pts[p][0], src_pts[p][1]];
            }
            array_push(combined.flat_subpaths, { points: pts_copy, closed: baked.flat_subpaths[s].closed });
            any = true;
            for (var p = 0; p < array_length(pts_copy); p++) {
                minx = min(minx, pts_copy[p][0]); maxx = max(maxx, pts_copy[p][0]);
                miny = min(miny, pts_copy[p][1]); maxy = max(maxy, pts_copy[p][1]);
            }
        }

        gmvex_path_destroy(baked);
    }
    if (!any) return undefined;

    combined.bbox = [minx, miny, maxx, maxy];
    combined.dirty = false;
    gmvex_bool_rebuild_vbuff_from_flat(combined);
    return combined;
}