const std = @import("std");
const zls = @import("zls");
const builtin = @import("builtin");

const tres = @import("tres");

const Context = @import("../context.zig").Context;

const types = zls.types;
const requests = zls.requests;

const allocator: std.mem.Allocator = std.testing.allocator;

test "documentSymbol - smoke" {
    try testDocumentSymbol(
        \\const S = struct {
        \\    fn f() void {}
        \\};
    ,
        \\Variable S
        \\  Function f
    );
}

// FIXME: https://github.com/zigtools/zls/issues/986
test "documentSymbol - nested struct with self" {
    try testDocumentSymbol(
        \\const Foo = struct {
        \\    const Self = @This();
        \\    pub fn foo() !Self {}
        \\    const Bar = struct {};
        \\};
    ,
        \\Variable Foo
        \\  Variable Self
        \\  Function foo
        \\  Variable Bar
    );
}

fn testDocumentSymbol(source: []const u8, want: []const u8) !void {
    var ctx = try Context.init();
    defer ctx.deinit();

    const test_uri = try ctx.addDocument(source);

    const params = types.DocumentSymbolParams{
        .textDocument = .{ .uri = test_uri },
    };

    const response = try ctx.requestGetResponse([]types.DocumentSymbol, "textDocument/documentSymbol", params);

    var got = std.ArrayListUnmanaged(u8){};
    defer got.deinit(allocator);

    var stack: [16][]const types.DocumentSymbol = undefined;
    var stack_len: usize = 0;

    stack[stack_len] = response.result;
    stack_len += 1;

    var writer = got.writer(allocator);
    while (stack_len > 0) {
        const top = &stack[stack_len - 1];
        if (top.len > 0) {
            try std.fmt.format(writer, "{[space]s:[width]}", .{ .space = "", .width = (stack_len - 1) * 2 });
            try std.fmt.format(writer, "{s} {s}\n", .{ @tagName(top.*[0].kind), top.*[0].name });
            if (top.*[0].children) |children| {
                std.debug.assert(stack_len < stack.len);
                stack[stack_len] = children;
                stack_len += 1;
            }
            top.* = top.*[1..];
        } else {
            stack_len -= 1;
        }
    }
    _ = got.pop(); // Final \n

    try std.testing.expectEqualStrings(want, got.items);
}
