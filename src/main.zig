const std = @import("std");

const ArrayList = std.array_list;

const Entry = struct {
    path: []const u8,
    rank: f64,
    time: i64,
};

fn toLowerSlice(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
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

fn matchScore(allocator: std.mem.Allocator, query: []const u8, path: []const u8) !i32 {
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

fn parseEntry(line: []const u8, allocator: std.mem.Allocator) !?Entry {
    var parts = std.mem.splitAny(u8, line, "|");
    const path = parts.next() orelse return null;
    const rank_str = parts.next() orelse return null;
    const time_str = parts.next() orelse return null;

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

    const entry = maybe_entry orelse return error.TestExpectedEntry;

    defer allocator.free(entry.path);

    try std.testing.expectEqualSlices(u8, "C:\\zs\\zs", entry.path);
    try std.testing.expectEqual(1.0, entry.rank);
    try std.testing.expectEqual(1753480569, entry.time);
}

fn loadEntries(allocator: std.mem.Allocator, path: []const u8) ![]Entry {
    var file = std.fs.cwd().openFile(path, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => {
            const f = try std.fs.cwd().createFile(path, .{});
            f.close();
            return allocator.alloc(Entry, 0);
        },
        else => return err,
    };
    defer file.close();

    var buffer: [1024]u8 = undefined;
    const reader = file.reader(&buffer);
    var r = reader.interface;

    var writer = std.io.Writer.Allocating.init(allocator);
    defer writer.deinit();

    var lines = ArrayList.Managed(Entry).init(allocator);

    while (true) {
        const maybe_line = r.streamDelimiter(&writer.writer, '\n');

        if (maybe_line) |_| {
            const line = writer.written();

            if (try parseEntry(line, allocator)) |entry| {
                try lines.append(entry);
            }

            writer.clearRetainingCapacity();
            r.toss(1);
        } else |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        }
    }

    return lines.toOwnedSlice();
}

fn saveEntries(path: []const u8, entries: []Entry, allocator: std.mem.Allocator) !void {
    var file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var writer = std.io.Writer.Allocating.init(allocator);
    defer writer.deinit();

    for (entries) |entry| {
        try writer.writer.print("{s}|{}|{}\n", .{ entry.path, entry.rank, entry.time });
    }

    try writer.writer.flush();
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);

    const exe_dir = try std.fs.selfExeDirPathAlloc(allocator);
    const datafile = try std.fs.path.join(allocator, &.{ exe_dir, "zs.db" });
    defer allocator.free(datafile);

    const now = std.time.timestamp();

    if (args.len >= 2 and std.mem.eql(u8, args[1], "--add")) {
        var path: []const u8 = undefined;

        if (args.len >= 3) {
            path = args[2];
        } else {
            path = try std.fs.cwd().realpathAlloc(allocator, ".");
        }

        var entries = try loadEntries(allocator, datafile);
        defer allocator.free(entries);

        var found = false;
        for (entries) |*entry| {
            if (std.mem.eql(u8, entry.path, path)) {
                entry.rank += 1;
                entry.time = now;
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

        try saveEntries(datafile, entries, allocator);
        return;
    }

    const query = if (args.len > 1) args[3] else return;
    const entries = try loadEntries(allocator, datafile);
    defer allocator.free(entries);

    var best: ?Entry = null;
    var best_score: f64 = -1;

    for (entries) |entry| {
        const pos = matchScore(allocator, query, entry.path) catch continue;

        if (pos >= 0) {
            const age = @as(f64, @floatFromInt(now - entry.time));
            const position_score = 1.0 / (@as(f64, @floatFromInt(pos)) + 1.0);
            const score = entry.rank * position_score * (3.75 / (0.0001 * age + 1.25));
            if (score > best_score) {
                best_score = score;
                best = entry;
            }
        }
    }

    var writer = std.Io.Writer.Allocating.init(allocator);
    defer writer.deinit();

    if (best) |b| {
        try writer.writer.print("{s}\n", .{b.path});
    } else {
        try writer.writer.print("No match\n", .{});
        std.process.exit(1);
    }
}
