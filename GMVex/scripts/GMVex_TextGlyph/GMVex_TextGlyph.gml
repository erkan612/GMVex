function gmvex_text_char_to_glyph(font, char_code) {
    var sub = font.cmap_subtable_offset;
    var seg_count_x2 = gmvex_text_read_u16be(font.buf, sub + 6);
    var seg_count = seg_count_x2 / 2;

    var end_codes_pos    = sub + 14;
    var start_codes_pos  = end_codes_pos + seg_count_x2 + 2; // +2 for reservedPad
    var id_deltas_pos    = start_codes_pos + seg_count_x2;
    var id_range_off_pos = id_deltas_pos + seg_count_x2;

    for (var i = 0; i < seg_count; i++) {
        var end_code = gmvex_text_read_u16be(font.buf, end_codes_pos + i*2);
        if (char_code <= end_code) {
            var start_code = gmvex_text_read_u16be(font.buf, start_codes_pos + i*2);
            if (char_code < start_code) return 0;
            var id_delta = gmvex_text_read_s16be(font.buf, id_deltas_pos + i*2);
            var id_range_offset = gmvex_text_read_u16be(font.buf, id_range_off_pos + i*2);
            if (id_range_offset == 0) {
                return (char_code + id_delta) & 0xFFFF;
            } else {
                var glyph_addr = id_range_off_pos + i*2 + id_range_offset + (char_code - start_code) * 2;
                var gid = gmvex_text_read_u16be(font.buf, glyph_addr);
                if (gid == 0) return 0;
                return (gid + id_delta) & 0xFFFF;
            }
        }
    }
    return 0;
}

function gmvex_text_get_loca_range(font, gid) {
    if (font.index_to_loc_format == 0) {
        var a = gmvex_text_read_u16be(font.buf, font.loca_offset + gid*2) * 2;
        var b = gmvex_text_read_u16be(font.buf, font.loca_offset + (gid+1)*2) * 2;
        return [a, b];
    } else {
        var a = gmvex_text_read_u32be(font.buf, font.loca_offset + gid*4);
        var b = gmvex_text_read_u32be(font.buf, font.loca_offset + (gid+1)*4);
        return [a, b];
    }
}

function gmvex_text_get_advance_width(font, gid) {
    if (font.hmtx_offset == -1) return font.units_per_em / 2; // no hmtx - fallback
    if (gid < font.num_h_metrics) {
        return gmvex_text_read_u16be(font.buf, font.hmtx_offset + gid*4);
    } else {
        return gmvex_text_read_u16be(font.buf, font.hmtx_offset + (font.num_h_metrics-1)*4);
    }
}

function gmvex_text_decode_simple_glyph(font, glyph_offset, number_of_contours) {
    var pos = glyph_offset + 10; // skip numberOfContours(2) + bbox(8)

    var end_pts = array_create(number_of_contours);
    for (var i = 0; i < number_of_contours; i++) {
        end_pts[i] = gmvex_text_read_u16be(font.buf, pos);
        pos += 2;
    }
    var num_points = end_pts[number_of_contours - 1] + 1;

    var instruction_length = gmvex_text_read_u16be(font.buf, pos);
    pos += 2 + instruction_length;

    var flags = array_create(num_points);
    var fi = 0;
    while (fi < num_points) {
        var flag = gmvex_text_read_u8(font.buf, pos); pos += 1;
        flags[fi] = flag; fi++;
        if (flag & 0x08) { // REPEAT_FLAG
            var repeat_count = gmvex_text_read_u8(font.buf, pos); pos += 1;
            for (var r = 0; r < repeat_count; r++) { flags[fi] = flag; fi++; }
        }
    }

    var xs = array_create(num_points);
    var xx = 0;
    for (var i = 0; i < num_points; i++) {
        var flag = flags[i];
        var dx = 0;
        if (flag & 0x02) { // X_SHORT_VECTOR
            dx = gmvex_text_read_u8(font.buf, pos); pos += 1;
            if (!(flag & 0x10)) dx = -dx;
        } else {
            if (flag & 0x10) { dx = 0; } // X_SAME_OR_POSITIVE
            else { dx = gmvex_text_read_s16be(font.buf, pos); pos += 2; }
        }
        xx += dx;
        xs[i] = xx;
    }

    var ys = array_create(num_points);
    var yy = 0;
    for (var i = 0; i < num_points; i++) {
        var flag = flags[i];
        var dy = 0;
        if (flag & 0x04) { // Y_SHORT_VECTOR
            dy = gmvex_text_read_u8(font.buf, pos); pos += 1;
            if (!(flag & 0x20)) dy = -dy;
        } else {
            if (flag & 0x20) { dy = 0; }
            else { dy = gmvex_text_read_s16be(font.buf, pos); pos += 2; }
        }
        yy += dy;
        ys[i] = yy;
    }

    var contours = [];
    var start = 0;
    for (var c = 0; c < number_of_contours; c++) {
        var _end = end_pts[c];
        var contour = [];
        for (var i = start; i <= _end; i++) {
            array_push(contour, { x: xs[i], y: ys[i], on_curve: (flags[i] & 0x01) != 0 });
        }
        array_push(contours, contour);
        start = _end + 1;
    }
    return contours;
}

