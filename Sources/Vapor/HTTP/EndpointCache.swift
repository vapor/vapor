import Foundation
import NIOConcurrencyHelpers
import NIOCore
import Logging
import HTTPTypes

public enum EndpointCacheError: Swift.Error {
    case unexpctedResponseStatus(HTTPStatus, uri: URI)
    case contentDecodeFailure(Error)
}

/// Handles the complexities of HTTP caching.
public actor EndpointCache<T>: Sendable where T: Decodable & Sendable {
    private var cached: (cachedData: T?, cacheDate: Date?)
    private var request: Task<T, Error>?
    private var headers: HTTPFields?
    private let uri: URI

    /// The designated initializer.
    /// - Parameters:
    ///   - uri: The `URI` of the resource to be downloaded.
    public init(uri: URI) {
        self.uri = uri
        self.request = nil
        self.headers = nil
        self.cached = (nil, nil)
    }

    /// Downloads the resource.
    /// - Parameters:
    ///   - request: The `Request` which is initiating the download.
    ///   - logger: An optional logger
    public func get(on request: Request, logger: Logger? = nil) async throws -> T {
        try await self.download(using: request.client, logger: logger ?? request.logger)
    }

    /// Downloads the resource.
    /// - Parameters:
    ///   - client: The `Client` which will perform the download.
    ///   - logger: An optional logger
    public func get(using client: Client, logger: Logger? = nil) async throws -> T {
        if let cached = self.cached.cachedData, let cacheUntil = self.cached.cacheDate, Date() <= cacheUntil {
            // If no-cache was set on the header, you *always* have to validate with the server.
            // must-revalidate does not require checking with the server until after it expires.
            if self.headers == nil || self.headers?.cacheControl == nil || self.headers?.cacheControl?.noCache == false {
                return cached
            }
        }

        // Don't make a new request if one is already running.
        if let request {
            // The current request may be happening on a different task.
            return try await request.value
        }

        logger?.debug("Requesting data from \(self.uri)")

        let newRequest = Task {
            try await self.download(using: client, logger: logger)
        }
        self.request = newRequest
        let result = try await newRequest.value
        // Once the request finishes, clear the current request and return the data.
        self.request = nil
        return result
    }

    private func download(using client: Client, logger: Logger?) async throws -> T {
        // https://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html#sec13.3.4
        var headers: HTTPFields = [:]

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

        do {
            let response = try await client.get(self.uri, headers: headers)
            if !(response.status == .notModified || response.status == .ok) {
                throw EndpointCacheError.unexpctedResponseStatus(response.status, uri: self.uri)
            }

            if let cacheControl = response.headers.cacheControl, cacheControl.noStore == true {
                // The server *shouldn't* give an expiration with no-store, but...
                self.clearCache()
            } else {
                headers = response.headers
                self.cached.1 = headers.expirationDate(requestSentAt: requestSentAt)
            }

            switch response.status {
            case .notModified:
                logger?.debug("Cached data is still valid.")
                guard let cached = self.cached.0 else {
                    // This shouldn't actually be possible, but just in case.
                    self.clearCache()
                    return try await self.download(using: client, logger: logger)
                }

                return cached

            case .ok:
                logger?.debug("New data received")

                let data: T

                do {
                    data = try response.content.decode(T.self)
                } catch {
                    throw EndpointCacheError.contentDecodeFailure(error)
                }

                if self.cached.1 != nil {
                    self.cached.0 = data
                }

                return data

            default:
                // This shouldn't ever happen
                throw Abort(.internalServerError)
            }
        } catch {
            guard let headers = self.headers, let cached = self.cached.0 else {
                throw error
            }

            if let cacheControl = headers.cacheControl, let cacheUntil = self.cached.1 {
                if let staleIfError = cacheControl.staleIfError,
                    cacheUntil.addingTimeInterval(Double(staleIfError)) > Date() {
                    // Can use the data for staleIfError seconds past expiration when the server is non-responsive
                    return cached
                } else if cacheControl.noCache == true && cacheUntil > Date() {
                    // The spec isn't very clear here.  If no-cache is present you're supposed to validate with the
                    // server. However, if the server doesn't respond, but I'm still within the expiration time, I'm
                    // opting to say that the cache should be considered usable.
                    return cached
                }
            }

            self.clearCache()
            throw error
        }
    }

    private func clearCache() {
        self.cached = (nil, nil)
        self.headers = nil
    }
}
