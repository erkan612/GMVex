gmvex_init();
gmvex_set_tolerance(0.1);

gmvex_test_poke_u32be = function(buf, offset, value) {
    buffer_poke(buf, offset,   buffer_u8, (value >> 24) & 0xFF);
    buffer_poke(buf, offset+1, buffer_u8, (value >> 16) & 0xFF);
    buffer_poke(buf, offset+2, buffer_u8, (value >> 8) & 0xFF);
    buffer_poke(buf, offset+3, buffer_u8, value & 0xFF);
}

gmvex_test_poke_u16be = function(buf, offset, value) {
    buffer_poke(buf, offset,   buffer_u8, (value >> 8) & 0xFF);
    buffer_poke(buf, offset+1, buffer_u8, value & 0xFF);
}