# WebSocket Module

The WebSocket module provides RFC 6455 compliant WebSocket support for real-time bidirectional communication.

## Overview

```zig
const websocket = @import("api").websocket;
```

## Quick Start

```zig
const api = @import("api");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    
    var app = try api.App.init(allocator, .{});
    defer app.deinit();

    // Enable WebSocket support
    try app.enableWebSocket(.{
        .max_connections = 10000,
        .ping_interval_ms = 30000,
    });

    // WebSocket endpoint
    app.router.get("/ws", websocketHandler);

    try app.listen(.{ .port = 8080 });
}

fn websocketHandler(ctx: *api.Context) !void {
    try ctx.response.upgradeWebSocket(.{
        .on_open = onOpen,
        .on_message = onMessage,
        .on_close = onClose,
    });
}
```

## WebSocket Hub

The Hub manages all WebSocket connections and provides broadcasting capabilities.

### Creating a Hub

```zig
var hub = websocket.Hub.init(allocator, .{
    .max_connections = 10000,
    .max_message_size = 64 * 1024, // 64KB
    .ping_interval_ms = 30000,      // 30 seconds
    .pong_timeout_ms = 10000,       // 10 seconds
    .enable_compression = false,
    .allowed_origins = &.{ "https://example.com" },
});
defer hub.deinit();
```

### Hub Configuration

```zig
const HubConfig = struct {
    // Maximum number of concurrent connections
    max_connections: u32 = 10000,
    
    // Maximum message size in bytes
    max_message_size: u32 = 64 * 1024,
    
    // Ping interval for keepalive
    ping_interval_ms: u32 = 30000,
    
    // Pong timeout before disconnect
    pong_timeout_ms: u32 = 10000,
    
    // WebSocket compression (permessage-deflate)
    enable_compression: bool = false,
    
    // Allowed origins for CORS
    allowed_origins: []const []const u8 = &.{},
};
```

## Connection Management

### Registering Connections

```zig
const handler = websocket.EventHandler{
    .on_open = struct {
        fn handle(conn: *websocket.Connection) void {
            std.log.info("Client connected: {d}", .{conn.id});
        }
    }.handle,
    .on_message = struct {
        fn handle(conn: *websocket.Connection, msg: websocket.Message) void {
            std.log.info("Received: {s}", .{msg.data});
        }
    }.handle,
    .on_close = struct {
        fn handle(conn: *websocket.Connection, code: u16, reason: []const u8) void {
            std.log.info("Client disconnected: {d}", .{conn.id});
        }
    }.handle,
};

const conn = try hub.register(handler);
```

### Connection Properties

```zig
const Connection = struct {
    id: u64,                              // Unique connection ID
    allocator: std.mem.Allocator,
    handler: EventHandler,
    state: ConnectionState,               // connecting, open, closing, closed
    rooms: std.StringHashMap(void),       // Rooms this connection belongs to
    metadata: std.StringHashMap([]const u8), // Custom metadata
    last_ping_time: i64,
    last_pong_time: i64,
};
```

### Sending Messages

```zig
// Send text message
try conn.sendText("Hello, World!");

// Send binary message
try conn.sendBinary(&[_]u8{ 0x01, 0x02, 0x03 });

// Send ping
try conn.sendPing("heartbeat");

// Send pong (response to ping)
try conn.sendPong("heartbeat");

// Close connection
try conn.close(.normal, "Goodbye");
```

## Rooms

Rooms allow grouping connections for targeted broadcasting.

### Joining Rooms

```zig
// Connection joins a room
try hub.joinRoom(conn, "chat:general");
try hub.joinRoom(conn, "notifications");
```

### Leaving Rooms

```zig
hub.leaveRoom(conn, "chat:general");
```

### Broadcasting to Rooms

```zig
// Broadcast to all connections in a room
hub.broadcastToRoom("chat:general", "New message!");

// Broadcast to room, excluding sender
hub.broadcastToRoomExcept("chat:general", "User joined", conn.id);
```

