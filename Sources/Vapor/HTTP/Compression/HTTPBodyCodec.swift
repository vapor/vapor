#if Compression
import CVaporZlib
import HTTPTypes
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A task-confined codec. zlib retains the stream's address, so it must have stable storage.
/// Input and output pointers are borrowed only for a synchronous call and cleared before returning.
@safe final class HTTPBodyCodec {
    enum Coding: String, Sendable { case gzip, deflate }
    private let stream: UnsafeMutablePointer<z_stream>
    private let compressing: Bool
    private var initialized = false
    private(set) var complete = false
    let capacity: Int

    init(coding: Coding, compressing: Bool, capacity: Int = 16_384) throws {
        self.compressing = compressing
        self.capacity = max(64, min(capacity, 65_536))
        unsafe self.stream = .allocate(capacity: 1)
        unsafe self.stream.initialize(to: z_stream())
        let windowBits: Int32 = coding == .gzip ? 31 : 15
        let result =
            if compressing {
                unsafe deflateInit2_(
                    self.stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, windowBits, 8,
                    Z_DEFAULT_STRATEGY, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
            } else {
                unsafe inflateInit2_(self.stream, windowBits, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
            }
        guard result == Z_OK else {
            throw Abort(.internalServerError, reason: "Could not initialize HTTP body codec (\(result))")
        }
        self.initialized = true
    }

    deinit {
        if self.initialized {
            if self.compressing { _ = unsafe deflateEnd(self.stream) } else { _ = unsafe inflateEnd(self.stream) }
        }
        unsafe self.stream.deinitialize(count: 1)
        unsafe self.stream.deallocate()
    }

    /// Performs bounded work, producing at most `capacity` bytes. The caller drives backpressure.
    func process(_ input: Span<UInt8>, finish: Bool = false) throws -> (consumed: Int, output: Data) {
        guard !self.complete else {
            if !input.isEmpty { throw Abort(.badRequest, reason: "Trailing data in compressed request body") }
            return (0, Data())
        }
        var output = Data(count: self.capacity)
        let offered = min(input.count, Int(UInt32.max))
        let result = input.withUnsafeBufferPointer { source in
            unsafe output.withUnsafeMutableBytes { destination in
                unsafe self.stream.pointee.next_in = UnsafeMutablePointer(mutating: source.baseAddress)
                unsafe self.stream.pointee.avail_in = UInt32(offered)
                unsafe self.stream.pointee.next_out = destination.bindMemory(to: UInt8.self).baseAddress
                unsafe self.stream.pointee.avail_out = UInt32(self.capacity)
                defer {
                    unsafe self.stream.pointee.next_in = nil
                    unsafe self.stream.pointee.next_out = nil
                }
                return self.compressing
                    ? unsafe deflate(self.stream, finish ? Z_FINISH : Z_SYNC_FLUSH)
                    : unsafe inflate(self.stream, Z_NO_FLUSH)
            }
        }
        let consumed = unsafe offered - Int(self.stream.pointee.avail_in)
        let produced = unsafe self.capacity - Int(self.stream.pointee.avail_out)
        guard result == Z_OK || result == Z_STREAM_END || result == Z_BUF_ERROR else {
            throw Abort(
                self.compressing ? .internalServerError : .badRequest,
                reason: "Invalid compressed HTTP body (\(result))")
        }
        self.complete = result == Z_STREAM_END
        output.count = produced
        return (consumed, output)
    }
}

/// Pull-based decoding: holds one compressed transport chunk and emits one bounded decoded chunk.
/// Owned by a single read at a time through RequestBodyStream's checkout/stow protocol.
final class HTTPBodyDecompressor {
    private let source: RequestBodyStream
    private let codec: HTTPBodyCodec
    private let limit: ServerConfiguration.RequestDecompressionConfiguration.DecompressionLimit
    private var input = Data()
    private var offset = 0
    private var received = 0
    private var produced = 0
    private var sourceEnded = false
    private var pendingOutput = false

    init(
        source: RequestBodyStream, coding: HTTPBodyCodec.Coding,
        limit: ServerConfiguration.RequestDecompressionConfiguration.DecompressionLimit
    ) throws {
        self.source = source
        self.codec = try HTTPBodyCodec(coding: coding, compressing: false)
        self.limit = limit
    }

    func read() async throws -> Data? {
        while true {
            if self.offset == self.input.count && !self.pendingOutput && !self.sourceEnded {
                try await self.source.read { bytes, ended in
                    self.input = bytes.withUnsafeBufferPointer { unsafe Data(buffer: $0) }
                    self.offset = 0
                    self.received += bytes.count
                    self.sourceEnded = ended
                }
            }
            if self.codec.complete {
                guard self.offset == self.input.count else {
                    throw Abort(.badRequest, reason: "Trailing data in compressed request body")
                }
                if self.sourceEnded { return nil }
                continue
            }
            let result = try self.codec.process(self.input.span.extracting(self.offset...))
            self.offset += result.consumed
            self.produced += result.output.count
            guard !self.limit.exceeded(compressed: self.received, decompressed: self.produced) else {
                throw Abort(.contentTooLarge, headers: .connectionClose, reason: "Request decompression limit exceeded")
            }
            self.pendingOutput = result.output.count == self.codec.capacity && !self.codec.complete
            if !result.output.isEmpty { return result.output }
            if self.sourceEnded && !self.codec.complete {
                throw Abort(.badRequest, reason: "Truncated compressed request body")
            }
        }
    }
}

#endif
