# ``VaporOpenAPI``

Describe your routes where you register them, and serve an OpenAPI document built from them.

## Overview

VaporOpenAPI builds an [OpenAPI 3.2](https://spec.openapis.org/oas/v3.2.0) document from an
application's routes. Each route is described where it's registered, and the schemas for its
parameters and bodies are worked out from the Swift types it uses, so the document follows the
code instead of being written alongside it.

It's part of Vapor, behind the `OpenAPI` package trait. Turn the trait on alongside Vapor's
default traits, which a list of traits otherwise replaces, and depend on the `VaporOpenAPI`
product:

```swift
.package(url: "https://github.com/vapor/vapor.git", from: "5.0.0", traits: [.defaults, "OpenAPI"]),
```

```swift
.product(name: "VaporOpenAPI", package: "vapor"),
```

Then describe routes, and serve the document with a page to browse it:

```swift
import Vapor
import VaporOpenAPI

func routes(_ app: Application) throws {
    let pets = app.grouped("pets").openAPI(tags: ["Pets"], auth: [.bearer(format: "JWT")])

    pets.openAPI(summary: "List pets", query: .type(PetFilter.self))
        .get { req async throws -> [Pet] in … }

    pets.openAPI(summary: "Add a pet", body: .type(NewPet.self), statusCode: .created)
        .post { req async throws -> Pet in … }

    app.openAPIDocumentation("docs", info: OpenAPIInfo(title: "Petstore", version: "1.0.0"))
}
```

`GET /docs` shows the API, and `GET /docs/openapi.json` serves the document. A handler's return
type, such as `[Pet]` here, is its response unless the route describes one.

## Topics

### Essentials

- <doc:DescribingRoutes>
- <doc:ServingTheDocumentation>
- <doc:Limitations>

### Describing routes

- ``OpenAPIBody``
- ``OpenAPIParameters``
- ``OpenAPIAuth``
- ``OpenAPILink``
- ``OpenAPILinkKey``

### Describing types

- ``OpenAPISchemaProvider``
- ``OpenAPISchema``

### Building the document

- ``OpenAPIDocument``
- ``OpenAPIInfo``
- ``OpenAPIDocumentError``
