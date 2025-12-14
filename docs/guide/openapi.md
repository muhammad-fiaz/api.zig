# OpenAPI

api.zig automatically generates OpenAPI 3.1 specifications and serves interactive documentation.

## Built-in Documentation

When you run your server, these endpoints are automatically available:

| Endpoint        | Description               |
| --------------- | ------------------------- |
| `/openapi.json` | OpenAPI 3.1 specification |
| `/docs`         | Interactive API Docs      |
| `/redoc`        | API Reference             |

## Accessing Documentation

Start your server:

```bash
zig build run
```

Visit:

- **API Docs:** http://localhost:8000/docs
- **API Reference:** http://localhost:8000/redoc
- **OpenAPI JSON:** http://localhost:8000/openapi.json

## App Configuration

Configure API metadata:

```zig
var app = api.App.init(allocator, .{
    .title = "My API",
    .version = "1.0.0",
    .description = "A sample API built with api.zig",
});
```

## OpenAPI Schema

api.zig includes schema generation utilities:

```zig
const api = @import("api");
const Schema = api.Schema;

// Create schemas
const string_schema = Schema.string();
const int_schema = Schema.integer();
const number_schema = Schema.number();
const bool_schema = Schema.boolean();
const object_schema = Schema.object();
```

## Schema from Types

Generate schemas from Zig types:

```zig
const api = @import("api");

const UserSchema = api.schemaFromType(struct {
    id: u32,
    name: []const u8,
    email: []const u8,
    active: bool,
});
```

## OpenAPI Object

Create OpenAPI specifications programmatically:

```zig
const openapi = api.OpenAPI.init(allocator, .{
    .title = "My API",
    .version = "1.0.0",
    .description = "API description",
});
```

## Example Output

The generated OpenAPI spec looks like:

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "My API",
    "version": "1.0.0"
  },
  "paths": {
    "/users": {
      "get": {
        "summary": "List users",
        "responses": {
          "200": {
            "description": "Success"
          }
        }
      }
    }
  }
}
```

## Interactive API Docs Features

The interactive documentation provides:

- Interactive API explorer
- Request builder
- Response viewer
- Authentication support
- Schema visualization

## API Reference Features

The API reference provides:

- Clean documentation layout
- Search functionality
- Code samples
- Schema definitions