### Room Information

```zig
// Get number of connections in a room
const count = hub.roomSize("chat:general");

// Check if connection is in a room
const in_room = conn.inRoom("chat:general");
```

## Broadcasting

### Broadcast to All

```zig
// Broadcast to all connections
hub.broadcast("Server announcement!");

// Broadcast excluding specific connection
hub.broadcastExcept("Someone joined", exclude_id);
```

### Targeted Messages

```zig
// Get connection by ID
if (hub.getConnection(user_id)) |conn| {
    try conn.sendText("Private message");
}
```

## Event Handlers

### EventHandler Structure

```zig
const EventHandler = struct {
    on_open: ?*const fn (*Connection) void = null,
    on_message: ?*const fn (*Connection, Message) void = null,
    on_close: ?*const fn (*Connection, u16, []const u8) void = null,
    on_error: ?*const fn (*Connection, anyerror) void = null,
    on_ping: ?*const fn (*Connection, []const u8) void = null,
    on_pong: ?*const fn (*Connection, []const u8) void = null,
};
```

### Message Types

```zig
const Message = struct {
    data: []const u8,
    type: MessageType,
    
    const MessageType = enum {
        text,
        binary,
    };
};
```

## Frame Protocol

### Frame Structure

```zig
const Frame = struct {
    fin: bool = true,           // Final fragment
    rsv1: bool = false,         // Reserved bit 1 (compression)
    rsv2: bool = false,         // Reserved bit 2
    rsv3: bool = false,         // Reserved bit 3
    opcode: Opcode,             // Frame type
    masked: bool = false,       // Client frames must be masked
    mask_key: ?[4]u8 = null,    // Masking key
    payload: []const u8,        // Payload data
};

const Opcode = enum(u4) {
    continuation = 0x0,
    text = 0x1,
    binary = 0x2,
    close = 0x8,
    ping = 0x9,
    pong = 0xA,
};
```

### Creating Frames

```zig
// Text frame
const text_frame = websocket.Frame.text("Hello");

// Binary frame
const binary_frame = websocket.Frame.binary(&data);

// Ping frame
const ping_frame = websocket.Frame.ping("heartbeat");

// Close frame
const close_frame = websocket.Frame.close(.normal, "Goodbye");
```

## Close Codes

```zig
const CloseCode = enum(u16) {
    normal = 1000,           // Normal closure
    going_away = 1001,       // Server shutting down
    protocol_error = 1002,   // Protocol error
    unsupported = 1003,      // Unsupported data
    no_status = 1005,        // No status code present
    abnormal = 1006,         // Abnormal closure
    invalid_data = 1007,     // Invalid frame payload
    policy_violation = 1008, // Policy violation
    message_too_big = 1009,  // Message too big
    extension_required = 1010, // Extension required
    internal_error = 1011,   // Internal server error
    tls_handshake = 1015,    // TLS handshake failure
};
```

## Handshake

### WebSocket Upgrade

```zig
const Handshake = struct {
    /// Validates WebSocket upgrade request
    pub fn validateRequest(ctx: *Context) bool {
        const upgrade = ctx.request.getHeader("Upgrade") orelse return false;
        const connection = ctx.request.getHeader("Connection") orelse return false;
        const key = ctx.request.getHeader("Sec-WebSocket-Key") orelse return false;
        
        return std.ascii.eqlIgnoreCase(upgrade, "websocket") and
               std.mem.indexOf(u8, connection, "Upgrade") != null and
               key.len > 0;
    }

    /// Generates accept key for handshake
    pub fn generateAcceptKey(key: []const u8) [28]u8 {
        // SHA-1 hash of key + GUID, base64 encoded
    }

    /// Creates upgrade response headers
    pub fn createResponse(key: []const u8) []const u8 {
        // HTTP 101 Switching Protocols response
    }
};
```

## Integration with App

### Enabling WebSocket

