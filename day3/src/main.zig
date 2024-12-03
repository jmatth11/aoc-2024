const std = @import("std");
const helpers = @import("helpers.zig");

const number_result = std.meta.Tuple(&.{ i64, usize });
const op_result = std.meta.Tuple(&.{ op, usize });

const token_errors = error{
    invalid_sequence,
};

const tokens = enum {
    multiply,
    number,
    left_paran,
    right_paran,
    comma,
    invalid,
};

const op_type = enum {
    multiply,
};

const op = struct {
    operation: op_type = op_type.multiply,
    values: [2]i64,
};

fn valid_start_char(unit: u8) bool {
    return unit == 'm';
}

fn token_type(buf: []const u8, idx: usize) tokens {
    const first_char = buf[idx];
    return switch (first_char) {
        'm' => {
            if ((idx + 2) > buf.len) return tokens.invalid;
            if (buf[idx + 1] == 'u' and buf[idx + 2] == 'l') return tokens.multiply;
            return tokens.invalid;
        },
        '(' => tokens.left_paran,
        ')' => tokens.right_paran,
        ',' => tokens.comma,
        48...57 => tokens.number,
        else => tokens.invalid,
    };
}

fn get_number(buf: []const u8, idx: usize) !number_result {
    var nums: [3]u8 = undefined;
    var offset: usize = 1;
    nums[0] = buf[idx];
    var cur_token = tokens.number;
    while (offset < 2 and cur_token == tokens.number) {
        cur_token = token_type(buf, idx + offset);
        if (cur_token == tokens.number) {
            nums[offset] = buf[idx + offset];
            offset += 1;
        }
    }
    const val = try std.fmt.parseInt(i64, &nums, 10);
    return .{ val, offset + 1 };
}

fn parse_string(buf: []const u8, idx: usize) !op_result {
    var n: usize = 0;
    var result = op{
        .values = undefined,
    };

    var cur_token = token_type(buf, idx);
    if (cur_token != tokens.multiply) return token_errors.invalid_sequence;
    n += 3;

    cur_token = token_type(buf, idx + n);
    if (cur_token != tokens.left_paran) return token_errors.invalid_sequence;
    n += 1;

    cur_token = token_type(buf, idx + n);
    if (cur_token != tokens.number) return token_errors.invalid_sequence;
    var num_result = try get_number(buf, idx + n);
    result.values[0] = num_result[0];
    n += num_result[1];

    cur_token = token_type(buf, idx + n);
    if (cur_token != tokens.comma) return token_errors.invalid_sequence;
    n += 1;

    cur_token = token_type(buf, idx + n);
    if (cur_token != tokens.number) return token_errors.invalid_sequence;
    num_result = try get_number(buf, idx + n);
    result.values[1] = num_result[0];
    n += num_result[1];

    cur_token = token_type(buf, idx + n);
    if (cur_token != tokens.left_paran) return token_errors.invalid_sequence;
    n += 1;
    return .{ result, n };
}

pub fn main() !void {
    var alloc = std.heap.page_allocator;
    const filename = try helpers.grab_file_arg(alloc);
    defer alloc.free(filename);
    var ops = std.ArrayList(op).init(alloc);
    const buffer = try helpers.read_entire_file(alloc, filename);
    var idx: usize = 0;
    while (idx < buffer.len) {
        if (valid_start_char(buffer[idx])) {
            const local_result = try parse_string(buffer, idx);
            try ops.append(local_result[0]);
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
