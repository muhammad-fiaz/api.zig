# HTML Pages Example

Serving HTML pages with embedded CSS styling. Demonstrates how to build server-rendered web pages with api.zig.

## Features

- Modern responsive HTML templates
- Embedded CSS styling
- Navigation between pages
- Mixed HTML and JSON endpoints

## Source Code

```zig
//! @file html_pages.zig
//! @brief HTML Pages Example - Server-Side Rendered Web Pages

const std = @import("std");
const api = @import("api");

/// Home page HTML template with modern styling.
const home_page_html =
    \\<!DOCTYPE html>
    \\<html lang="en">
    \\<head>
    \\    <meta charset="UTF-8">
    \\    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    \\    <title>api.zig</title>
    \\    <style>
    \\        * { margin: 0; padding: 0; box-sizing: border-box; }
    \\        body {
    \\            font-family: system-ui, -apple-system, sans-serif;
    \\            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    \\            min-height: 100vh;
    \\            display: flex;
    \\            align-items: center;
    \\            justify-content: center;
    \\        }
    \\        .container {
    \\            background: white;
    \\            border-radius: 16px;
    \\            padding: 48px;
    \\            box-shadow: 0 20px 40px rgba(0,0,0,0.2);
    \\            text-align: center;
    \\            max-width: 500px;
    \\        }
    \\        h1 { color: #667eea; margin-bottom: 16px; }
    \\        p { color: #666; margin-bottom: 24px; }
    \\        a {
    \\            display: inline-block;
    \\            padding: 10px 24px;
    \\            background: #667eea;
    \\            color: white;
    \\            text-decoration: none;
    \\            border-radius: 8px;
    \\            margin: 0 8px;
    \\        }
    \\    </style>
    \\</head>
    \\<body>
    \\    <div class="container">
    \\        <h1>api.zig</h1>
    \\        <p>High-performance web framework for Zig</p>
    \\        <a href="/docs">API Docs</a>
    \\        <a href="/redoc">ReDoc</a>
    \\    </div>
    \\</body>
    \\</html>
;

/// About page HTML template.
const about_page_html =
    \\<!DOCTYPE html>
    \\<html lang="en">
    \\<head>
    \\    <meta charset="UTF-8">
    \\    <title>About</title>
    \\    <style>body { font-family: system-ui; padding: 40px; }</style>
    \\</head>
    \\<body>
    \\    <h1>About api.zig</h1>
    \\    <p>A high-performance web framework for Zig.</p>
    \\    <a href="/">Back to Home</a>
    \\</body>
    \\</html>
;

/// Home page handler.
fn homePage() api.Response {
    return api.Response.html(home_page_html);
}

/// About page handler.
fn aboutPage() api.Response {
    return api.Response.html(about_page_html);
}

/// API endpoint handler.
fn apiEndpoint(ctx: *api.Context) api.Response {
    _ = ctx;
    return api.Response.jsonRaw(
        \\{"status":"ok"}
    );
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{
        .title = "HTML Pages Example",
        .version = "1.0.0",
    });
    defer app.deinit();

    try app.get("/", homePage);
    try app.get("/about", aboutPage);
    try app.get("/api", apiEndpoint);

    try app.run(.{ .port = 8000 });
}
```

## Running

```bash
zig build run
```

## Output

```
[OK] http://127.0.0.1:8000
[INFO]   /docs   - Interactive API Documentation
[INFO]   /redoc  - API Reference
[INFO] GET /
[INFO] GET /about
```

## Pages

| Route    | Description       |
| -------- | ----------------- |
| `/`      | Styled home page  |
| `/about` | About page        |
| `/api`   | JSON API endpoint |
| `/docs`  | Interactive API Docs |
| `/redoc` | ReDoc             |

## Screenshot

When you visit `http://localhost:8000/`, you'll see a beautifully styled page with:

- Gradient background (purple to blue)
- White card with shadow
- Title and description
- Links to documentation

## Key Features

- **HTML responses**: Using `api.Response.html()`
- **CSS styling**: Inline CSS for modern design
- **Mixed content**: Both HTML pages and JSON API
- **Responsive design**: Works on all screen sizes

## Response Types

| Method | Content-Type | Description |
|--------|-------------|-------------|
| `Response.html()` | `text/html; charset=utf-8` | HTML pages |
| `Response.text()` | `text/plain; charset=utf-8` | Plain text |
| `Response.jsonRaw()` | `application/json` | Raw JSON string |
| `Response.json()` | `application/json` | Serialize Zig struct |
| `Response.xml()` | `application/xml` | XML content |

### Response Examples

```zig
// HTML response
api.Response.html("<h1>Hello</h1>")

// JSON response
api.Response.jsonRaw("{\"key\":\"value\"}")

// Text response
api.Response.text("Plain text")

// Custom content type
api.Response.text(css_content).setContentType("text/css")

// Set status code
api.Response.html("<h1>Not Found</h1>").setStatus(.not_found)

// Add custom headers
api.Response.html(page).addHeader("X-Custom", "value")
```

## Response Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `.setStatus()` | `Response` | Set HTTP status code |
| `.setContentType()` | `Response` | Override Content-Type header |
| `.addHeader()` | `Response` | Add custom header |
| `.redirect()` | `Response` | Create redirect response |
| `.init()` | `Response` | Create empty response |

## Common Content Types

api.zig provides pre-defined content types via `api.ContentTypes`:

| Constant | Value |
|----------|-------|
| `ContentTypes.HTML` | `text/html; charset=utf-8` |
| `ContentTypes.TEXT` | `text/plain; charset=utf-8` |
| `ContentTypes.JSON` | `application/json` |
| `ContentTypes.XML` | `application/xml` |
| `ContentTypes.CSS` | `text/css` |
| `ContentTypes.JS` | `application/javascript` |
| `ContentTypes.BINARY` | `application/octet-stream` |

## Key Features

- **HTML responses**: Using `api.Response.html()` with proper charset
- **CSS styling**: Inline CSS for modern design patterns
- **Mixed content**: Both HTML pages and JSON API on same server
- **Responsive design**: Works on all screen sizes
- **Auto documentation**: Swagger UI and ReDoc at `/docs` and `/redoc`
