# Path Parameters

Extract dynamic values from URL paths using path parameters.

## Basic Usage

Define path parameters using `{name}` syntax:

```zig
try app.get("/users/{id}", getUser);
```

Extract in handlers:

```zig
fn getUser(ctx: *api.Context) api.Response {
    const id = ctx.param("id") orelse "0";
    // id contains the value from the URL
    return api.Response.text(id);
}
```

## Multiple Parameters

```zig
try app.get("/users/{user_id}/posts/{post_id}", getUserPost);

fn getUserPost(ctx: *api.Context) api.Response {
    const user_id = ctx.param("user_id") orelse "0";
    const post_id = ctx.param("post_id") orelse "0";

    // Use both parameters...
    _ = user_id;
    _ = post_id;

    return api.Response.jsonRaw("{\"user_id\":1,\"post_id\":1}");
}
```

## Type Conversion

Path parameters are strings. Convert them as needed:

```zig
fn getUser(ctx: *api.Context) api.Response {
    const id_str = ctx.param("id") orelse "0";
    const id = std.fmt.parseInt(u32, id_str, 10) catch 0;

    // id is now u32
    _ = id;

    return api.Response.jsonRaw("{}");
}
```

## Nested Resources

```zig
// Organizations -> Projects -> Tasks
try app.get("/orgs/{org_id}/projects/{project_id}/tasks/{task_id}", getTask);

fn getTask(ctx: *api.Context) api.Response {
    const org_id = ctx.param("org_id") orelse "0";
    const project_id = ctx.param("project_id") orelse "0";
    const task_id = ctx.param("task_id") orelse "0";

    _ = org_id;
    _ = project_id;
    _ = task_id;

    return api.Response.jsonRaw("{\"task\":\"example\"}");
}
```

## String Parameters

Path parameters work with any string value:

```zig
try app.get("/greet/{name}", greetUser);

fn greetUser(ctx: *api.Context) api.Response {
    const name = ctx.param("name") orelse "World";

    var buf: [128]u8 = undefined;
    const message = std.fmt.bufPrint(&buf, "Hello, {s}!", .{name}) catch "Hello!";

    return api.Response.text(message);
}
```

**Request:** `GET /greet/Alice`  
**Response:** `Hello, Alice!`

## Route Matching Examples

| Route Pattern                 | Request Path       | Matches | Parameters              |
| ----------------------------- | ------------------ | ------- | ----------------------- |
| `/users/{id}`                 | `/users/123`       | ✅      | id = "123"              |
| `/users/{id}`                 | `/users/`          | ❌      | -                       |
| `/users/{id}/posts/{post_id}` | `/users/1/posts/5` | ✅      | id = "1", post_id = "5" |
| `/files/{path}`               | `/files/docs`      | ✅      | path = "docs"           |

## Path Matching Function

For testing or custom routing:

```zig
const result = api.router.matchPath("/users/{id}", "/users/123");

if (result) |params| {
    const id = params.get("id"); // "123"
}
```
