#if Compression
import CompressionDeflate
import HTTPTypes
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

enum HTTPBodyCoding: String, Sendable { 
    case gzip
    case deflate 
}

/// Pull-based decoding: holds one compressed transport chunk and emits one bounded decoded chunk.
/// Owned by a single read at a time through RequestBodyStream's checkout/stow protocol.
final class HTTPBodyDecompressor {
    private let source: RequestBodyStream
    private var decompressor: Deflate.StreamingDecompressor
    private let limit: ServerConfiguration.RequestDecompressionConfiguration.DecompressionLimit
    private var input = Data()
    private var offset = 0
    private var received = 0
    private var produced = 0
    private var sourceEnded = false
    private var pendingOutput = false

    init(
        source: RequestBodyStream,
        httpBodyCoding: HTTPBodyCoding,
        limit: ServerConfiguration.RequestDecompressionConfiguration.DecompressionLimit
    ) throws {
        self.source = source
        var configuration = Deflate.DecompressionConfiguration()
        configuration.trailingDataPolicy = .reject
        switch httpBodyCoding {
        case .deflate: configuration.format = .zlib
        case .gzip: configuration.format = .gzip
        }
        self.decompressor = .init(configuration: configuration)
        self.limit = limit
    }

    func read() async throws -> [UInt8]? {
        while true {
            if self.decompressor.isFinished && self.offset == self.input.count {
                if self.sourceEnded { return nil }
            }

            if self.offset == self.input.count && !self.pendingOutput && !self.sourceEnded {
                try await self.source.read { bytes, ended in
                    self.input = bytes.withUnsafeBufferPointer { unsafe Data(buffer: $0) }
                    self.offset = 0
                    self.received += bytes.count
                    self.sourceEnded = ended
                }
            }

            let result: [UInt8]
            do {
                result = try [UInt8](capacity: 64 * 1024) { output throws(Deflate.Error) in
                    self.offset += try self.decompressor.decompress(
                        self.input.span.extracting(self.offset...), 
                        into: &output
                    )
                }
            } catch .unexpectedTrailingData {
                throw Abort(.badRequest, reason: "Trailing data in compressed request body")
            } catch .truncatedInput {
                throw Abort(.badRequest, reason: "Truncated compressed request body")
            } catch .corruptData {
                throw Abort(.badRequest, reason: "Could not decompress undecompressible HTTP body")
            } catch {
                throw Abort(.badRequest, reason: "Could not decompress HTTP body: \(error)")
            }
            self.produced += result.count

            guard !self.limit.exceeded(compressed: self.received, decompressed: self.produced) else {
                throw Abort(.contentTooLarge, headers: .connectionClose, reason: "Request decompression limit exceeded")
            }

            if !result.isEmpty { return result }

            if self.sourceEnded && self.offset == self.input.count && !self.pendingOutput && !self.decompressor.isFinished {
                throw Abort(.badRequest, reason: "Truncated compressed request body")
            }
        }
    }
}

#endif
