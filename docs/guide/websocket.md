# WebSocket

api.zig includes RFC-6455 WebSocket support with an extensible connection hub and handlers for real-time apps.

## Quick Start

- Create a `WebSocket.Hub` and register event handlers.
- Use `app.upgradeToWebSocket(...)` (or the provided helper) in a route to accept WebSocket connections.

Example:

```zig
const hub = try websocket.Hub.init(allocator);
app.get("/ws", (ctx) => websocket.accept(ctx, &hub));
```

## Features

- Ping/Pong heartbeats
- Reconnection-friendly message framing
- Room/channel broadcasting
- GraphQL subscription integration (see GraphQL docs)

See `src/websocket.zig` for low-level details and available helpers.