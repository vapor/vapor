import Baggage

public enum EndpointCacheError: Swift.Error {
    case unexpctedResponseStatus(HTTPStatus, uri: URI)
    case contentDecodeFailure(Error)
}

/// Handles the complexities of HTTP caching.
public final class EndpointCache<T> where T: Decodable {
    private var cached: T?
    private var request: EventLoopFuture<T>?
    private var headers: HTTPHeaders?
    private var cacheUntil: Date?

    private let sync: Lock
    private let uri: URI

    /// The designated initializer.
    /// - Parameters:
    ///   - uri: The `URI` of the resource to be downloaded.
    public init(uri: URI) {
        self.uri = uri
        self.sync = .init()
    }

    /// Downloads the resource.
    /// - Parameters:
    ///   - request: The `Request` which is initiating the download.
    ///   - logger: An optional logger
    public func get(on request: Request, logger: Logger? = nil) -> EventLoopFuture<T> {
        return self.download(on: request.eventLoop, using: request.client, context: request)
    }

    /// Downloads the resource.
    /// - Parameters:
    ///   - eventLoop: The `EventLoop` to use for the download.
    ///   - client: The `Client` which will perform the download.
    ///   - context: The `LoggingContext` used for instrumentation.
    public func get(using client: Client, on eventLoop: EventLoop, context: LoggingContext) -> EventLoopFuture<T> {
        self.sync.lock()
        defer { self.sync.unlock() }

        if let cached = self.cached, let cacheUntil = self.cacheUntil, Date() < cacheUntil {
            // If no-cache was set on the header, you *always* have to validate with the server.
            // must-revalidate does not require checking with the server until after it expires.
            if self.headers == nil || self.headers?.cacheControl == nil || self.headers?.cacheControl?.noCache == false {
                return eventLoop.makeSucceededFuture(cached)
            }
        }

        // Don't make a new request if one is already running.
        if let request = self.request {
            // The current request may be happening on a different event loop.
            return request.hop(to: eventLoop)
        }

        context.logger.debug("Requesting data from \(self.uri)")

        let request = self.download(on: eventLoop, using: client, context: context)
        self.request = request

        // Once the request finishes, clear the current request and return the data.
        return request.map { data in
            // Synchronize access to shared state
            self.sync.lock()
            defer { self.sync.unlock() }
            self.request = nil

            return data
        }
    }

    private func download(on eventLoop: EventLoop, using client: Client, context: LoggingContext) -> EventLoopFuture<T> {
        // https://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html#sec13.3.4
        var headers: HTTPHeaders = [:]
        if let eTag = self.headers?.first(name: .eTag) {
            headers.add(name: .ifNoneMatch, value: eTag)
        }

        if let lastModified = self.headers?.lastModified {
            // TODO: If using HTTP/1.0 then this should be .ifUnmodifiedSince instead. Don't know
            // how to determine that right now.
            headers.add(name: .ifModifiedSince, value: lastModified.serialize())
        }

        // Cache-Control max-age is calculated against the request date.
        let requestSentAt = Date()

        return client.get(
            self.uri,
            headers: headers,
            context: context
        ).flatMapThrowing { response -> ClientResponse in
            if !(response.status == .notModified || response.status == .ok) {
                throw EndpointCacheError.unexpctedResponseStatus(response.status, uri: self.uri)
            }

            return response
        }.flatMap { response -> EventLoopFuture<T> in
            // Synchronize access to shared state.
            self.sync.lock()
            defer { self.sync.unlock() }

            if let cacheControl = response.headers.cacheControl, cacheControl.noStore == true {
                // The server *shouldn't* give an expiration with no-store, but...
                self.clearCache()
            } else {
                self.headers = response.headers
                self.cacheUntil = self.headers?.expirationDate(requestSentAt: requestSentAt)
            }

            switch response.status {
            case .notModified:
                context.logger.debug("Cached data is still valid.")

                guard let cached = self.cached else {
                    // This shouldn't actually be possible, but just in case.
                    self.clearCache()
                    return self.download(on: eventLoop, using: client, context: context)
                }

                return eventLoop.makeSucceededFuture(cached)

            case .ok:
                context.logger.debug("New data received")

                let data: T

                do {
                    data = try response.content.decode(T.self)
                } catch {
                    return eventLoop.makeFailedFuture(EndpointCacheError.contentDecodeFailure(error))
                }

                if self.cacheUntil != nil {
                    self.cached = data
                }

                return eventLoop.makeSucceededFuture(data)

            default:
                // This shouldn't ever happen due to the previous flatMapThrowing
                return eventLoop.makeFailedFuture(Abort(.internalServerError))
            }
        }.flatMapError { error -> EventLoopFuture<T> in
            // Synchronize access to shared state.
            self.sync.lock()
            defer { self.sync.unlock() }

            guard let headers = self.headers, let cached = self.cached else {
                return eventLoop.makeFailedFuture(error)
            }

            if let cacheControl = headers.cacheControl, let cacheUntil = self.cacheUntil {
                if let staleIfError = cacheControl.staleIfError,
                    cacheUntil.addingTimeInterval(Double(staleIfError)) > Date() {
                    // Can use the data for staleIfError seconds past expiration when the server is non-responsive
                    return eventLoop.makeSucceededFuture(cached)
                } else if cacheControl.noCache == true && cacheUntil > Date() {
                    // The spec isn't very clear here.  If no-cache is present you're supposed to validate with the
                    // server. However, if the server doesn't respond, but I'm still within the expiration time, I'm
                    // opting to say that the cache should be considered usable.
                    return eventLoop.makeSucceededFuture(cached)
                }
            }

            self.clearCache()

            return eventLoop.makeFailedFuture(error)
        }
    }

    private func clearCache() {
        self.cached = nil
        self.headers = nil
        self.cacheUntil = nil
    }
}
