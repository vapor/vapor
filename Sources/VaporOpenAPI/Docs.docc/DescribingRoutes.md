# Describing Routes

Say what a route takes and returns, for one route or for every route in a group.

## Overview

`openAPI(...)` returns a routes builder that records its details on every route registered
through it, the same way `grouped(_:)` adds middleware:

```swift
app.openAPI(summary: "Get a pet", path: .type(PetPath.self), response: .type(Pet.self))
    .get("pets", ":petID") { req in … }
```

Every detail is optional. A route registered without `openAPI(...)` is still in the document,
with its path, method and path parameters, and with its handler's return type as its response.

### Groups

Details given to a group reach every route in it:

```swift
let admin = app.grouped("admin").openAPI(tags: ["Admin"], auth: [.bearer()])
admin.get("users") { … }
admin.openAPI(summary: "Delete a user", deprecated: true).delete("users", ":id") { … }
```

A route's own summary, description, body, response and status replace its group's. Tags,
content types and auth add up, with a route's scopes for a scheme replacing its group's.
Parameters from a group and a route are combined, and a route can undo its group's
deprecation with `deprecated: false`.

To leave routes out of the document, such as a health check, register them through
`hiddenFromOpenAPI()`.

### Parameters and bodies

Parameters and bodies are described by a type or by an example value:

```swift
struct PetFilter: Codable {
    var status: Status?
    var limit: Int?
}

app.openAPI(query: .type(PetFilter.self)).get("pets") { … }
app.openAPI(body: .example(NewPet(name: "Tom", tag: "cat"))).post("pets") { … }
```

Each property of a parameters type is a parameter, optional ones not required. `query:`,
`headers:`, `path:` and `cookies:` take ``OpenAPIParameters``, and combine with `.all(of:)` or
an array literal. `body:` and `response:` take ``OpenAPIBody``, which can also be a `.one(of:)`,
`.any(of:)`, `.all(of:)` or `.not(_:)` of others.

A type's schema is worked out from what its `init(from:)` decodes. Objects and enums are stored
in the document's components and referred to by `$ref`, and recursive types refer to
themselves. Types that can't be decoded with placeholder values, or that should say more than
their structure does, can describe themselves with ``OpenAPISchemaProvider``:

```swift
struct Money: Codable, OpenAPISchemaProvider {
    static var openAPISchema: OpenAPISchema { .string(format: .other("decimal")) }
}
```

An enum that's `CaseIterable`, with `String` or `Int` raw values, is described as an
enumeration of its cases with no conformance needed:

```swift
enum Status: String, Codable, CaseIterable {
    case available, pending, sold
}
```

### Responses

A route's response is its `response:`, or else its handler's return type, or else none. Its
status is `statusCode:`, `200 OK` by default, and its content type is the body type's
`Content.defaultContentType`, such as `text/plain` for a `String`, unless `responseContentTypes:`
says otherwise.

A handler that returns a status, such as `HTTPResponse.Status.noContent`, returns a value, not
a type, so give it with `statusCode:`:

```swift
app.openAPI(statusCode: .noContent).delete("pets", ":id") { req in … return .noContent }
```

### Auth

``OpenAPIAuth`` describes how an operation is authorized. Schemes are collected into the
document's components by their id, derived from the kind of scheme unless you give one:

```swift
app.openAPI(auth: [.bearer(format: "JWT"), .apiKey(name: "X-API-Key")]).get("me") { … }
app.openAPI(auth: [.oauth2(id: "petstore", flows: flows).scopes("read:pets")]).get("pets") { … }
```

Two schemes of the same kind that differ in more than their descriptions, such as two OpenID
Connect providers, need ids of their own.

### Links

Links tell clients which response values other operations take. Declare a key for each kind
of value, and mark where it's returned and where it's taken:

```swift
enum PetID: OpenAPILinkKey {}

app.openAPI(response: .type(Pet.self), links: [OpenAPILink("id", in: .response(.body)): PetID.self])
    .post("pets") { … }
app.openAPI(operationID: "getPet", links: [OpenAPILink("petID", in: .request(.path)): PetID.self])
    .get("pets", ":petID") { … }
```

Every response value is linked to every request value with the same key.
