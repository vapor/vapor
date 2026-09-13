/// How much of a request body ``Request/Body/collect(max:)`` and its relatives will buffer.
///
/// Bodies are lazy: nothing is held in memory until something asks for it, and this is the ceiling
/// that applies when it does. Both literal forms of ``ByteCount`` work directly, so the common cases
/// need no case name:
///
///     try await req.body.collect()                // .default
///     try await req.body.collect(max: "1mb")      // .specified
///     try await req.body.collect(max: 4096)       // .specified
public enum BodySizeLimit: Sendable, Equatable {
    /// The request's ``Request/maxBodySize``.
    ///
    /// That starts at the application's ``Routes/defaultMaxBodySize`` and is whatever the route or
    /// an earlier middleware last set it to, so this is the limit the application configured for
    /// this request rather than a fixed number.
    case `default`

    /// No ceiling: buffer the body however large it turns out to be.
    ///
    /// - Warning: This is an unbounded allocation driven by whoever sent the request. It is safe
    ///   only where the size is already known to be bounded — a test, or a body this process
    ///   produced itself. Anywhere a client controls the length, prefer ``specified(_:)``.
    case unlimited

    /// An explicit ceiling, regardless of what the request or the application is configured for.
    case specified(ByteCount)
}

extension BodySizeLimit: ExpressibleByIntegerLiteral {
    /// A ceiling in bytes.
    public init(integerLiteral value: Int) {
        self = .specified(ByteCount(value: value))
    }
}

extension BodySizeLimit: ExpressibleByStringLiteral {
    /// A ceiling written the way ``ByteCount`` writes one, such as `"1mb"`.
    public init(stringLiteral value: String) {
        self = .specified(ByteCount(stringLiteral: value))
    }
}

extension BodySizeLimit {
    /// The ceiling in bytes, resolving ``default`` against the request it applies to.
    func bytes(for request: Request) -> Int {
        switch self {
        case .default: request.maxBodySize.value
        case .unlimited: .max
        case .specified(let count): count.value
        }
    }
}
