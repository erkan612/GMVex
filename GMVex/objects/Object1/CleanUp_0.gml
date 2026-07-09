gmvex_path_destroy(r1_fill);
gmvex_path_destroy(r1_stroke);
gmvex_path_destroy(r1_combo);
gmvex_path_destroy(r1_bool);

gmvex_path_destroy(r2_mask_target);
gmvex_path_destroy(r2_multi_target);
gmvex_path_destroy(r2_grad);
gmvex_path_destroy(r2_grad_mask_target);

gmvex_path_destroy(r3_stroke_mask_target);
gmvex_path_destroy(r3_stroke_grad);
gmvex_path_destroy(r3_stroke_grad_mask_target);

if (!is_undefined(suite_font)) {
    for (var i = 0; i < array_length(suite_text_paths); i++) gmvex_path_destroy(suite_text_paths[i].path);
    gmvex_text_font_destroy(suite_font);
}