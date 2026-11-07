# Limitations

What the document can't tell from the code, and how to describe it instead.

## Overview

Schemas are worked out by decoding each type from placeholder values and recording what it
asks for. That covers most `Codable` types, but not everything a type can do, and the routes
themselves don't say everything about their responses.

### Decoding

- **Nested containers and superclass decoders.** A type whose `init(from:)` calls
  `nestedContainer`, `nestedUnkeyedContainer` or `superDecoder` can't be described. Describe it
  with ``OpenAPISchemaProvider``. A subclass that calls `super.init(from: decoder)` is fine.
- **Optional fields read by hand.** An `init(from:)` that checks `contains(_:)` or
  `decodeNil(forKey:)` before decoding a field is told every key is there and not null, so the
  field is documented as required. Use `decodeIfPresent`, or describe the type yourself.
- **Placeholder values.** The placeholders are values such as `""`, `0` and the nil UUID. An
  `init(from:)` that rejects them can give its own with `openAPIPlaceholder`; one that traps on
  them, such as with `URL(string: s)!`, stops the application when the document is built at
  boot.
- **Recursion through itself.** A type that contains itself and is also a collection or
  `ExpressibleByNilLiteral`, such as a JSON value enum, can't be described.
- **Encoding settings.** Property names and examples come from the types' coding keys and a
  plain `JSONEncoder`, so key and date strategies set in `ContentConfiguration` aren't applied.

### Responses

- **One response.** Each operation documents one successful response. Error responses, such
  as `404 Not Found`, aren't described.
- **Statuses as values.** A handler that returns `HTTPResponse.Status` needs `statusCode:`.

### Macro routes

Routes declared with `@GET`, `@POST` and the other route macros are in the document, with
their paths and methods, and a `@Controller`'s routes take the details of the group it's
registered through:

```swift
try app.openAPI(tags: ["Pets"]).register(collection: PetController())
```

But they can't yet be described one by one:

- their return types aren't their responses, since the macros return a `Response`. Describe
  them with the group, or register them without a macro.
- a single route in a `@Controller` can't have its own details.
- their path parameters have generated names, such as `int0`, and are documented as strings.

A freestanding `#GET` can be described through the builder it's registered on:
`#GET(on: app.openAPI(summary: "List pets"), "pets") { … }`.
