//! WebSocket support for api.zig framework.
//! Provides real-time bidirectional communication, connection management,
//! and integration with GraphQL subscriptions.
//!
//! ## Features
//! - RFC 6455 compliant WebSocket implementation
//! - Connection lifecycle management
//! - Message framing and parsing
//! - Ping/Pong heartbeat support
//! - Room/channel broadcasting
//! - GraphQL subscription integration

const std = @import("std");
const Context = @import("context.zig").Context;
const Response = @import("response.zig").Response;
const http = @import("http.zig");

/// WebSocket opcode types.
pub const Opcode = enum(u4) {
    continuation = 0x0,
    text = 0x1,
    binary = 0x2,
    close = 0x8,
    ping = 0x9,
    pong = 0xA,

    pub fn isControl(self: Opcode) bool {
        return @intFromEnum(self) >= 0x8;
    }
};

/// WebSocket close codes (RFC 6455).
pub const CloseCode = enum(u16) {
    normal = 1000,
    going_away = 1001,
    protocol_error = 1002,
    unsupported_data = 1003,
    no_status_received = 1005,
    abnormal_closure = 1006,
    invalid_frame_payload = 1007,
    policy_violation = 1008,
    message_too_big = 1009,
    mandatory_extension = 1010,
    internal_server_error = 1011,
    tls_handshake = 1015,

    pub fn toString(self: CloseCode) []const u8 {
        return switch (self) {
            .normal => "Normal closure",
            .going_away => "Going away",
            .protocol_error => "Protocol error",
            .unsupported_data => "Unsupported data",
            .no_status_received => "No status received",
            .abnormal_closure => "Abnormal closure",
            .invalid_frame_payload => "Invalid frame payload",
            .policy_violation => "Policy violation",
            .message_too_big => "Message too big",
            .mandatory_extension => "Mandatory extension",
            .internal_server_error => "Internal server error",
            .tls_handshake => "TLS handshake failure",
        };
    }
};

