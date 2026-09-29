#if Compression
import HTTPTypes
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension Application {
    /// Creates response compression middleware using the current ``serverConfiguration`` settings.
    ///
    /// Configure the settings before creating the middleware, then register it explicitly:
    ///
    ///     app.middleware.use(app.makeResponseCompressionMiddleware(), at: .beginning)
    ///
    /// Placing it before error middleware allows it to compress error responses as well.
    public func makeResponseCompressionMiddleware() -> ResponseCompressionMiddleware {
        ResponseCompressionMiddleware(configuration: self.serverConfiguration.responseCompression)
    }
}

/// Compresses response bodies using gzip or deflate when accepted by the client.
///
/// Register this middleware to enable compression. The default policy compresses known compressible
/// content types. Place it before error middleware to compress error responses.
/// Use ``Application/makeResponseCompressionMiddleware()`` to apply the application's server settings.
/// Response compression is only enabled for routes whose middleware chain contains this middleware.
/// To leave some routes uncompressed, register this middleware on a route group instead of the application.
public struct ResponseCompressionMiddleware: Middleware {
    private let configuration: ServerConfiguration.ResponseCompressionConfiguration

    /// Creates middleware with a copy of the supplied compression settings.
    /// - Parameter configuration: Response compression settings. Defaults to known compressible types.
    public init(configuration: ServerConfiguration.ResponseCompressionConfiguration = .init()) {
        self.configuration = configuration
    }

    public func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        var response = try await next.respond(to: request)
        let policy = self.configuration
        guard policy.mediaTypes.contains(response.headers.contentType), response.headers[.contentEncoding] == nil,
            response.status.kind != .informational,
            response.status != .noContent, response.status != .notModified,
            response.status != .partialContent, response.headers[.contentRange] == nil,
            response.body.count != 0
        else { return response }

        // Cache entries for both the encoded and identity variants depend on Accept-Encoding.
        let vary =
            response.headers[.vary]?.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces).lowercased()
            } ?? []
        if !vary.contains("*") && !vary.contains("accept-encoding") {
            response.headers.append(.init(name: .vary, value: "Accept-Encoding"))
        }
        guard let coding = Self.negotiate(request.headers[.acceptEncoding]) else { return response }
        // HEAD must not execute a streaming body merely to calculate compressed metadata.
        guard request.method != .head else { return response }

        let original = response.body
        let capacity = policy.initialByteBufferCapacity
        response.headers[.contentEncoding] = coding.rawValue
        // A strong validator for the identity bytes cannot be a strong validator for encoded bytes.
        if let etag = response.headers[.eTag], !etag.hasPrefix("W/") {
            response.headers[.eTag] = "W/" + etag
        }
        if case .stream(let stream) = original.storage, stream.state.collected == nil {
            response.body = .init(stream: { writer in
                let codec = try HTTPBodyCodec(coding: coding, compressing: true, capacity: capacity)
                let compressor = CompressingBodyWriter(codec: codec, downstream: writer)
                try stream.state.beginConsuming()
                try await stream.callback(compressor)
                if let count = stream.count, count != compressor.count.value {
                    throw ResponseBodyLengthMismatch(declared: count, written: compressor.count.value)
                }
                try await compressor.finish()
            })
        } else {
            let codec = try HTTPBodyCodec(coding: coding, compressing: true, capacity: capacity)
            var compressed = Data()
            try await original.withStreamingBytes { bytes in
                var offset = 0
                repeat {
                    let result = try codec.process(bytes.extracting(offset...), finish: true)
                    offset += result.consumed
                    compressed.append(result.output)
                } while !codec.complete
            }
            response.body = .init(data: compressed)
        }
        return response
    }

    /// Explicit exclusions override wildcard preferences; gzip wins equal weights.
    static func negotiate(_ header: String?) -> HTTPBodyCodec.Coding? {
        guard let header else { return nil }
        var weights: [String: Double] = [:]
        for item in header.split(separator: ",") {
            let parts = item.split(separator: ";", omittingEmptySubsequences: false)
            let name = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
            var weight = 1.0
            for parameter in parts.dropFirst() {
                let pair = parameter.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                if pair[0].trimmingCharacters(in: .whitespaces).lowercased() == "q" {
                    weight = pair.count == 2 ? Double(pair[1].trimmingCharacters(in: .whitespaces)) ?? 0 : 0
                }
            }
            weights[name] = weight.isFinite && (0...1).contains(weight) ? weight : 0
        }
        let gzip = weights["gzip"] ?? weights["*"] ?? 0
        let deflate = weights["deflate"] ?? weights["*"] ?? 0
        let best = max(gzip, deflate)
        guard best > 0, best >= (weights["identity"] ?? 0) else { return nil }
        return gzip >= deflate ? .gzip : .deflate
    }
}

/// A borrowed writer wrapping the transport writer; never captures it in an escaping closure.
private struct CompressingBodyWriter: HTTPBodyWriter, ~Escapable {
    final class Count { var value = 0 }
    let codec: HTTPBodyCodec
    let downstream: any HTTPBodyWriter & ~Escapable
    let count = Count()

    @_lifetime(copy downstream)
    init(codec: HTTPBodyCodec, downstream: borrowing any HTTPBodyWriter & ~Escapable) {
        self.codec = codec
        self.downstream = copy downstream
    }

    func write(_ bytes: Span<UInt8>) async throws {
        self.count.value += bytes.count
        var offset = 0
        var full: Bool
        repeat {
            let result = try self.codec.process(bytes.extracting(offset...))
            offset += result.consumed
            full = result.output.count == self.codec.capacity
            if !result.output.isEmpty { try await self.downstream.write(result.output.span) }
        } while offset < bytes.count || full
    }

    func finish() async throws {
        while !self.codec.complete {
            let result = try self.codec.process(Span(), finish: true)
            if !result.output.isEmpty { try await self.downstream.write(result.output.span) }
        }
    }
}

#endif
