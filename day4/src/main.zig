const std = @import("std");
const helpers = @import("helpers.zig");

const board = struct {
    row: u32,
    col: u32,
    data: []const u8,
};

fn check_permutations(state: *board, idx: usize) usize {

}


pub fn main() !void {
    var alloc = std.heap.page_allocator;
    const filename = try helpers.grab_file_arg(alloc);
    defer alloc.free(filename);
    var state = board{
        .row = undefined,
        .col = undefined,
        .data = try helpers.read_entire_file(alloc, filename),
    };
    var idx: usize = 0;
    var enabled: bool = true;
    while (idx < state.datalen) {
        if (valid_start_char(buffer[idx])) {
            const local_result = parse_string(buffer, idx) catch {
                idx += 1;
                continue;
            };
            const local_op = local_result[0].operation;
            const flip = local_op == op_type.do or local_op == op_type.dont;
            if (local_op == op_type.do) {
                enabled = true;
            }
            if (local_op == op_type.dont) {
                enabled = false;
            }
            if (!flip and enabled) {
                try ops.append(local_result[0]);
            }
            idx += local_result[1];
        } else {
            idx += 1;
        }
    }
    var sum: i64 = 0;
    for (ops.items) |single_op| {
        sum += (single_op.values[0] * single_op.values[1]);
    }

    std.debug.print("part 1 = {d}\n", .{sum});
}