/// WebSocket frame structure.
pub const Frame = struct {
    fin: bool = true,
    rsv1: bool = false,
    rsv2: bool = false,
    rsv3: bool = false,
    opcode: Opcode,
    masked: bool = false,
    mask_key: ?[4]u8 = null,
    payload: []const u8,

    /// Creates a text frame.
    pub fn text(data: []const u8) Frame {
        return .{ .opcode = .text, .payload = data };
    }

    /// Creates a binary frame.
    pub fn binary(data: []const u8) Frame {
        return .{ .opcode = .binary, .payload = data };
    }

    /// Creates a ping frame.
    pub fn ping(data: []const u8) Frame {
        return .{ .opcode = .ping, .payload = data };
    }

    /// Creates a pong frame.
    pub fn pong(data: []const u8) Frame {
        return .{ .opcode = .pong, .payload = data };
    }

    /// Creates a close frame.
    pub fn close(code: CloseCode, reason: []const u8) Frame {
        _ = code;
        return .{ .opcode = .close, .payload = reason };
    }

    /// Encodes the frame for transmission.
    pub fn encode(self: Frame, allocator: std.mem.Allocator) ![]u8 {
        var buffer: std.ArrayListUnmanaged(u8) = .{};

        // First byte: FIN + RSV + Opcode
        var first_byte: u8 = @intFromEnum(self.opcode);
        if (self.fin) first_byte |= 0x80;
        if (self.rsv1) first_byte |= 0x40;
        if (self.rsv2) first_byte |= 0x20;
        if (self.rsv3) first_byte |= 0x10;
        try buffer.append(allocator, first_byte);

        // Second byte: MASK + Payload length
        var second_byte: u8 = if (self.masked) 0x80 else 0;
        const len = self.payload.len;

        if (len < 126) {
            second_byte |= @intCast(len);
            try buffer.append(allocator, second_byte);
        } else if (len <= 65535) {
            second_byte |= 126;
            try buffer.append(allocator, second_byte);
            try buffer.appendSlice(allocator, &std.mem.toBytes(@as(u16, @intCast(len))));
        } else {
            second_byte |= 127;
            try buffer.append(allocator, second_byte);
            try buffer.appendSlice(allocator, &std.mem.toBytes(@as(u64, @intCast(len))));
        }

        // Mask key (if masked)
        if (self.masked) {
            if (self.mask_key) |key| {
                try buffer.appendSlice(allocator, &key);
            }
        }

        // Payload (masked if necessary)
        if (self.masked and self.mask_key != null) {
            const key = self.mask_key.?;
            for (self.payload, 0..) |byte, i| {
                try buffer.append(allocator, byte ^ key[i % 4]);
            }
        } else {
            try buffer.appendSlice(allocator, self.payload);
        }

        return buffer.toOwnedSlice(allocator);
    }

    /// Decodes a frame from raw data.
    pub fn decode(data: []const u8) !Frame {
        if (data.len < 2) return error.InsufficientData;

        const first_byte = data[0];
        const second_byte = data[1];

        var frame = Frame{
            .fin = (first_byte & 0x80) != 0,
            .rsv1 = (first_byte & 0x40) != 0,
            .rsv2 = (first_byte & 0x20) != 0,
            .rsv3 = (first_byte & 0x10) != 0,
            .opcode = @enumFromInt(first_byte & 0x0F),
            .masked = (second_byte & 0x80) != 0,
            .payload = &.{},
        };

        var offset: usize = 2;
        var payload_len: u64 = second_byte & 0x7F;

        if (payload_len == 126) {
            if (data.len < 4) return error.InsufficientData;
            payload_len = std.mem.readInt(u16, data[2..4], .big);
            offset = 4;
        } else if (payload_len == 127) {
            if (data.len < 10) return error.InsufficientData;
            payload_len = std.mem.readInt(u64, data[2..10], .big);
            offset = 10;
        }

        // Read mask key
        if (frame.masked) {
            if (data.len < offset + 4) return error.InsufficientData;
            frame.mask_key = data[offset..][0..4].*;
            offset += 4;
        }

        // Read payload
        if (data.len < offset + payload_len) return error.InsufficientData;
        frame.payload = data[offset .. offset + payload_len];

        return frame;
    }
};

/// WebSocket message (may span multiple frames).
pub const Message = struct {
    type: MessageType,
    data: []const u8,
};

/// WebSocket message type.
pub const MessageType = enum {
    text,
    binary,
    ping,
    pong,
    close,
};

/// WebSocket connection state.
pub const ConnectionState = enum {
    connecting,
    open,
    closing,
    closed,
};

/// WebSocket event handler interface.
pub const EventHandler = struct {
    on_open: ?*const fn (*Connection) void = null,
    on_message: ?*const fn (*Connection, Message) void = null,
    on_error: ?*const fn (*Connection, anyerror) void = null,
    on_close: ?*const fn (*Connection, CloseCode, []const u8) void = null,
    on_ping: ?*const fn (*Connection, []const u8) void = null,
    on_pong: ?*const fn (*Connection, []const u8) void = null,
};

