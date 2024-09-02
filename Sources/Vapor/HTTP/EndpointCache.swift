import Foundation
import NIOConcurrencyHelpers
import NIOCore
import Logging
import NIOHTTP1

public enum EndpointCacheError: Swift.Error {
    case unexpctedResponseStatus(HTTPStatus, uri: URI)
    case contentDecodeFailure(Error)
}

/// Handles the complexities of HTTP caching.
public final class EndpointCache<T>: Sendable where T: Decodable & Sendable {
    private let cached: NIOLockedValueBox<(T?, Date?)>
    private let request: NIOLockedValueBox<T?>
    private let headers: NIOLockedValueBox<HTTPHeaders?>
    private let sync: NIOLock
    private let uri: URI
    
    /// The designated initializer.
    /// - Parameters:
    ///   - uri: The `URI` of the resource to be downloaded.
    public init(uri: URI) {
        self.uri = uri
        self.sync = .init()
        self.request = .init(nil)
        self.headers = .init(nil)
        self.cached = .init((nil, nil))
    }
    
    /// Downloads the resource.
    /// - Parameters:
    ///   - request: The `Request` which is initiating the download.
    ///   - logger: An optional logger
    public func get(on request: Request, logger: Logger? = nil) async throws -> T {
        return try await self.download(on: request.eventLoop, using: request.client, logger: logger ?? request.logger)
    }
    
    /// Downloads the resource.
    /// - Parameters:
    ///   - eventLoop: The `EventLoop` to use for the download.
    ///   - client: The `Client` which will perform the download.
    ///   - logger: An optional logger
    public func get(using client: Client, logger: Logger? = nil, on eventLoop: EventLoop) async throws -> T {
#warning("This all needs rewriting, probably actor?")
        self.sync.lock()
        defer { self.sync.unlock() }
        
        let cachedData = self.cached.withLockedValue { $0 }
        if let cached = cachedData.0, let cacheUntil = cachedData.1, Date() < cacheUntil {
            // If no-cache was set on the header, you *always* have to validate with the server.
            // must-revalidate does not require checking with the server until after it expires.
            let cachedHeaders = self.headers.withLockedValue { $0 }
            if cachedHeaders == nil || cachedHeaders?.cacheControl == nil || cachedHeaders?.cacheControl?.noCache == false {
                return cached
            }
        }
        
        // Don't make a new request if one is already running.
        if let request = self.request.withLockedValue({ $0 }) {
            return request
        }
        
        logger?.debug("Requesting data from \(self.uri)")
        
        let request = try await self.download(on: eventLoop, using: client, logger: logger)
        self.request.withLockedValue { $0 = request }
        
        // Once the request finishes, clear the current request and return the data.
        // Synchronize access to shared state
        self.sync.lock()
        defer { self.sync.unlock() }
        self.request.withLockedValue { $0 = nil }
        
        return request
    }
    
    private func download(on eventLoop: EventLoop, using client: Client, logger: Logger?) async throws -> T {
        // https://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html#sec13.3.4
        var headers: HTTPHeaders = [:]
        self.headers.withLockedValue { cachedHeaders in
            if let eTag = cachedHeaders?.first(name: .eTag) {
                headers.add(name: .ifNoneMatch, value: eTag)
            }
            
            if let lastModified = cachedHeaders?.lastModified {
                // TODO: If using HTTP/1.0 then this should be .ifUnmodifiedSince instead. Don't know
                // how to determine that right now.
                headers.add(name: .ifModifiedSince, value: lastModified.serialize())
            }
        }
        
        // Cache-Control max-age is calculated against the request date.
        let requestSentAt = Date()
        
        let response = try await client.get(self.uri, headers: headers)
        if !(response.status == .notModified || response.status == .ok) {
            throw EndpointCacheError.unexpctedResponseStatus(response.status, uri: self.uri)
        }
        
        do {
            // Synchronize access to shared state.
            self.sync.lock()
            defer { self.sync.unlock() }
            
            if let cacheControl = response.headers.cacheControl, cacheControl.noStore == true {
                // The server *shouldn't* give an expiration with no-store, but...
                self.clearCache()
            } else {
                self.headers.withLockedValue { headers in
                    headers = response.headers
                    self.cached.withLockedValue { $0.1 = headers?.expirationDate(requestSentAt: requestSentAt) }
                }
            }
            
            switch response.status {
            case .notModified:
                logger?.debug("Cached data is still valid.")
                
                let cachedData = self.cached.withLockedValue({ $0 })
                guard let cached = cachedData.0 else {
                    // This shouldn't actually be possible, but just in case.
                    self.clearCache()
                    return try await self.download(on: eventLoop, using: client, logger: logger)
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
                
                self.cached.withLockedValue { cachedData in
                    if cachedData.1 != nil {
                        cachedData.0 = data
                    }
                }
                
                return data
                
            default:
                // This shouldn't ever happen due to the previous flatMapThrowing
                throw Abort(.internalServerError)
            }
        } catch {
            // Synchronize access to shared state.
            self.sync.lock()
            defer { self.sync.unlock() }
            
            let cachedData = self.cached.withLockedValue { $0 }
            guard let headers = self.headers.withLockedValue({ $0 }), let cached = cachedData.0 else {
                throw error
            }
            
            if let cacheControl = headers.cacheControl, let cacheUntil = cachedData.1 {
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
        self.cached.withLockedValue { $0 = (nil, nil) }
        self.headers.withLockedValue { $0 = nil }
    }
}
