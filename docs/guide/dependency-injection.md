# Dependency Injection

The `Depends` extractor enables automatic dependency resolution for route handlers, supporting database connections, authentication contexts, configuration, and shared services.

## Basic Usage

```zig
const api = @import("api");

fn getDatabase(ctx: *api.Context) !*Database {
    return ctx.get(*Database, "db") orelse return error.NoDatabaseConnection;
}

fn getCurrentUser(ctx: *api.Context) !User {
    const auth = ctx.header("Authorization") orelse return error.Unauthorized;
    return validateToken(auth);
}

const DbDep = api.extractors.Depends(getDatabase);
const UserDep = api.extractors.Depends(getCurrentUser);
```

## Handler Integration

```zig
fn listItems(ctx: *api.Context) api.Response {
    const db = DbDep.extract(ctx) catch {
        return api.Response.err(.internal_server_error, "{\"error\":\"Database unavailable\"}");
    };
    
    const user = UserDep.extract(ctx) catch {
        return api.Response.err(.unauthorized, "{\"error\":\"Authentication required\"}");
    };
    
    const items = db.value.getItemsForUser(user.value.id) catch {
        return api.Response.err(.internal_server_error, "{\"error\":\"Query failed\"}");
    };
    
    return api.Response.jsonFromValue(ctx.allocator, items) catch
        api.Response.err(.internal_server_error, "{}");
}
```

## Dependency Chaining

Dependencies can depend on other dependencies:

```zig
fn getAuthenticatedDb(ctx: *api.Context) !AuthenticatedDbConnection {
    const user = try getCurrentUser(ctx);
    const db = try getDatabase(ctx);
    return db.withUser(user);
}
```
