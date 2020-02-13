import NIO

// Comments on these properties are copied from the mozilla doc URL shown below.
extension HTTPHeaders {
    /// Represents the HTTP `Cache-Control` header.
    /// - See Also:
    /// [Cache-Control docs](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cache-Control)
    public struct CacheControl: OptionSet {
        // MARK: - Option Values

        /// Indicates that once a resource becomes stale, caches must not use their stale copy without
        /// successful [validation](https://developer.mozilla.org/en-US/docs/Web/HTTP/Caching#Cache_validation) on the origin server.
        public static let mustRevalidate = Self(rawValue: 1 << 0)

        /// Caches must check with the origin server for
        /// [validation](https://developer.mozilla.org/en-US/docs/Web/HTTP/Caching#Cache_validation) before using the cached copy.
        public static let noCache = Self(rawValue: 1 << 1)

        /// The cache **should not store anything** about the client request or server response.
        public static let noStore = Self(rawValue: 1 << 2)

        /// No transformations or conversions should be made to the resource. The Content-Encoding, Content-Range, Content-Type headers must not be modified
        /// by a proxy. A non-transparent proxy or browser feature such as
        /// [Google's Light Mode](https://support.google.com/webmasters/answer/6211428?hl=en) might, for example, convert between image
        /// formats in order to save cache space or to reduce the amount of traffic on a slow link. The `no-transform` directive disallows this.
        public static let noTransform = Self(rawValue: 1 << 3)

        /// The response may be cached by any cache, even if the response is normally non-cacheable
        public static let isPublic = Self(rawValue: 1 << 4)

        /// The response is for a single user and **must not** be stored by a shared cache. A private cache (like the user's browser cache) may store the response.
        public static let isPrivate = Self(rawValue: 1 << 5)

        /// Like `must-revalidate`, but only for shared caches (e.g., proxies). Ignored by private caches.
        public static let proxyRevalidate = Self(rawValue: 1 << 6)

        /// Indicates to not retrieve new data. This being the case, the server wishes the client to obtain a response only once and then cache. From this moment the
        /// client should keep releasing a cached copy and avoid contacting the origin-server to see if a newer copy exists.
        public static let onlyIfCached = Self(rawValue: 1 << 7)

        /// Indicates the client will accept a stale response.  If the `maxStale` property is set, indicates the upper limit of staleness the client will accept.
        public static let maxStale = Self(rawValue: 1 << 8)

        /// Indicates that the response body **will not change** over time.
        ///
        /// The resource, if *unexpired*, is unchanged on the server and therefore the client should
        /// not send a conditional revalidation for it (e.g. `If-None-Match` or `If-Modified-Since`) to check for updates, even when the user explicitly refreshes
        /// the page. Clients that aren't aware of this extension must ignore them as per the HTTP specification. In Firefox, immutable is only honored on https:// transactions.
        /// For more information, see also this [blog post](https://bitsup.blogspot.de/2016/05/cache-control-immutable.html).
        public static let immutable = Self(rawValue: 1 << 9)

        // MARK: - Properties
        public var rawValue = 0

        /// The maximum amount of time a resource is considered fresh. Unlike the`Expires` header, this directive is relative to the time of the request.
        public var maxAge: Int?

        /// Overrides max-age or the Expires header, but only for shared caches (e.g., proxies). Ignored by private caches.
        public var sMaxAge: Int?

        /// Indicates the client will accept a stale response. An optional value in seconds indicates the upper limit of staleness the client will accept.
        public var maxStale: Int?

        /// Indicates the client wants a response that will still be fresh for at least the specified number of seconds.
        public var minFresh: Int?

        /// Indicates the client will accept a stale response, while asynchronously checking in the background for a fresh one. The value indicates how long the client will accept a stale response.
        public var staleWhileRevalidate: Int?

        /// Indicates the client will accept a stale response if the check for a fresh one fails. The value indicates how many *seconds* long the client will accept the stale response after the initial expiration.
        public var staleIfError: Int?

        /// Initializes the class
        /// - Parameter rawValue: The initial value.
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        private static let exactMatch: [String: Self] = [
            "must-revalidate": Self.mustRevalidate,
            "no-cache": Self.noCache,
            "no-store": Self.noStore,
            "no-transform": Self.noTransform,
            "public": Self.isPublic,
            "private": Self.isPrivate,
            "proxy-revalidate": Self.proxyRevalidate,
            "only-if-cached": Self.onlyIfCached,
            "max-stale": Self.maxStale
        ]

        private static let prefix: [String: WritableKeyPath<Self, Int?>] = [
            "max-age": \.maxAge,
            "s-maxage": \.sMaxAge,
            "max-stale": \.maxStale,
            "min-fresh": \.minFresh,
            "stale-while-revalidate": \.staleWhileRevalidate,
            "stale-if-error": \.staleIfError
        ]

        internal static func parse(_ value: String) -> CacheControl? {
            var set = CharacterSet.whitespacesAndNewlines
            set.insert(",")

            var foundSomething = false

            var cache = CacheControl()

            value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .split(separator: ",")
                .forEach {
                    let str = String($0)
                    
                    if let value = Self.exactMatch[str] {
                        cache.insert(value)
                        foundSomething = true
                        return
                    }

                    let parts = str.components(separatedBy: "=")
                    guard parts.count == 2, let keyPath = Self.prefix[parts[0]], let seconds = Int(parts[1]) else {
                        return
                    }

                    if keyPath == \.maxStale {
                        cache.insert(Self.maxStale)
                        foundSomething = true
                    }

                    cache[keyPath: keyPath] = seconds
                    foundSomething = true
            }

            return foundSomething ? cache : nil
        }

        /// Generates the header string for this instance.
        public func serialize() -> String {
            let options = Self.exactMatch
                .filter { contains($0.value) }
                .map { $0.key }

            let optionsWithSeconds = Self.prefix
                .filter { self[keyPath: $0.value] != nil }
                .map { "\($0.key)=\(self[keyPath: $0.value]!)" }

            return (options + optionsWithSeconds).joined(separator: ", ")
        }
    }

    /// Gets the value of the `Cache-Control` header, if present.
    public var cacheControl: CacheControl? {
        get { firstValue(name: .cacheControl).flatMap(CacheControl.parse) }
        set {
            if let new = newValue?.serialize() {
                replaceOrAdd(name: .cacheControl, value: new)
            } else {
                remove(name: .expires)
            }
        }
    }
}
