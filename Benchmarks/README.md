# Vapor Benchmarks

Performance benchmarks for Vapor, built on [ordo-one/benchmark](https://github.com/ordo-one/benchmark).

This is a **separate package** from Vapor itself, so the benchmark dependencies never end up in
Vapor's manifest and downstream consumers don't have to resolve them.

## Running

From this directory:

```sh
swift package --disable-sandbox benchmark                          # everything
swift package --disable-sandbox benchmark --filter 'routing/.*'    # one area
swift package --disable-sandbox benchmark --filter 'auth/.*'
```

To check a change for regressions, record a baseline before it and compare after:

```sh
swift package --disable-sandbox benchmark baseline update main
# ...make your change...
swift package --disable-sandbox benchmark baseline compare main
```

## What is measured

**Instruction counts and malloc counts are the signal.** They're deterministic, so they don't need a
quiet machine and they make small regressions visible. Wall clock is recorded for context but is
noisy and shouldn't gate anything.

Every benchmark uses `scalingFactor: .kilo` — a single operation is far cheaper than the cost of
taking one sample, so a thousand run per sample and the results are scaled back down. Without it
every benchmark reports the same ~30K instructions of measurement overhead.

## Areas

| prefix | covers |
|---|---|
| `request/` | `Request` creation, header access, URI and `Authorization` header parsing |
| `auth/` | the authentication cache, and full requests through the authenticator middleware |
| `routing/` | trie routing: static, path parameters, catchall, 404s, method dispatch, scale |
| `response/` | each handler return type — `String`, `Content`, status, `Response`, `ByteBuffer` |
| `content/` | JSON and URL-encoded decoding, query strings, coders in isolation |
| `middleware/` | per-layer chain cost, error handling, CORS, sessions |
| `macro-routing/` | `@Controller`/`@GET` routes, each paired with a hand-written equivalent |

Benchmarks that drive a whole request build a fresh `Request` per iteration, which is what a real
server does. Subtract `request/create` to isolate the routing and handler cost.

Where a number is only meaningful as a comparison, the suite includes the pair: every
`macro-routing/` benchmark has a hand-written equivalent, and `middleware/chain N layers` is a series
whose differences give the per-layer cost.

## A note on `BenchmarkResponder`

Vapor's `DefaultResponder` is `package`-scoped and so invisible from this package, and `VaporTesting`
can't be linked into a non-test executable because it depends on swift-testing. `Support.swift`
therefore contains `BenchmarkResponder`, a copy of `DefaultResponder` assembled from public API
(`Routes.all`, `Route.responder`, `[any Middleware].makeResponder(chainingTo:)` and RoutingKit's
trie), so the same machinery is exercised.

**Keep it in step with `Sources/Vapor/Responder/DefaultResponder.swift`.** The only deliberate
difference is that a 404 throws `Abort(.notFound)` rather than `RouteNotFound`, whose initialiser is
internal; both are `AbortError`s with the same status.
