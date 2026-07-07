function gmvex_group_create() {
    return {
        members: [],
        gx: 0, gy: 0, grot: 0, gxscale: 1, gyscale: 1,
        gorigin_x: 0, gorigin_y: 0
    };
}

function gmvex_group_add_path(group, path) {
    array_push(group.members, { kind: "path", ref: path });
}

function gmvex_group_add_group(group, child_group) {
    array_push(group.members, { kind: "group", ref: child_group });
}

function gmvex_group_set_transform(group, x, y, rot = 0, xscale = 1, yscale = 1, origin_x = 0, origin_y = 0) {
    group.gx = x; group.gy = y; group.grot = rot;
    group.gxscale = xscale; group.gyscale = yscale;
    group.gorigin_x = origin_x; group.gorigin_y = origin_y;
}

function gmvex_group_compose_point(acc, px, py) {
    var lx = (px - acc.gorigin_x) * acc.gxscale;
    var ly = (py - acc.gorigin_y) * acc.gyscale;
    var rad = degtorad(acc.grot);
    var cos_r = cos(rad);
    var sin_r = sin(rad);
    var rx = lx * cos_r - ly * sin_r;
    var ry = lx * sin_r + ly * cos_r;
    return [acc.gx + rx, acc.gy + ry];
}

function gmvex_group_compose_accumulated(acc, group) {
    var new_origin = gmvex_group_compose_point(acc, group.gx, group.gy);
    return {
        gx: new_origin[0], gy: new_origin[1],
        grot: acc.grot + group.grot,
        gxscale: acc.gxscale * group.gxscale,
        gyscale: acc.gyscale * group.gyscale,
        gorigin_x: group.gorigin_x, gorigin_y: group.gorigin_y
    };
}

function gmvex_group_resolve_transforms(group, ancestor_acc = undefined) {
    if (is_undefined(ancestor_acc)) {
        ancestor_acc = { gx: 0, gy: 0, grot: 0, gxscale: 1, gyscale: 1, gorigin_x: 0, gorigin_y: 0 };
    }
    var acc = gmvex_group_compose_accumulated(ancestor_acc, group);

    var n = array_length(group.members);
    for (var i = 0; i < n; i++) {
        var member = group.members[i];
        if (member.kind == "group") {
            gmvex_group_resolve_transforms(member.ref, acc);
        } else {
            var path = member.ref;
            if (!variable_struct_exists(path, "group_orig_tx")) {
                path.group_orig_tx = variable_struct_exists(path, "tx") ? path.tx : 0;
                path.group_orig_ty = variable_struct_exists(path, "ty") ? path.ty : 0;
                path.group_orig_trot = variable_struct_exists(path, "trot") ? path.trot : 0;
                path.group_orig_txscale = variable_struct_exists(path, "txscale") ? path.txscale : 1;
                path.group_orig_tyscale = variable_struct_exists(path, "tyscale") ? path.tyscale : 1;
            }

            var world_point = gmvex_group_compose_point(acc, path.group_orig_tx, path.group_orig_ty);
            gmvex_path_set_transform(
                path,
                world_point[0], world_point[1],
                path.group_orig_trot + acc.grot,
                path.group_orig_txscale * acc.gxscale,
                path.group_orig_tyscale * acc.gyscale,
                variable_struct_exists(path, "tox") ? path.tox : 0,
                variable_struct_exists(path, "toy") ? path.toy : 0
            );
        }
    }
}