```zig
var app = try api.App.init(allocator, .{});

try app.enableWebSocket(.{
    .max_connections = 5000,
    .ping_interval_ms = 30000,
});

// Access the hub
const hub = app.ws_hub.?;
```

### WebSocket Route Handler

```zig
fn chatHandler(ctx: *api.Context) !void {
    // Validate WebSocket request
    if (!websocket.Handshake.validateRequest(ctx)) {
        ctx.response.setStatus(.bad_request);
        return;
    }

    // Get hub from app
    const hub = ctx.app.ws_hub orelse return error.WebSocketNotEnabled;

    // Register connection
    const conn = try hub.register(.{
        .on_message = handleMessage,
        .on_close = handleClose,
    });

    // Store user info
    try conn.metadata.put("user_id", ctx.request.getHeader("X-User-Id") orelse "anonymous");

    // Join default room
    try hub.joinRoom(conn, "lobby");
}

fn handleMessage(conn: *websocket.Connection, msg: websocket.Message) void {
    const hub = // get hub reference
    
    // Echo to room
    if (conn.inRoom("lobby")) {
        hub.broadcastToRoom("lobby", msg.data);
    }
}
```

## Connection Metadata

### Setting Metadata

```zig
try conn.setMetadata("user_id", "12345");
try conn.setMetadata("username", "john_doe");
try conn.setMetadata("role", "admin");
```

### Getting Metadata

```zig
const user_id = conn.getMetadata("user_id");
const username = conn.getMetadata("username");
```

## Compression

### permessage-deflate

```zig
var hub = websocket.Hub.init(allocator, .{
    .enable_compression = true,
});

// Compression is negotiated during handshake
// Server checks for Sec-WebSocket-Extensions header
```

## Example: Chat Application

```zig
const std = @import("std");
const api = @import("api");
const websocket = api.websocket;

var hub: *websocket.Hub = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{});
    defer app.deinit();

    try app.enableWebSocket(.{});
    hub = app.ws_hub.?;

    app.router.get("/chat", chatHandler);
    app.router.get("/", serveChat);

    try app.listen(.{ .port = 8080 });
}

fn serveChat(ctx: *api.Context) !void {
    ctx.response.setHeader("Content-Type", "text/html");
    try ctx.response.send(chat_html);
}

fn chatHandler(ctx: *api.Context) !void {
    if (!websocket.Handshake.validateRequest(ctx)) {
        ctx.response.setStatus(.bad_request);
        return;
    }

    const conn = try hub.register(.{
        .on_open = onOpen,
        .on_message = onMessage,
        .on_close = onClose,
    });

    try hub.joinRoom(conn, "general");
}

fn onOpen(conn: *websocket.Connection) void {
    hub.broadcastToRoom("general", "A new user joined!");
}

fn onMessage(conn: *websocket.Connection, msg: websocket.Message) void {
    // Broadcast message to all in room
    hub.broadcastToRoom("general", msg.data);
}

fn onClose(conn: *websocket.Connection, code: u16, reason: []const u8) void {
    hub.broadcastToRoom("general", "A user left");
}

const chat_html =
    \\<!DOCTYPE html>
    \\<html>
    \\<body>
    \\  <div id="messages"></div>
    \\  <input type="text" id="input">
    \\  <button onclick="send()">Send</button>
    \\  <script>
    \\    const ws = new WebSocket('ws://localhost:8080/chat');
    \\    ws.onmessage = (e) => {
    \\      document.getElementById('messages').innerHTML += e.data + '<br>';
    \\    };
    \\    function send() {
    \\      ws.send(document.getElementById('input').value);
    \\    }
    \\  </script>
    \\</body>
    \\</html>
;
```

## See Also

- [GraphQL Module](graphql.md) - For GraphQL subscriptions over WebSocket
- [Session Module](session.md) - For WebSocket authentication
- [Middleware Module](middleware.md) - For WebSocket middleware
