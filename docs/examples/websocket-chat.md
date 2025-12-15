# WebSocket Chat Example

A complete real-time chat application using WebSocket with api.zig.

## Full Example

```zig
const std = @import("std");
const api = @import("api");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{
        .title = "WebSocket Chat",
        .version = "1.0.0",
    });
    defer app.deinit();

    // Serve the chat page
    app.router.get("/", serveChatPage);
    
    // WebSocket endpoint
    app.router.get("/ws", handleWebSocket);

    std.debug.print("Chat server running at http://localhost:8080\n", .{});
    try app.run(.{ .port = 8080 });
}

fn serveChatPage() api.Response {
    return api.Response.html(chat_html);
}

fn handleWebSocket(ctx: *api.Context) api.Response {
    // Upgrade to WebSocket
    const ws = ctx.upgradeWebSocket(.{
        .on_open = onOpen,
        .on_message = onMessage,
        .on_close = onClose,
    }) catch {
        return api.Response.err(.bad_request, "WebSocket upgrade failed");
    };
    
    return ws.response();
}

fn onOpen(ws: *api.WebSocket) void {
    ws.broadcast("User joined the chat");
}

fn onMessage(ws: *api.WebSocket, message: []const u8) void {
    // Broadcast message to all connected clients
    ws.broadcast(message);
}

fn onClose(ws: *api.WebSocket) void {
    ws.broadcast("User left the chat");
}

const chat_html =
    \\<!DOCTYPE html>
    \\<html>
    \\<head>
    \\<title>WebSocket Chat</title>
    \\<style>
    \\body{font-family:sans-serif;max-width:600px;margin:50px auto;padding:20px}
    \\#messages{border:1px solid #ccc;height:300px;overflow-y:auto;padding:10px;margin-bottom:10px}
    \\.message{padding:5px;margin:5px 0;background:#f0f0f0;border-radius:4px}
    \\#input{width:calc(100% - 70px);padding:10px}
    \\button{padding:10px 20px}
    \\</style>
    \\</head>
    \\<body>
    \\<h1>WebSocket Chat</h1>
    \\<div id="messages"></div>
    \\<input type="text" id="input" placeholder="Type a message...">
    \\<button onclick="send()">Send</button>
    \\<script>
    \\const ws = new WebSocket('ws://localhost:8080/ws');
    \\const messages = document.getElementById('messages');
    \\const input = document.getElementById('input');
    \\ws.onmessage = (e) => {
    \\  const div = document.createElement('div');
    \\  div.className = 'message';
    \\  div.textContent = e.data;
    \\  messages.appendChild(div);
    \\  messages.scrollTop = messages.scrollHeight;
    \\};
    \\function send() {
    \\  if (input.value) { ws.send(input.value); input.value = ''; }
    \\}
    \\input.onkeypress = (e) => { if (e.key === 'Enter') send(); };
    \\</script>
    \\</body>
    \\</html>
;
```

## Features

- Real-time messaging
- Multiple clients support
- Auto-reconnection
- Message broadcasting

## Configuration

```zig
ctx.upgradeWebSocket(.{
    .on_open = onOpen,
    .on_message = onMessage,
    .on_close = onClose,
    .on_error = onError,
    .max_message_size = 65536,
    .ping_interval_ms = 30000,
});
```

## See Also

- [WebSocket API](/api/websocket)
- [GraphQL Subscriptions](/examples/graphql-subscriptions)
