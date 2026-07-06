function gmvex_text_read_u8(buf, offset)  { buffer_seek(buf, buffer_seek_start, offset); return buffer_read(buf, buffer_u8); }

function gmvex_text_read_s8(buf, offset) {
    var v = gmvex_text_read_u8(buf, offset);
    return (v >= 128) ? (v - 256) : v;
}

function gmvex_text_read_u16be(buf, offset) {
    buffer_seek(buf, buffer_seek_start, offset);
    var b0 = buffer_read(buf, buffer_u8);
    var b1 = buffer_read(buf, buffer_u8);
    return (b0 << 8) | b1;
}
function gmvex_text_read_s16be(buf, offset) {
    var v = gmvex_text_read_u16be(buf, offset);
    return (v >= 32768) ? (v - 65536) : v;
}
function gmvex_text_read_u32be(buf, offset) {
    buffer_seek(buf, buffer_seek_start, offset);
    var b0 = buffer_read(buf, buffer_u8);
    var b1 = buffer_read(buf, buffer_u8);
    var b2 = buffer_read(buf, buffer_u8);
    var b3 = buffer_read(buf, buffer_u8);
    return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3;
}
function gmvex_text_read_tag(buf, offset) {
    buffer_seek(buf, buffer_seek_start, offset);
    var s = "";
    for (var i = 0; i < 4; i++) s += chr(buffer_read(buf, buffer_u8));
    return s;
}

function gmvex_text_font_load(path) {
    var buf = buffer_load(path);
    if (buf == -1) {
        show_debug_message("gmvex_text_font_load: failed to load file at " + path);
        return undefined;
    }

    var num_tables = gmvex_text_read_u16be(buf, 4);
    var tables = ds_map_create();
    var offset = 12;
    for (var i = 0; i < num_tables; i++) {
        var tag = gmvex_text_read_tag(buf, offset);
        var table_offset = gmvex_text_read_u32be(buf, offset + 8);
        var table_length  = gmvex_text_read_u32be(buf, offset + 12);
        tables[? tag] = [table_offset, table_length];
        offset += 16;
    }

    if (!ds_map_exists(tables, "glyf") || !ds_map_exists(tables, "loca")) {
        show_debug_message("gmvex_text_font_load: no 'glyf'/'loca' table found -- this is likely a CFF-outline (.otf) font, which this module does not support. See module header.");
        ds_map_destroy(tables);
        buffer_delete(buf);
        return undefined;
    }
    if (!ds_map_exists(tables, "cmap") || !ds_map_exists(tables, "head") || !ds_map_exists(tables, "maxp")) {
        show_debug_message("gmvex_text_font_load: missing required table (cmap/head/maxp) -- not a valid font file?");
        ds_map_destroy(tables);
        buffer_delete(buf);
        return undefined;
    }

    var head_offset = tables[? "head"][0];
    var magic = gmvex_text_read_u32be(buf, head_offset + 12);
    if (magic != 0x5F0F3CF5) {
        show_debug_message("gmvex_text_font_load: head table magic number mismatch, offsets are likely wrong for this file");
        ds_map_destroy(tables);
        buffer_delete(buf);
        return undefined;
    }
    var units_per_em = gmvex_text_read_u16be(buf, head_offset + 18);
    var index_to_loc_format = gmvex_text_read_s16be(buf, head_offset + 50);

    var maxp_offset = tables[? "maxp"][0];
    var num_glyphs = gmvex_text_read_u16be(buf, maxp_offset + 4);

    var hhea_ascent = 0, hhea_descent = 0, hhea_line_gap = 0, num_h_metrics = 0, hmtx_offset = -1;
    if (ds_map_exists(tables, "hhea") && ds_map_exists(tables, "hmtx")) {
        var hhea_offset = tables[? "hhea"][0];
        hhea_ascent   = gmvex_text_read_s16be(buf, hhea_offset + 4);
        hhea_descent  = gmvex_text_read_s16be(buf, hhea_offset + 6);
        hhea_line_gap = gmvex_text_read_s16be(buf, hhea_offset + 8);
        num_h_metrics = gmvex_text_read_u16be(buf, hhea_offset + 34);
        hmtx_offset = tables[? "hmtx"][0];
    }

    var cmap_offset = tables[? "cmap"][0];
    var cmap_num_subtables = gmvex_text_read_u16be(buf, cmap_offset + 2);
    var chosen_subtable_offset = -1;
    var fallback_subtable_offset = -1;
    var sub_pos = cmap_offset + 4;
    for (var i = 0; i < cmap_num_subtables; i++) {
        var platform_id = gmvex_text_read_u16be(buf, sub_pos);
        var encoding_id = gmvex_text_read_u16be(buf, sub_pos + 2);
        var sub_offset  = gmvex_text_read_u32be(buf, sub_pos + 4);
        if (platform_id == 3 && encoding_id == 1) chosen_subtable_offset = cmap_offset + sub_offset;
        if (platform_id == 0 && fallback_subtable_offset == -1) fallback_subtable_offset = cmap_offset + sub_offset;
        sub_pos += 8;
    }
    if (chosen_subtable_offset == -1) chosen_subtable_offset = fallback_subtable_offset;
    if (chosen_subtable_offset == -1) {
        show_debug_message("gmvex_text_font_load: no usable cmap subtable found (need platform 3/encoding 1, or platform 0)");
        ds_map_destroy(tables);
        buffer_delete(buf);
        return undefined;
    }
    var cmap_format = gmvex_text_read_u16be(buf, chosen_subtable_offset);
    if (cmap_format != 4) {
        show_debug_message("gmvex_text_font_load: cmap subtable format " + string(cmap_format) + " is not supported (only format 4 is implemented, which covers the vast majority of fonts for BMP characters)");
        ds_map_destroy(tables);
        buffer_delete(buf);
        return undefined;
    }

    return {
        buf: buf,
        tables: tables,
        units_per_em: units_per_em,
        index_to_loc_format: index_to_loc_format,
        num_glyphs: num_glyphs,
        glyf_offset: tables[? "glyf"][0],
        loca_offset: tables[? "loca"][0],
        cmap_subtable_offset: chosen_subtable_offset,
        hmtx_offset: hmtx_offset,
        num_h_metrics: num_h_metrics,
        ascent: hhea_ascent,
        descent: hhea_descent,
        glyph_cache: ds_map_create(),
		line_gap: hhea_line_gap,
    };
}

function gmvex_text_font_destroy(font) {
    if (is_undefined(font)) return;
    buffer_delete(font.buf);
    ds_map_destroy(font.tables);
    ds_map_destroy(font.glyph_cache);
}