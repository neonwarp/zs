const std = @import("std");

const ArrayList = std.array_list;
const Allocator = std.mem.Allocator;

const Entry = struct {
    path: []const u8,
    rank: f64,
    time: i64,
};

fn toLowerSlice(allocator: Allocator, s: []const u8) ![]u8 {
    var lower = try allocator.alloc(u8, s.len);
    for (s, 0..) |_, i| {
        const c = s[i];
        if (c >= 'A' and c <= 'Z') {
            lower[i] = c + 32;
        } else {
            lower[i] = c;
        }
    }
    return lower;
}

test "toLowerSlice" {
    const allocator = std.testing.allocator;
    const input = "Hello World!";
    const expected = "hello world!";
    const result = try toLowerSlice(allocator, input);
    defer allocator.free(result);
    try std.testing.expectEqualSlices(u8, expected, result);
}

fn matchScore(allocator: Allocator, query: []const u8, path: []const u8) !i32 {
    const query_lc = try toLowerSlice(allocator, query);
    defer allocator.free(query_lc);

    const path_lc = try toLowerSlice(allocator, path);
    defer allocator.free(path_lc);

    if (std.mem.indexOf(u8, path_lc, query_lc)) |pos| {
        return @intCast(pos);
    } else {
        return -1;
    }
}

test "matchScore" {
    const allocator = std.testing.allocator;
    const path = "C:\\Users\\zs";
    const query = "zs";
    const score = try matchScore(allocator, query, path);
    try std.testing.expect(score >= 0);
}

fn parseEntry(line: []const u8, allocator: Allocator) !?Entry {
    var parts = std.mem.splitAny(u8, line, "|");
    const path = parts.next() orelse
        return null;
    const rank_str = parts.next() orelse
        return null;
    const time_str = parts.next() orelse
        return null;

    const rank = try std.fmt.parseFloat(f64, rank_str);
    const time = try std.fmt.parseInt(i64, time_str, 10);

    const copied_path = try allocator.dupe(u8, path);
    return Entry{
        .path = copied_path,
        .rank = rank,
        .time = time,
    };
}

test "parseEntry" {
    const allocator = std.testing.allocator;
    const line = "C:\\zs\\zs|1.0|1753480569";
    const maybe_entry = try parseEntry(line, allocator);

    const entry = maybe_entry orelse
        return error.TestExpectedEntry;

    defer allocator.free(entry.path);

    try std.testing.expectEqualSlices(u8, "C:\\zs\\zs", entry.path);
    try std.testing.expectEqual(1.0, entry.rank);
    try std.testing.expectEqual(1753480569, entry.time);
}

fn trimCR(s: []const u8) []const u8 {
    return if (s.len > 0 and s[s.len - 1] == '\r') s[0 .. s.len - 1] else s;
}

test "trimCR" {
    const input = "Hello World!\r";
    const expected = "Hello World!";
    const result = trimCR(input);
    try std.testing.expectEqualSlices(u8, expected, result);
}

fn loadEntries(reader: *std.Io.Reader, allocator: Allocator) ![]Entry {
    var list = ArrayList.Managed(Entry).init(allocator);

    while (true) {
        const maybe_line = try reader.takeDelimiter('\n');
        if (maybe_line == null) break;
        const line = trimCR(maybe_line.?);
        if (line.len == 0) continue;
        if (try parseEntry(line, allocator)) |e| try list.append(e);
    }

    return list.toOwnedSlice();
}

fn parseMaybeAppend(line: []const u8, allocator: Allocator, list: *ArrayList.Managed(Entry)) !void {
    if (try parseEntry(line, allocator)) |e| try list.append(e);
}

