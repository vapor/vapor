#if Compression
import Algorithms
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
/// For eligible responses, if the client excludes both supported encodings and the uncompressed
/// representation, the middleware returns an empty `406 Not Acceptable` response.
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
                $0.trimming(while: { $0 == " " || $0 == "\t" }).lowercased()
            } ?? []
        if !vary.contains("*") && !vary.contains("accept-encoding") {
            response.headers.append(.init(name: .vary, value: "Accept-Encoding"))
        }
        let coding: HTTPBodyCodec.Coding
        switch Self.negotiate(request.headers[.acceptEncoding]) {
        case .compress(let selected): coding = selected
        case .identity: return response
        case .notAcceptable:
            // This middleware can wrap ErrorMiddleware, so return the response rather than throw.
            // Do not retain representation headers (such as ETag) from the rejected response.
            return Response(status: .notAcceptable, headers: [.vary: response.headers[.vary] ?? "Accept-Encoding"])
        }
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

    enum NegotiationResult: Equatable, Sendable {
        case compress(HTTPBodyCodec.Coding)
        case identity
        case notAcceptable
    }

    /// Explicit exclusions override wildcard preferences; gzip wins equal weights.
    /// Invalid weights reject that coding. Conflicting duplicates use the lowest weight so that
    /// an explicit exclusion cannot be undone by another entry or field line.
    static func negotiate(_ header: String?) -> NegotiationResult {
        guard let header else { return .identity }
        // Only retain the four entries that affect selection, regardless of the number of unknown codings.
        var weights: [String: Int] = [:]
        for item in header.split(separator: ",") {
            let parts = item.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
            let name = parts[0].trimming(while: { $0 == " " || $0 == "\t" }).lowercased()
            guard name == "gzip" || name == "deflate" || name == "identity" || name == "*" else { continue }
            let weight: Int
            if parts.count == 1 {
                weight = 1000
            } else {
                let parameter = parts[1].trimming(while: { $0 == " " || $0 == "\t" })
                weight = parameter.prefix(2).lowercased() == "q=" ? Self.qualityValue(parameter.dropFirst(2)) ?? 0 : 0
            }
            weights[name] = min(weights[name] ?? weight, weight)
        }
        let gzip = weights["gzip"] ?? weights["*"] ?? 0
        let deflate = weights["deflate"] ?? weights["*"] ?? 0
        let best = max(gzip, deflate)
        if best > 0, best >= (weights["identity"] ?? 0) {
            return .compress(gzip >= deflate ? .gzip : .deflate)
        }
        let acceptsIdentity = weights["identity"].map { $0 > 0 } ?? (weights["*"] != 0)
        return acceptsIdentity ? .identity : .notAcceptable
    }

    /// RFC 9110 section 12.4.2: an ASCII 0 or 1, optionally followed by a decimal point and
    /// at most three digits. Values beginning with 1 may only have zero fractional digits.
    /// Integer thousandths avoid accepting floating-point extensions such as signs or exponents.
    private static func qualityValue(_ value: Substring) -> Int? {
        let bytes = value.utf8
        guard (1...5).contains(bytes.count), let first = bytes.first, first == 48 || first == 49 else { return nil }
        if bytes.count == 1 { return first == 49 ? 1000 : 0 }
        guard bytes.dropFirst().first == 46 else { return nil }
        var quality = first == 49 ? 1000 : 0
        var place = 100
        for digit in bytes.dropFirst(2) {
            guard (48...57).contains(digit), first == 48 || digit == 48 else { return nil }
            quality += Int(digit - 48) * place
            place /= 10
        }
        return quality
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
