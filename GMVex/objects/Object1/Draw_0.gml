// row 1
gmvex_fill_draw(r1_fill, make_color_rgb(0,200,255), 1);
gmvex_stroke_draw(r1_stroke, 6, c_yellow, 1);
gmvex_fill_draw(r1_combo, make_color_rgb(80,220,120), 1);
gmvex_stroke_draw(r1_combo, 4, c_white, 1);
gmvex_fill_draw(r1_bool, make_color_rgb(255,150,50), 1);

// row 2
gmvex_fill_draw_masked(r2_mask_target, make_color_rgb(0,200,255), 1);
gmvex_fill_draw_masked(r2_multi_target, make_color_rgb(255,100,200), 1);
gmvex_fill_draw_gradient(r2_grad, gmvex_gradient.LINEAR, 0, 70, 140, 70, [[0,c_red,1],[1,c_blue,1]]);
gmvex_fill_draw_gradient_masked(r2_grad_mask_target, gmvex_gradient.LINEAR, 0, 70, 140, 70, [[0,c_red,1],[1,c_blue,1]]);

// row 3
gmvex_stroke_draw_masked(r3_stroke_mask_target, 8, c_yellow, 1);
gmvex_stroke_draw_gradient(r3_stroke_grad, 8, gmvex_gradient.LINEAR, 0, 70, 140, 70, [[0,c_red,1],[1,c_blue,1]]);
gmvex_stroke_draw_gradient_masked(r3_stroke_grad_mask_target, 8, gmvex_gradient.LINEAR, 0, 70, 140, 70, [[0,c_red,1],[1,c_blue,1]]);

if (!is_undefined(suite_font)) {
    for (var i = 0; i < array_length(suite_text_paths); i++) gmvex_fill_draw(suite_text_paths[i].path, c_white, 1);
}

draw_set_color(c_white);
draw_text(60, 210, "fill");
draw_text(300, 210, "stroke");
draw_text(540, 210, "fill+stroke");
draw_text(780, 210, "boolean intersect");
draw_text(60, 450, "mask");
draw_text(300, 450, "multi-shape mask");
draw_text(540, 450, "gradient fill");
draw_text(780, 450, "gradient+mask");
draw_text(60, 690, "stroke+mask");
draw_text(300, 690, "stroke+gradient");
draw_text(540, 690, "stroke+gradient+mask");
draw_text(780, 690, "text (ligature: ffi)");