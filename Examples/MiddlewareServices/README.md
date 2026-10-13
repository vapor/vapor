# Middleware services and macros

This compile example uses the real `FluentKit.Databases` and `Vapor.Client` types.
It follows [vapor/template's controller injection](https://github.com/vapor/template/blob/vapor5/Sources/App/Controllers/TodoController.swift):
the application configures and owns `Databases`, manages its service lifecycle,
and passes it to controller initializers. Middleware receives that same service.
FluentKit stays an example dependency; Vapor does not acquire a Fluent dependency.

From the repository root:

```sh
swift build --package-path Examples/MiddlewareServices
swift test --filter VaporMacro
swift test --filter TaskLocalRequestContextTests
```

The example compiles database queries but does not run a server, connect to a
database, or send HTTP requests. An application must supply its configured
database service, schema, and client. The integration tests use a deterministic
`Client` implementation and exercise real route registration and requests.

## Compare the three APIs in Development

Run `swift run Development` from the repository root and use the port printed in
the `Server started` log. The examples in
[`Sources/Development/MiddlewareServiceExamples.swift`](../../Sources/Development/MiddlewareServiceExamples.swift)
use the same authentication and service-header middleware with three injection styles:

| Style | Grouped authentication route | Service source |
| --- | --- | --- |
| Key path | `/api/macros/middleware/key-path/me` | `using: \Self.authentication` |
| Typed factory | `/api/macros/middleware/factory/me` | `using: { (controller: Self) in ... }` |
| Task local | `/api/macros/middleware/task-local/me` | A client bound with `withValue` during registration |

Each controller also exposes `/attached` in place of `/me` to demonstrate the
individual-handler `@AuthMiddleware` form. All six routes return `{"name":"Vapor"}`
when sent `Authorization: Bearer demo-token`, and return 401 for a missing or
invalid token. The `/me` routes also run `#Middleware` and return the
`X-Example-Service: example-api` header. For example:

```sh
development_port=12345 # Replace with the port from the server log.
curl -i -H 'Authorization: Bearer demo-token' \
  "http://127.0.0.1:${development_port}/api/macros/middleware/key-path/me"
```

The example client responds in process, so these routes need no database or
external API. The task-local example captures its client during registration;
its binding has ended by the time requests arrive.

`MiddlewareServicesIntegrationTests` runs the same cases against all three styles:
two independently registered service instances, attached and grouped auth,
required and optional users, missing and invalid credentials, and middleware
order. Rebinding the task local during requests must not change the captured
service. Separate loopback tests exercise dynamic task-local reads inside macro
middleware, checking both a serving-scope binding and a missing binding, including
that the HTTP caller's context does not become the server's context.

## Recommended API

Keep dependencies in the controller and expose the middleware through a stored
or computed property:

```swift
@Controller
struct UserController {
    let databases: Databases

    var authentication: DatabaseAuthenticator {
        DatabaseAuthenticator(databases: databases)
    }

    #AuthMiddleware(DatabaseUser.self, using: \Self.authentication) {
        @GET("users", "me")
        func me(req: Request, user: DatabaseUser) async throws -> String {
            user.name
        }
    }
}
```

`using:` also accepts a typed factory when an extra middleware property would be
unnecessary:

```swift
#Middleware(using: { (controller: Self) in APIMiddleware(client: controller.client) }) {
    // Route handlers, or nested middleware groups.
}
```

Both forms also work on a single handler:

```swift
@GET("users", "me")
@AuthMiddleware(DatabaseUser.self, using: \Self.authentication)
func me(req: Request, user: DatabaseUser) async throws -> String { user.name }
```

The overload accepts `(Controller) -> any Middleware`. Swift's key-path-to-function
conversion permits a key-path literal through that same typed interface. The
expansion evaluates it as `self[keyPath: \Self.authentication]`, or calls the
factory with `self`, inside `boot(routes:)`. Key paths defer **instance access**;
their names and value types are still checked before expansion. Missing properties
and properties that are not middleware produce compiler errors.

Factories/computed properties are evaluated during registration, once per route.
Use a stored middleware property for shared middleware identity. Neither form
creates a new database pool or client unless the application explicitly does so
in its factory. Nest groups to compose controller-dependent middleware. Existing
variadic middleware values remain supported for dependencies available at type scope.

## Results on Swift 6.4

Tested with Apple Swift 6.4 (`swiftlang-6.4.0.34.1`) on arm64 macOS, using the
grouping implementation from PR #3464 at `f232b4ea` as the starting point.

| Approach | Result | Assessment |
| --- | --- | --- |
| `Auth(databases: databases)` at the macro site | Fails: instance member cannot be used on the controller type | There is no controller instance in declaration scope. |
| `Auth(databases: self.databases)` | Fails: `self` is not in scope | Adding `self` does not defer lookup. |
| Erasing the argument to `Any`, or wrapping it in `@autoclosure` | Both fail with the same instance-member error | Argument type changes do not change its lexical scope. |
| Key path with the original PR's arbitrary-name group macros | Fails with a circular macro expansion | Name discovery also needs to be fixed. |
| `using: \Self.authentication` with the revised expansion | Compiles and passes request tests | Shortest explicit API for stored or computed middleware. |
| `using: { (controller: Self) in Auth(databases: controller.databases) }` | Compiles and passes request tests | Useful inline alternative with no ambient state. |
| A static `@TaskLocal` service reference | Compiles and passes a registration-capture test | Viable, but dependencies and their binding scope are implicit. |

When the middleware initializer reads a task local, bind it while the generated
registration code runs. The tested middleware stores the client and can therefore
serve requests after the binding ends. Reading a task local later inside `respond`
instead depends on the request task's context. Merely registering a handler inside
`withValue` does not capture that context for future requests.

The current Vapor 5 server handles connections and requests in child tasks of the
serving task. A binding enclosing `app.run()` reaches request handlers; a binding
enclosing only `routes(app)` does not. `TaskLocalRequestContextTests` verifies both
cases with real loopback HTTP requests, including that registration-time capture
continues to work and the HTTP client's task-local value does not reach the server.
Separate integration tests confirm that a detached task does not inherit a
binding. File location, such as `routes.swift`, does not determine the binding's
lifetime. These scope requirements make task locals less suitable as the default
pool/client injection API than controller properties.

## Why the macro expansion changes are necessary

These are changes to Vapor's macro implementation, not a Swift compiler patch.
They work with the tested Swift 6.4 toolchain; upgrading to 6.4 alone does not
resolve the original implementation's lookup failures.

The original freestanding group macros advertise `names: arbitrary` and lift
handlers themselves. Resolving a controller property can require discovering those
generated members, which requires type-checking the group's arguments, which
requires resolving that same property. Key paths and typed closures still trigger
this cycle on the original PR.

The revised implementation makes `#Middleware` and `#AuthMiddleware` declaration
markers that generate no names. `@Controller` performs the member expansion from
the original syntax, before those argument lookups. HTTP peer macros advertise
their actual `_route_` and `_register_` prefixes instead of arbitrary names.

Controller member generation and route registration share one traversal, preserving
outer-to-inner middleware order. Auth middleware from each enclosing scope runs;
the nearest auth declaration selects the type injected into the handler. The
shared traversal handles both trailing closures and explicit `body:` arguments.
Groups outside `@Controller` and unsupported declarations inside a group are
diagnosed rather than silently discarded.

This uses supported macro roles and typed arguments, without strings naming
dependencies, dummy static properties, or global service registries. The Swift
model requires [type-checked macro arguments](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0389-attached-macros.md).

One existing grouping limitation remains: the original group body is still checked
as a closure at declaration scope. A handler written inside it cannot directly
refer to controller `self`; an ordinary controller method with attached
`@AuthMiddleware(..., using: ...)` can. The changes here resolve middleware
dependencies; they do not change the lexical scope of the group body.
