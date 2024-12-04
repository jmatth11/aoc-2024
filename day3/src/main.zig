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
    do,
    dont,
    invalid,
};

const op_type = enum {
    multiply,
    do,
    dont,
};

const op = struct {
    operation: op_type = op_type.multiply,
    values: [2]i64,
};

fn valid_start_char(unit: u8) bool {
    return unit == 'm' or unit == 'd';
}

fn parse_d_commands(buf: []const u8, idx: usize) tokens {
    var offset: usize = 0;
    if (buf[idx] != 'o') return tokens.invalid;
    offset += 1;
    var cur_token = token_type(buf, idx + offset);
    if (cur_token == tokens.left_paran) {
        offset += 1;
        cur_token = token_type(buf, idx + offset);
        if (cur_token == tokens.right_paran) return tokens.do;
        return tokens.invalid;
    }
    if (buf[idx + offset] == 'n' and
        buf[idx + offset + 1] == '\'' and
        buf[idx + offset + 2] == 't')
    {
        offset += 3;
        cur_token = token_type(buf, idx + offset);
        offset += 1;
        if (cur_token == tokens.left_paran) {
            cur_token = token_type(buf, idx + offset);
            if (cur_token == tokens.right_paran) return tokens.dont;
        }
    }
    return tokens.invalid;
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
        'd' => parse_d_commands(buf, idx + 1),
        48...57 => tokens.number,
        else => tokens.invalid,
    };
}

fn get_number(buf: []const u8, idx: usize) !number_result {
    var nums: [3]u8 = [_]u8{ 0, 0, 0 };
    var offset: usize = 1;
    nums[0] = buf[idx];
    var cur_token = tokens.number;
    while (offset < 3 and cur_token == tokens.number) {
        cur_token = token_type(buf, idx + offset);
        if (cur_token == tokens.number) {
            nums[offset] = buf[idx + offset];
            offset += 1;
        }
    }
    const val = try std.fmt.parseInt(i64, nums[0..offset], 10);
    return .{ val, offset };
}

fn parse_string(buf: []const u8, idx: usize) !op_result {
    var n: usize = 0;
    var result = op{
        .values = undefined,
    };

    var cur_token = token_type(buf, idx);
    if (cur_token == tokens.do) {
        result.operation = op_type.do;
        return .{ result, 4 };
    }
    if (cur_token == tokens.dont) {
        result.operation = op_type.dont;
        return .{ result, 6 };
    }
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
    if (cur_token != tokens.right_paran) return token_errors.invalid_sequence;
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
    var enabled: bool = true;
    while (idx < buffer.len) {
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
