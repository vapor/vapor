#if Compression
import Algorithms
import HTTPTypes
import CompressionDeflate
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

        guard
            self.configuration.mediaTypes.contains(response.headers.contentType),
            response.headers[.contentEncoding] == nil,
            response.status.kind != .informational,
            response.status != .noContent, response.status != .notModified,
            response.status != .partialContent, response.headers[.contentRange] == nil,
            response.body.count != 0
        else { return response }

        // Cache entries for both the encoded and identity variants depend on Accept-Encoding.
        let vary =
            response.headers[.vary]?.split(separator: ",").map {
                $0.trimmingOWS().lowercased()
            } ?? []
        if !vary.contains("*") && !vary.contains("accept-encoding") {
            response.headers.append(.init(name: .vary, value: "Accept-Encoding"))
        }

        let coding: HTTPBodyCoding
        switch Self.negotiate(request.headers[.acceptEncoding]) {
        case .compress(let selected): coding = selected
        case .identity: return response
        case .notAcceptable:
            // This middleware can wrap ErrorMiddleware, so return the response rather than throw.
            // Do not retain representation headers (such as ETag) from the rejected response.
            return Response(status: .notAcceptable, headers: [.vary: response.headers[.vary] ?? "Accept-Encoding"])
        }
        let compressionConfiguration: Deflate.CompressionConfiguration = coding == .gzip ? .gzip() : .default

        // HEAD must not execute a streaming body merely to calculate compressed metadata.
        guard request.method != .head else { return response }

        response.headers[.contentEncoding] = coding.rawValue
        // A strong validator for the identity bytes cannot be a strong validator for encoded bytes.
        if let etag = response.headers[.eTag], !etag.hasPrefix("W/") {
            response.headers[.eTag] = "W/" + etag
        }

        let original = response.body
        let capacity = max(64, min(self.configuration.initialByteBufferCapacity, 65_536))

        if case .stream(let stream) = original.storage, stream.state.collected == nil {
            response.body = .init(stream: { writer in
                let compressor = CompressingBodyWriter(
                    compressionConfiguration: compressionConfiguration, bufferCapacity: capacity, downstream: writer
                )
                try stream.state.beginConsuming()
                try await stream.callback(compressor)

                if let count = stream.count, count != compressor.bytesWritten {
                    throw ResponseBodyLengthMismatch(declared: count, written: compressor.bytesWritten)
                }

                try await compressor.finish()
            })
        } else {
            let compressor = Deflate.Compressor(configuration: compressionConfiguration)
            var compressed: [UInt8]!
            try await original.withStreamingBytes { bytes in
                compressed = try [UInt8](capacity: compressor.upperBound(forInputSize: bytes.count)) { outputSpan in
                    try compressor.compress(bytes, into: &outputSpan)
                }
            }

            response.body = .init(data: Data(compressed))
        }

        return response
    }

    enum NegotiationResult: Sendable, Equatable {
        case compress(HTTPBodyCoding)
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
            let name = parts[0].trimmingOWS().lowercased()

            guard ["gzip", "deflate", "identity", "*"].contains(name) else { continue }

            let weight =
                if parts.count == 1 {
                    1000
                } else {
                    Self.qualityValue(parts[1].trimmingOWS()) ?? 0
                }

            weights[name] = min(weights[name] ?? weight, weight)
        }

        let gzip = weights["gzip"] ?? weights["*"] ?? 0
        let deflate = weights["deflate"] ?? weights["*"] ?? 0
        let best = max(gzip, deflate)
        if best > 0, best >= (weights["identity"] ?? 0) {
            return .compress(gzip >= deflate ? .gzip : .deflate)
        }

        let acceptsIdentity = (weights["identity"] ?? weights["*"] ?? 1) > 0
        return acceptsIdentity ? .identity : .notAcceptable
    }

    /// Parses a `q=` parameter per RFC 9110 section 12.4.2: an ASCII 0 or 1, optionally followed by
    /// a decimal point and at most three digits. Values beginning with 1 may only have zero fractional digits.
    /// Integer thousandths avoid accepting floating-point extensions such as signs or exponents.
    private static func qualityValue(_ parameter: Substring) -> Int? {
        guard parameter.prefix(2).lowercased() == "q=" else { return nil }
        let bytes = parameter.dropFirst(2).utf8
        let zero = UInt8(ascii: "0")
        let one = UInt8(ascii: "1")

        guard
            (1...5).contains(bytes.count),
            let first = bytes.first,
            first == zero || first == one
        else {
            return nil
        }
        var quality = first == one ? 1000 : 0
        guard bytes.count > 1 else { return quality }

        guard bytes.dropFirst().first == UInt8(ascii: ".") else { return nil }
        var place = 100
        for digit in bytes.dropFirst(2) {
            guard (zero...UInt8(ascii: "9")).contains(digit), first == zero || digit == zero else { return nil }
            quality += Int(digit - zero) * place
            place /= 10
        }

        return quality
    }
}

/// A borrowed writer wrapping the transport writer; never captures it in an escaping closure.
private struct CompressingBodyWriter: HTTPBodyWriter, ~Escapable {
    // `write` is non-mutating and the compressor is ~Copyable, so mutable state lives in a class.
    final class CompressorBox {
        var bytesWritten = 0
        var compressor: Deflate.StreamingCompressor

        init(compressor: consuming Deflate.StreamingCompressor) {
            self.compressor = compressor
        }
    }

    let downstream: any HTTPBodyWriter & ~Escapable
    let box: CompressorBox
    let bufferCapacity: Int

    /// Uncompressed bytes received from the body, for checking against its declared length.
    var bytesWritten: Int {
        self.box.bytesWritten
    }

    @_lifetime(copy downstream)
    init(
        compressionConfiguration: Deflate.CompressionConfiguration,
        bufferCapacity: Int,
        downstream: borrowing any HTTPBodyWriter & ~Escapable
    ) {
        self.downstream = copy downstream
        self.box = .init(compressor: .init(configuration: compressionConfiguration))
        self.bufferCapacity = bufferCapacity
    }

    func write(_ bytes: Span<UInt8>) async throws {
        var consumed = 0
        var flushed = false
        while !flushed {
            let output = try [UInt8](capacity: bufferCapacity) { outputSpan in
                if consumed < bytes.count {
                    consumed += try box.compressor.compress(bytes.extracting(consumed...), into: &outputSpan).consumed
                }
                if consumed == bytes.count {
                    flushed = try box.compressor.flush(into: &outputSpan) == .awaitingInput
                }
            }
            if !output.isEmpty {
                try await self.downstream.write(output.span)
            }

        }

        self.box.bytesWritten += consumed
    }

    func finish() async throws {
        var isFinished = false
        while !isFinished {
            let output = try [UInt8](capacity: bufferCapacity) { outputSpan in
                isFinished = try box.compressor.finish(into: &outputSpan) == .finished
            }
            if !output.isEmpty {
                try await self.downstream.write(output.span)
            }
        }
    }
}

extension StringProtocol {
    fileprivate func trimmingOWS() -> Self.SubSequence {
        self.trimming(while: { $0 == " " || $0 == "\t" })
    }
}

#endif
