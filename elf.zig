const std = @import("std");
const io = std.io;
const fs = std.fs;
const elf = std.elf;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub fn isReaservedSection(index: u64) bool {
    return index == elf.SHN_UNDEF
    or index == elf.SHN_UNDEF 
    or index == elf.SHN_LORESERVE
    or index == elf.SHN_LOPROC
    or index == elf.SHN_HIPROC
    or index == elf.SHN_ABS
    or index == elf.SHN_COMMON
    or index == elf.SHN_HIRESERVE;
}

pub fn getSectionStringTable(header: elf.Header, file: fs.File) !elf.Shdr {
    const pos = try file.seekableStream().getPos();
    try file.seekableStream().seekTo(header.shoff + (header.shstrndx * header.shentsize));
    const section_header = try file.reader().readStruct(elf.Shdr);
    try file.seekableStream().seekTo(pos);
    return section_header;
}

pub fn getStringTable(header: elf.Header, index: u64, file: fs.File) !elf.Shdr {
    const pos = try file.seekableStream().getPos();
    try file.seekableStream().seekTo(header.shoff + (index * header.shentsize));
    const section_header = try file.reader().readStruct(elf.Shdr);
    try file.seekableStream().seekTo(pos);
    return section_header;
}

pub fn getSections(header: elf.Header, file: fs.File) !std.StringHashMap(elf.Shdr) {
    try file.seekableStream().seekTo(header.shoff);
    var section_list = std.StringHashMap(elf.Shdr).init(allocator);
    const strtable = try getSectionStringTable(header, file);
    for(0..header.shnum) |_| {
        const section_header = try file.reader().readStruct(elf.Shdr);
        const pos = try file.seekableStream().getPos();
        try file.seekTo(strtable.sh_offset + section_header.sh_name);
        const name = try file.reader().readUntilDelimiterAlloc(allocator, 0, std.math.maxInt(u64)); 
        try section_list.put(name, section_header);
        try file.seekableStream().seekTo(pos);
    }
    return section_list;
} 

pub fn getSymbols(header: elf.Header, secheader: elf.Shdr, file: fs.File) !std.StringHashMap(elf.Sym) {
    const string_table = try getStringTable(header, secheader.sh_link, file);
    var symbols  = std.StringHashMap(elf.Sym).init(allocator);
    const symbol_count = secheader.sh_size /  secheader.sh_entsize;
    try file.seekableStream().seekTo(secheader.sh_offset);
    for(0..symbol_count) |_| {
        const symbol = try file.reader().readStruct(elf.Sym);
        const pos = try file.seekableStream().getPos();
        try file.seekableStream().seekTo(string_table.sh_offset + symbol.st_name);
        const symbol_name = try file.reader().readUntilDelimiterAlloc(allocator, 0, std.math.maxInt(u64));
        try file.seekableStream().seekTo(pos);
        try symbols.put(symbol_name, symbol);
    }
    return symbols;
}


pub fn main() !void {
    const cwd = fs.cwd();

    const elf_object = try cwd.openFile("main.o", .{});

    //_= elf_object;

    const header = try elf.Header.read(elf_object);

    const sections = try getSections(header, elf_object);
    //defer allocator.free(sections);

    //std.debug.print("{}\n", .{sections[0]});
    var sect_iter = sections.iterator();

    while (sect_iter.next()) |sec| {
        if(sec.value_ptr.sh_type == elf.SHT_SYMTAB) {
            //std.debug.print("{}\n", .{sec});
            var symbols = try getSymbols(header, sec.value_ptr.*, elf_object);
            var it = symbols.iterator();

            while (it.next()) |s| {
                std.debug.print("name: {s}\n", .{s.key_ptr.*});
            }
        }
    }
}