test "parseMaybeAppend" {
    const allocator = std.testing.allocator;
    var list = ArrayList.Managed(Entry).init(allocator);
    defer {
        for (list.items) |e| allocator.free(e.path);
        list.deinit();
    }

    const line = "C:\\zs\\zs|1.0|1753480569";
    try parseMaybeAppend(line, allocator, &list);

    try std.testing.expectEqual(list.items.len, 1);
    const entry = list.items[0];
    try std.testing.expectEqualSlices(u8, "C:\\zs\\zs", entry.path);
    try std.testing.expectEqual(1.0, entry.rank);
    try std.testing.expectEqual(1753480569, entry.time);
}

fn saveEntries(writer: *std.Io.Writer, entries: []Entry) !void {
    for (entries) |e| {
        try writer.print("{s}|{d}|{}\n", .{ e.path, e.rank, e.time });
    }
}

fn freeEntries(allocator: Allocator, entries: []Entry) void {
    for (entries) |e| allocator.free(e.path);
    allocator.free(entries);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);

    const exe_dir = try std.fs.selfExeDirPathAlloc(allocator);
    const datafile = try std.fs.path.join(allocator, &.{ exe_dir, "zs.db" });
    defer allocator.free(datafile);

    const now = std.time.timestamp();

    if (args.len >= 2 and std.mem.eql(u8, args[1], "--add")) {
        const path: []const u8 = if (args.len >= 3)
            args[2]
        else
            try std.fs.cwd().realpathAlloc(allocator, ".");

        // Open (create if missing)
        var file = std.fs.cwd().openFile(datafile, .{ .mode = .read_write }) catch |e| switch (e) {
            error.FileNotFound => try std.fs.cwd().createFile(datafile, .{ .read = true, .truncate = false }),
            else => return e,
        };
        defer file.close();

        // Load
        var buffer_r: [4096]u8 = undefined;
        var reader = file.reader(&buffer_r);
        var entries = try loadEntries(&reader.interface, allocator);
        defer freeEntries(allocator, entries);

        var found = false;
        for (entries) |*e| {
            if (std.mem.eql(u8, e.path, path)) {
                e.rank += 1;
                e.time = now;
                found = true;
                break;
            }
        }

        if (!found) {
            const new_entry = Entry{
                .path = try allocator.dupe(u8, path),
                .rank = 1,
                .time = now,
            };

            entries = try allocator.realloc(entries, entries.len + 1);
            entries[entries.len - 1] = new_entry;
        }

        var buffer_w: [4096]u8 = undefined;
        var writer = file.writer(&buffer_w);
        var stream = &writer.interface;

        // Rewrite file
        try file.setEndPos(0);
        try file.seekTo(0);
        try saveEntries(stream, entries);
        try stream.flush();
        return;
    }

    if (args.len <= 1) return;
    const query = args[1];

    var file_ro = std.fs.cwd().openFile(datafile, .{ .mode = .read_only }) catch |e| switch (e) {
        error.FileNotFound => return,
        else => return e,
    };
    defer file_ro.close();

    var buffer: [4096]u8 = undefined;
    var reader = file_ro.reader(&buffer);
    const entries = try loadEntries(&reader.interface, allocator);
    defer freeEntries(allocator, entries);

    var best: ?Entry = null;
    var best_score: f64 = -1;

    for (entries) |e| {
        const pos = matchScore(allocator, query, e.path) catch continue;
        if (pos >= 0) {
            const age = @as(f64, @floatFromInt(now - e.time));
            const position_score = 1.0 / (@as(f64, @floatFromInt(pos)) + 1.0);
            const score = e.rank * position_score * (3.75 / (0.0001 * age + 1.25));
            if (score > best_score) {
                best_score = score;
                best = e;
            }
        }
    }

    var buffer_stdout: [512]u8 = undefined;
    var writer_stdout = std.fs.File.stdout().writer(&buffer_stdout);
    const stdout = &writer_stdout.interface;

    if (best) |b| {
        try stdout.print("{s}\n", .{b.path});
        try stdout.flush();
    } else {
        try stdout.print("No match\n", .{});
        try stdout.flush();
        std.process.exit(1);
    }
}
