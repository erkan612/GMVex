gmvex_init(0.1);

// row 1
r1_fill = gmvex_path_create();
gmvex_path_add_rect(r1_fill, 0, 0, 140, 140);
gmvex_path_set_transform(r1_fill, 60, 60);

r1_stroke = gmvex_path_create();
gmvex_path_add_circle(r1_stroke, 70, 70, 60);
gmvex_path_set_transform(r1_stroke, 300, 60);

r1_combo = gmvex_path_create();
gmvex_path_add_rect(r1_combo, 0, 0, 140, 140);
gmvex_path_set_transform(r1_combo, 540, 60);

var bool_a = gmvex_path_create();
gmvex_path_add_circle(bool_a, 0, 0, 70);
gmvex_path_set_transform(bool_a, 810, 100);
gmvex_path_apply_transform_all(bool_a);
var bool_b = gmvex_path_create();
gmvex_path_add_circle(bool_b, 0, 0, 70);
gmvex_path_set_transform(bool_b, 890, 130);
gmvex_path_apply_transform_all(bool_b);
r1_bool = gmvex_path_boolean(bool_a, bool_b, gmvex_bool.INTERSECTION);
gmvex_path_destroy(bool_a);
gmvex_path_destroy(bool_b);

// row2
r2_mask_target = gmvex_path_create();
gmvex_path_add_rect(r2_mask_target, 0, 0, 140, 140);
gmvex_path_set_transform(r2_mask_target, 60, 300);
r2_mask_content = gmvex_path_create();
gmvex_path_add_circle(r2_mask_content, 0, 0, 60);
gmvex_path_set_transform(r2_mask_content, 70, 70);
gmvex_path_set_mask(r2_mask_target, r2_mask_content);

r2_multi_target = gmvex_path_create();
gmvex_path_add_rect(r2_multi_target, 0, 0, 140, 140);
gmvex_path_set_transform(r2_multi_target, 300, 300);
var multi_c1 = gmvex_path_create();
gmvex_path_add_circle(multi_c1, 0, 0, 28);
gmvex_path_set_transform(multi_c1, 42, 70);
gmvex_path_apply_transform_all(multi_c1);
var multi_c2 = gmvex_path_create();
gmvex_path_add_circle(multi_c2, 0, 0, 28);
gmvex_path_set_transform(multi_c2, 98, 70);
gmvex_path_apply_transform_all(multi_c2);
r2_multi_combined = gmvex_svg_merge_paths_flat([multi_c1, multi_c2]);
gmvex_path_set_mask(r2_multi_target, r2_multi_combined);

r2_grad = gmvex_path_create();
gmvex_path_add_rect(r2_grad, 0, 0, 140, 140);
gmvex_path_set_transform(r2_grad, 540, 300);

r2_grad_mask_target = gmvex_path_create();
gmvex_path_add_rect(r2_grad_mask_target, 0, 0, 140, 140);
gmvex_path_set_transform(r2_grad_mask_target, 780, 300);
r2_grad_mask_content = gmvex_path_create();
gmvex_path_add_circle(r2_grad_mask_content, 0, 0, 60);
gmvex_path_set_transform(r2_grad_mask_content, 70, 70);
gmvex_path_set_mask(r2_grad_mask_target, r2_grad_mask_content);

// row 3
r3_stroke_mask_target = gmvex_path_create();
gmvex_path_add_rect(r3_stroke_mask_target, 0, 0, 140, 140);
gmvex_path_set_transform(r3_stroke_mask_target, 60, 540);
r3_stroke_mask_content = gmvex_path_create();
gmvex_path_add_circle(r3_stroke_mask_content, 0, 0, 110);
gmvex_path_set_transform(r3_stroke_mask_content, 70, 70);
gmvex_path_set_mask(r3_stroke_mask_target, r3_stroke_mask_content);

r3_stroke_grad = gmvex_path_create();
gmvex_path_add_rect(r3_stroke_grad, 0, 0, 140, 140);
gmvex_path_set_transform(r3_stroke_grad, 300, 540);

r3_stroke_grad_mask_target = gmvex_path_create();
gmvex_path_add_rect(r3_stroke_grad_mask_target, 0, 0, 140, 140);
gmvex_path_set_transform(r3_stroke_grad_mask_target, 540, 540);
r3_stroke_grad_mask_content = gmvex_path_create();
gmvex_path_add_circle(r3_stroke_grad_mask_content, 0, 0, 70);
gmvex_path_set_transform(r3_stroke_grad_mask_content, 70, 70);
gmvex_path_set_mask(r3_stroke_grad_mask_target, r3_stroke_grad_mask_content);

suite_font = gmvex_text_font_load("Roboto-Regular.ttf");
if (is_undefined(suite_font)) {
    show_debug_message("Roboto-Regular.ttf not found - check Included Files. Text cell will be skipped.");
} else {
    suite_text_paths = gmvex_text_to_paths(suite_font, "office", 40, 780, 610);
}
