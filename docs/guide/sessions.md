# Sessions

api.zig provides a secure session management system with pluggable backends (in-memory, Redis, etc.).

## Basics

- Create a `Session.Manager` and configure cookie name, TTL, secure flag, and storage backend.
- Use `sessionMiddleware(manager)` to enable automatic session loading/saving for requests.

## Example

```zig
const manager = try session.Manager.init(allocator, manager_config);
app.addMiddleware(sessionMiddleware(&manager));
```

## Tips

- Use secure cookies (`Secure=true`) in production and set `SameSite` appropriately.
- Use server-side stores (e.g., Redis) for multi-process deployments.

See the `src/session.zig` API docs for configuration options and storage interfaces.