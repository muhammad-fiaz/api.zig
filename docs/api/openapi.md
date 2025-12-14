# OpenAPI

OpenAPI 3.1 specification generator with automatic schema inference from Zig types. Generates JSON specifications for interactive API documentation.

## Import

```zig
const api = @import("api");
const OpenAPI = api.OpenAPI;
const Schema = api.Schema;
```

## OpenAPI

### OpenAPI.Info

```zig
pub const Info = struct {
    title: []const u8,
    version: []const u8,
    description: ?[]const u8 = null,
    terms_of_service: ?[]const u8 = null,
    contact: ?Contact = null,
    license: ?License = null,
};
```

### Creating OpenAPI

```zig
const openapi = OpenAPI.init(allocator, .{
    .title = "My API",
    .version = "1.0.0",
    .description = "API description",
});
```

## Schema

JSON Schema definitions for OpenAPI.

### Schema Types

```zig
pub const SchemaType = enum {
    string,
    number,
    integer,
    boolean,
    array,
    object,
    null_type,
};
```

### Schema Builders

```zig
Schema.string()   // String schema
Schema.integer()  // Integer schema
Schema.number()   // Number schema
Schema.boolean()  // Boolean schema
Schema.object()   // Object schema
Schema.array(itemSchema)  // Array schema
```

### Schema from Type

```zig
pub fn schemaFromType(comptime T: type) Schema
```

Generates schema from Zig type.

```zig
const UserSchema = api.schemaFromType(struct {
    id: u32,
    name: []const u8,
    active: bool,
});
```

## Built-in Endpoints

The server automatically provides:

| Endpoint        | Description               |
| --------------- | ------------------------- |
| `/openapi.json` | OpenAPI 3.1 specification |
| `/docs`         | Interactive API Docs      |
| `/redoc`        | API Reference             |

## App Configuration

```zig
var app = api.App.init(allocator, .{
    .title = "My API",
    .version = "1.0.0",
    .description = "API for managing users",
    .docs_url = "/docs",
    .redoc_url = "/redoc",
    .openapi_url = "/openapi.json",
});
```

## Example Output

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "My API",
    "version": "1.0.0",
    "description": "API for managing users"
  },
  "paths": {
    "/users": {
      "get": {
        "summary": "List users",
        "responses": {
          "200": {
            "description": "Success",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array"
                }
              }
            }
          }
        }
      }
    }
  }
}
```

## Accessing Documentation

```bash
# Start server
zig build run

# Visit documentation
open http://localhost:8000/docs   # Interactive API Docs
open http://localhost:8000/redoc  # API Reference
```