function gmvex_text_decode_composite_glyph(font, glyph_offset, dx0, dy0) {
    var ARG_1_AND_2_ARE_WORDS    = 0x0001;
    var ARGS_ARE_XY_VALUES       = 0x0002;
    var WE_HAVE_A_SCALE          = 0x0008;
    var MORE_COMPONENTS          = 0x0020;
    var WE_HAVE_AN_X_AND_Y_SCALE = 0x0040;
    var WE_HAVE_A_TWO_BY_TWO     = 0x0080;

    var pos = glyph_offset + 10;
    var all_contours = [];

    while (true) {
        var flags = gmvex_text_read_u16be(font.buf, pos);
        var glyph_index = gmvex_text_read_u16be(font.buf, pos + 2);
        pos += 4;

        var arg1 = 0, arg2 = 0;
        if (flags & ARG_1_AND_2_ARE_WORDS) {
            arg1 = gmvex_text_read_s16be(font.buf, pos);
            arg2 = gmvex_text_read_s16be(font.buf, pos + 2);
            pos += 4;
        } else {
            arg1 = gmvex_text_read_s8(font.buf, pos);
            arg2 = gmvex_text_read_s8(font.buf, pos + 1);
            pos += 2;
        }

        if (flags & WE_HAVE_A_SCALE) { pos += 2; }
        else if (flags & WE_HAVE_AN_X_AND_Y_SCALE) { pos += 4; }
        else if (flags & WE_HAVE_A_TWO_BY_TWO) { pos += 8; }

        var use_dx = dx0, use_dy = dy0;
        if (flags & ARGS_ARE_XY_VALUES) {
            use_dx += arg1;
            use_dy += arg2;
        }

        var sub_contours = gmvex_text_get_glyph_contours(font, glyph_index, use_dx, use_dy);
        for (var i = 0; i < array_length(sub_contours); i++) array_push(all_contours, sub_contours[i]);

        if (!(flags & MORE_COMPONENTS)) break;
    }
    return all_contours;
}

function gmvex_text_get_glyph_contours(font, gid, dx = 0, dy = 0) {
    if (gid < 0 || gid >= font.num_glyphs) return [];
    var range = gmvex_text_get_loca_range(font, gid);
    if (range[1] == range[0]) return [];

    var glyph_offset = font.glyf_offset + range[0];
    var number_of_contours = gmvex_text_read_s16be(font.buf, glyph_offset);

    var contours;
    if (number_of_contours >= 0) {
        contours = gmvex_text_decode_simple_glyph(font, glyph_offset, number_of_contours);
    } else {
        return gmvex_text_decode_composite_glyph(font, glyph_offset, dx, dy);
    }

    if (dx != 0 || dy != 0) {
        for (var c = 0; c < array_length(contours); c++) {
            var contour = contours[c];
            for (var p = 0; p < array_length(contour); p++) {
                contour[p].x += dx;
                contour[p].y += dy;
            }
        }
    }
    return contours;
}