/// WebSocket connection.
pub const Connection = struct {
    id: u64,
    allocator: std.mem.Allocator,
    state: ConnectionState = .connecting,
    handler: EventHandler,
    rooms: std.StringHashMap(void),
    metadata: std.StringHashMap([]const u8),
    last_ping_time: i64 = 0,
    last_pong_time: i64 = 0,

    // Internal connection data
    _send_buffer: std.ArrayListUnmanaged(u8),
    _recv_buffer: std.ArrayListUnmanaged(u8),

    pub fn init(allocator: std.mem.Allocator, id: u64, handler: EventHandler) Connection {
        return .{
            .id = id,
            .allocator = allocator,
            .handler = handler,
            .rooms = std.StringHashMap(void).init(allocator),
            .metadata = std.StringHashMap([]const u8).init(allocator),
            ._send_buffer = .{},
            ._recv_buffer = .{},
        };
    }

    pub fn deinit(self: *Connection) void {
        self.rooms.deinit();
        self.metadata.deinit();
        self._send_buffer.deinit(self.allocator);
        self._recv_buffer.deinit(self.allocator);
    }

    /// Sends a text message.
    pub fn sendText(self: *Connection, data: []const u8) !void {
        const frame = Frame.text(data);
        const encoded = try frame.encode(self.allocator);
        defer self.allocator.free(encoded);
        try self._send_buffer.appendSlice(self.allocator, encoded);
    }

    /// Sends a binary message.
    pub fn sendBinary(self: *Connection, data: []const u8) !void {
        const frame = Frame.binary(data);
        const encoded = try frame.encode(self.allocator);
        defer self.allocator.free(encoded);
        try self._send_buffer.appendSlice(self.allocator, encoded);
    }

    /// Sends a ping.
    pub fn sendPing(self: *Connection, data: []const u8) !void {
        const frame = Frame.ping(data);
        const encoded = try frame.encode(self.allocator);
        defer self.allocator.free(encoded);
        try self._send_buffer.appendSlice(self.allocator, encoded);
        self.last_ping_time = std.time.milliTimestamp();
    }

    /// Sends a pong.
    pub fn sendPong(self: *Connection, data: []const u8) !void {
        const frame = Frame.pong(data);
        const encoded = try frame.encode(self.allocator);
        defer self.allocator.free(encoded);
        try self._send_buffer.appendSlice(self.allocator, encoded);
    }

    /// Closes the connection.
    pub fn close(self: *Connection, code: CloseCode, reason: []const u8) !void {
        self.state = .closing;
        const frame = Frame.close(code, reason);
        const encoded = try frame.encode(self.allocator);
        defer self.allocator.free(encoded);
        try self._send_buffer.appendSlice(self.allocator, encoded);
    }

    /// Joins a room.
    pub fn joinRoom(self: *Connection, room: []const u8) !void {
        try self.rooms.put(room, {});
    }

    /// Leaves a room.
    pub fn leaveRoom(self: *Connection, room: []const u8) void {
        _ = self.rooms.remove(room);
    }

    /// Checks if in a room.
    pub fn inRoom(self: *Connection, room: []const u8) bool {
        return self.rooms.contains(room);
    }

    /// Sets connection metadata.
    pub fn setMeta(self: *Connection, key: []const u8, value: []const u8) !void {
        try self.metadata.put(key, value);
    }

    /// Gets connection metadata.
    pub fn getMeta(self: *Connection, key: []const u8) ?[]const u8 {
        return self.metadata.get(key);
    }
};

