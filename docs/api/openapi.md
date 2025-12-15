# OpenAPI

OpenAPI 3.1 specification generator with automatic schema inference from Zig types. Generates JSON specifications for interactive API documentation.

## Import

```zig
const api = @import("api");
const OpenAPI = api.OpenAPI;
const Schema = api.Schema;
const SchemaBuilder = api.SchemaBuilder;
```

## SchemaBuilder Methods

| Method | Description |
|--------|-------------|
| `string()` | String type |
| `integer()` | Integer type |
| `int32()` | 32-bit integer |
| `int64()` | 64-bit integer |
| `number()` | Number type |
| `float()` | 32-bit float |
| `double()` | 64-bit float |
| `boolean()` | Boolean type |
| `email()` | Email format string |
| `uuid()` | UUID format string |
| `date()` | Date format string |
| `dateTime()` | DateTime format string |
| `uri()` | URI format string |
| `password()` | Password format string |
| `array(items)` | Array with item schema |
| `object()` | Object schema |
| `nullable()` | Make nullable |

## OpenAPI.Info

| Field | Type | Description |
|-------|------|-------------|
| `title` | `[]const u8` | API title |
| `version` | `[]const u8` | API version |
| `description` | `?[]const u8` | API description |
| `terms_of_service` | `?[]const u8` | Terms URL |
| `contact` | `?Contact` | Contact info |
| `license` | `?License` | License info |

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

## Schema Types

| Type | Constant | Description |
|------|----------|-------------|
| String | `.string` | Text values |
| Integer | `.integer` | Whole numbers |
| Number | `.number` | Decimal numbers |
| Boolean | `.boolean` | True/false |
| Array | `.array` | List of items |
| Object | `.object` | Key-value pairs |
| Null | `.null_type` | Null value |

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

## Built-in Endpoints

| Endpoint | Description |
|----------|-------------|
| `/openapi.json` | OpenAPI 3.1 JSON specification |
| `/docs` | Swagger UI (Interactive API Documentation) |
| `/redoc` | ReDoc (API Reference) |

## App Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `title` | `[]const u8` | `"API"` | OpenAPI title |
| `version` | `[]const u8` | `"0.0.0"` | API version |
| `description` | `?[]const u8` | `null` | API description |
| `docs_url` | `[]const u8` | `"/docs"` | Swagger UI path |
| `redoc_url` | `[]const u8` | `"/redoc"` | ReDoc path |
| `openapi_url` | `[]const u8` | `"/openapi.json"` | Spec path |

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
