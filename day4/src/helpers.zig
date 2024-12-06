const std = @import("std");

/// Context type for the map function.
pub const Context = struct {
    data: *anyopaque,
};

/// Function type for mapping across a file iteration.
pub const map_func = fn (ctx: *Context, line: []const u8) void;

/// General command errors
pub const cmd_error = error{
    no_file,
    read_error,
};

/// Iterate over file line by line and execute the callback given.
///
/// @param alloc The allocator
/// @param filename The file to open.
/// @param callback The callback function
/// @param ctx The context to pass to the callback
/// @returns void on success, error otherwise.
pub fn iterate_file(
    alloc: std.mem.Allocator,
    filename: []const u8,
    callback: map_func,
    ctx: *Context,
) !void {
    const max_bytes_per_line = 4096;
    var file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();
    // wrapping the reader into a std.io.bufferedReader is usually advised
    var buffered_reader = std.io.bufferedReader(file.reader());
    const reader = buffered_reader.reader();
    while (try reader.readUntilDelimiterOrEofAlloc(alloc, '\n', max_bytes_per_line)) |line| {
        defer alloc.free(line);
        callback(ctx, line);
    }
}

/// Read the entire file and return the buffer of data.
///
/// @param alloc The allocator.
/// @param filename The file's name.
/// @return The file's data.
pub fn read_entire_file(alloc: std.mem.Allocator, filename: []const u8) ![]const u8 {
    var file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();
    const file_size = try file.getEndPos();
    const buffer = try alloc.alloc(u8, file_size);
    const result_size = try file.readAll(buffer);
    if (result_size != file_size) {
        return cmd_error.read_error;
    }
    return buffer;
}

/// Grab the filename from the command line arguments.
/// Caller is responsible for freeing returned string.
///
/// @param alloc The allocator
/// @return The filename if successful, and error otherwise.
pub fn grab_file_arg(alloc: std.mem.Allocator) ![]const u8 {
    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);
    if (args.len < 2) return cmd_error.no_file;
    return alloc.dupe(u8, args[1]);
}

/// Get the absolute value of the given parameter.
///
/// @param T The comptime type.
/// @param a The value.
/// @return The absolute value.
pub fn abs(comptime T: type, a: T) T {
    if (a < 0) return -a;
    return a;
}