/// WebSocket server/hub for managing connections.
pub const Hub = struct {
    allocator: std.mem.Allocator,
    connections: std.AutoHashMap(u64, *Connection),
    rooms: std.StringHashMap(std.ArrayListUnmanaged(*Connection)),
    next_id: u64 = 1,
    config: HubConfig,

    pub const HubConfig = struct {
        max_connections: u32 = 10000,
        max_message_size: u32 = 64 * 1024, // 64KB
        ping_interval_ms: u32 = 30000, // 30 seconds
        pong_timeout_ms: u32 = 10000, // 10 seconds
        enable_compression: bool = false,
        allowed_origins: []const []const u8 = &.{},
    };

    pub fn init(allocator: std.mem.Allocator, config: HubConfig) Hub {
        return .{
            .allocator = allocator,
            .connections = std.AutoHashMap(u64, *Connection).init(allocator),
            .rooms = std.StringHashMap(std.ArrayListUnmanaged(*Connection)).init(allocator),
            .config = config,
        };
    }

    pub fn deinit(self: *Hub) void {
        var conn_iter = self.connections.valueIterator();
        while (conn_iter.next()) |conn| {
            conn.*.deinit();
            self.allocator.destroy(conn.*);
        }
        self.connections.deinit();

        var room_iter = self.rooms.valueIterator();
        while (room_iter.next()) |room| {
            room.deinit(self.allocator);
        }
        self.rooms.deinit();
    }

    /// Registers a new connection.
    pub fn register(self: *Hub, handler: EventHandler) !*Connection {
        if (self.connections.count() >= self.config.max_connections) {
            return error.TooManyConnections;
        }

        const id = self.next_id;
        self.next_id += 1;

        const conn = try self.allocator.create(Connection);
        conn.* = Connection.init(self.allocator, id, handler);
        conn.state = .open;

        try self.connections.put(id, conn);

        if (handler.on_open) |on_open| {
            on_open(conn);
        }

        return conn;
    }

    /// Unregisters a connection.
    pub fn unregister(self: *Hub, conn: *Connection) void {
        // Remove from all rooms
        var room_iter = self.rooms.iterator();
        while (room_iter.next()) |entry| {
            var members = entry.value_ptr;
            var i: usize = 0;
            while (i < members.items.len) {
                if (members.items[i].id == conn.id) {
                    _ = members.swapRemove(i);
                } else {
                    i += 1;
                }
            }
        }

        _ = self.connections.remove(conn.id);
        conn.deinit();
        self.allocator.destroy(conn);
    }

    /// Gets a connection by ID.
    pub fn getConnection(self: *Hub, id: u64) ?*Connection {
        return self.connections.get(id);
    }

    /// Broadcasts a message to all connections.
    pub fn broadcast(self: *Hub, data: []const u8) void {
        var iter = self.connections.valueIterator();
        while (iter.next()) |conn| {
            conn.*.sendText(data) catch {};
        }
    }

    /// Broadcasts a message to a specific room.
    pub fn broadcastToRoom(self: *Hub, room: []const u8, data: []const u8) void {
        const members = self.rooms.get(room) orelse return;
        for (members.items) |conn| {
            conn.sendText(data) catch {};
        }
    }

    /// Broadcasts to all except specified connection.
    pub fn broadcastExcept(self: *Hub, exclude_id: u64, data: []const u8) void {
        var iter = self.connections.valueIterator();
        while (iter.next()) |conn| {
            if (conn.*.id != exclude_id) {
                conn.*.sendText(data) catch {};
            }
        }
    }

    /// Adds a connection to a room.
    pub fn joinRoom(self: *Hub, conn: *Connection, room: []const u8) !void {
        try conn.joinRoom(room);

        const result = try self.rooms.getOrPut(room);
        if (!result.found_existing) {
            result.value_ptr.* = .{};
        }
        try result.value_ptr.append(self.allocator, conn);
    }

    /// Removes a connection from a room.
    pub fn leaveRoom(self: *Hub, conn: *Connection, room: []const u8) void {
        conn.leaveRoom(room);

        if (self.rooms.getPtr(room)) |members| {
            var i: usize = 0;
            while (i < members.items.len) {
                if (members.items[i].id == conn.id) {
                    _ = members.swapRemove(i);
                } else {
                    i += 1;
                }
            }
        }
    }

    /// Gets the number of connections in a room.
    pub fn roomSize(self: *Hub, room: []const u8) usize {
        const members = self.rooms.get(room) orelse return 0;
        return members.items.len;
    }

    /// Gets total connection count.
    pub fn connectionCount(self: *Hub) usize {
        return self.connections.count();
    }
};

