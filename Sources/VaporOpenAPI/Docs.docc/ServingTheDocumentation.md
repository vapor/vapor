# Serving the Documentation

Serve the document and a page to browse it, or build the document yourself.

## Overview

`openAPIDocumentation(...)` registers two routes: a page that shows the API with
[Stoplight Elements](https://stoplight.io/open-source/elements), and the document it loads:

```swift
app.openAPIDocumentation("docs", info: OpenAPIInfo(title: "Petstore", version: "1.0.0"))
// GET /docs              the page
// GET /docs/openapi.json the document
```

Both routes are hidden from the document. Register them through a group to protect them, or
only in some environments:

```swift
if app.environment != .production {
    app.grouped(AdminAuthenticator()).openAPIDocumentation("docs", of: app, info: info)
}
```

The page loads Elements from a CDN, pinned to one version and checked against its hashes.

### When the document is built

The document is built once, when the application boots, from the routes registered by then,
and every request is served the same bytes. Register the documentation before the application
boots. Routes added afterwards aren't in the document, including those that a lifecycle handler
registered after the documentation adds in its own `didBoot`.

Until the application has booted, `openapi.json` responds with 503 Service Unavailable.

### Routes that can't be described

A route OpenAPI can't express doesn't stop the application from starting. The error is
logged, and `openapi.json` responds with 500 Internal Server Error, naming the route and how to
fix it, except in release builds, which say only to see the log. This happens for:

- a catch-all `**`, such as a single-page app's fallback. Register it through
  `hiddenFromOpenAPI()`.
- a constant path segment with braces, such as `file-{name}.zip`.
- the same method and path registered twice, or paths that differ only in their parameters'
  names, such as `/users/:id` and `/users/:userID`.
- two routes with one operation ID, or one auth id used for two different schemes.
- a `body:`, `response:` or parameters type that can't be described, or a `path:` parameter the
  path doesn't have.
- a link to a parameter its target operation doesn't have, or into a request body.

A handler's return type never fails the document: one that can't be described is left out,
and logged at debug level.

### Building the document yourself

`app.routes.openAPI(info:)` builds the document directly, for a route of your own, a file
written at build time, or a test:

```swift
let document = try app.routes.openAPI(info: OpenAPIInfo(title: "Petstore", version: "1.0.0"))
let json: Data = try document.json()
```

``OpenAPIDocument/json()`` sorts keys, so the output is the same on every run. A document can
also be returned from a handler as it is. It throws ``OpenAPIDocumentError``, naming the route
and why it can't be described.