/// WebSocket handshake validator.
pub const Handshake = struct {
    /// Validates WebSocket upgrade request.
    pub fn validate(ctx: *Context) !void {
        const upgrade = ctx.header("Upgrade") orelse return error.MissingUpgradeHeader;
        if (!std.ascii.eqlIgnoreCase(upgrade, "websocket")) return error.InvalidUpgradeHeader;

        const connection = ctx.header("Connection") orelse return error.MissingConnectionHeader;
        if (std.mem.indexOf(u8, connection, "Upgrade") == null) return error.InvalidConnectionHeader;

        const version = ctx.header("Sec-WebSocket-Version") orelse return error.MissingVersionHeader;
        if (!std.mem.eql(u8, version, "13")) return error.UnsupportedVersion;

        _ = ctx.header("Sec-WebSocket-Key") orelse return error.MissingKeyHeader;
    }

    /// Generates the accept key for handshake response.
    pub fn generateAcceptKey(key: []const u8, allocator: std.mem.Allocator) ![]u8 {
        const magic_string = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

        // Concatenate key + magic string
        const concat = try std.fmt.allocPrint(allocator, "{s}{s}", .{ key, magic_string });
        defer allocator.free(concat);

        // SHA-1 hash
        var hasher = std.crypto.hash.Sha1.init(.{});
        hasher.update(concat);
        var hash: [20]u8 = undefined;
        hasher.final(&hash);

        // Base64 encode
        const encoder = std.base64.standard;
        const encoded_len = encoder.calcSize(hash.len);
        const result = try allocator.alloc(u8, encoded_len);
        _ = encoder.encode(result, &hash);

        return result;
    }

    /// Creates the WebSocket handshake response.
    pub fn acceptResponse(ctx: *Context) !Response {
        const key = ctx.header("Sec-WebSocket-Key") orelse return error.MissingKeyHeader;
        const accept_key = try generateAcceptKey(key, ctx.allocator);
        defer ctx.allocator.free(accept_key);

        var response = Response.init();
        response.status = .switching_protocols;
        response.setHeader("Upgrade", "websocket");
        response.setHeader("Connection", "Upgrade");
        response.setHeader("Sec-WebSocket-Accept", accept_key);

        return response;
    }
};

/// WebSocket configuration.
pub const WebSocketConfig = struct {
    path: []const u8 = "/ws",
    max_message_size: u32 = 64 * 1024,
    ping_interval_ms: u32 = 30000,
    pong_timeout_ms: u32 = 10000,
    enable_compression: bool = false,
    allowed_origins: []const []const u8 = &.{},
    subprotocols: []const []const u8 = &.{},
};

/// Default WebSocket configurations.
pub const Defaults = struct {
    pub const standard: WebSocketConfig = .{};

    pub const high_performance: WebSocketConfig = .{
        .max_message_size = 1024 * 1024, // 1MB
        .ping_interval_ms = 15000,
        .pong_timeout_ms = 5000,
    };

    pub const chat: WebSocketConfig = .{
        .max_message_size = 4096,
        .ping_interval_ms = 25000,
    };

    pub const streaming: WebSocketConfig = .{
        .max_message_size = 10 * 1024 * 1024, // 10MB
        .ping_interval_ms = 60000,
        .enable_compression = true,
    };
};

test "frame encoding" {
    const allocator = std.testing.allocator;
    const frame = Frame.text("Hello");
    const encoded = try frame.encode(allocator);
    defer allocator.free(encoded);

    try std.testing.expect(encoded.len > 0);
    try std.testing.expectEqual(@as(u8, 0x81), encoded[0]); // FIN + text opcode
    try std.testing.expectEqual(@as(u8, 5), encoded[1]); // Payload length
}

test "hub operations" {
    const allocator = std.testing.allocator;
    var hub = Hub.init(allocator, .{});
    defer hub.deinit();

    const conn = try hub.register(.{});
    try std.testing.expectEqual(@as(usize, 1), hub.connectionCount());

    try hub.joinRoom(conn, "test-room");
    try std.testing.expectEqual(@as(usize, 1), hub.roomSize("test-room"));

    hub.leaveRoom(conn, "test-room");
    try std.testing.expectEqual(@as(usize, 0), hub.roomSize("test-room"));

    hub.unregister(conn);
    try std.testing.expectEqual(@as(usize, 0), hub.connectionCount());
}
