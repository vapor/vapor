import Async
import Bits
import Foundation

public final class Base64Stream: Async.Stream {
    /// Accepts Base64 encoded byte streams
    public typealias Input = ByteBuffer

    /// Outputs  byte streams
    public typealias Output = ByteBuffer

    /// The underlying coder
    private var base64: Base64

    /// Use to implement output stream
    private let outputStream: BasicStream<ByteBuffer>

    /// The bytes that couldn't be parsed from the previous buffer
    private var remainder: Data

    /// Current output request
    private var outputRequest: OutputRequest?

    /// Current state
    private var state: Base64StreamState

    /// Remaining output requested
    private var remainingOutputRequested: UInt

    /// Creates a Base64 coder with default buffer size and encoding
    init(base64: Base64) {
        self.base64 = base64
        outputStream = .init()
        remainder = .init()
        outputRequest = nil
        state = .open
        remainingOutputRequested = 0
        self.remainder.reserveCapacity(4)
        /// handle downstream requesting data
        self.outputStream.onRequestClosure = request
        /// handle downstream canceling output requests
        self.outputStream.onCancelClosure = cancel
    }

    /// Resumes reading data.
    private func request(_ reading: UInt) {
        let isSuspended = remainingOutputRequested == 0
        remainingOutputRequested += reading
        if isSuspended {
            update()
        }
    }

    /// Cancels reading
    private func cancel() {
        outputRequest?.cancelOutput()
        remainingOutputRequested = 0
    }

    /// See InputStream.onOutput
    public func onOutput(_ outputRequest: OutputRequest) {
        self.outputRequest = outputRequest
    }

    /// See InputStream.onInput
    public func onInput(_ input: ByteBuffer) {
        do {
            try processIncludingRemainder(input: input)
            update()
        } catch {
            onError(error)
        }
    }

    /// See InputStream.onError
    public func onError(_ error: Error) {
        outputStream.onError(error)
    }

    /// See OutputStream.onOutput
    public func output<I>(to input: I) where I: Async.InputStream, ByteBuffer == I.Input {
        outputStream.output(to: input)
    }

    /// See ClosableStream.onClose
    public func onClose() {
        do {
            try complete()
            update()
            outputRequest?.cancelOutput()
            outputStream.onClose()
        } catch {
            onError(error)
        }
    }

    private func update() {
        // if we have reminaing output, request more.
        // otherwise, suspend
        if remainingOutputRequested > 0 {
            switch state {
            case .open: outputRequest?.requestOutput()
            case .closing(let buffer):
                outputStream.onInput(buffer)
                remainingOutputRequested -= 1
                state = .closed
            case .closed: break
            }
        }
    }

    /// Processed the `input`'s `ByteBuffer` by Base64-encoding it
    ///
    /// Calls the `OutputHandler` with the Base64-encoded data
    private func processIncludingRemainder(input: ByteBuffer) throws {
        // If the remainder from previous processing attempts is not empty
        if remainder.count != 0 {
            // Create a new buffer for the input + the remainder
            let newPointerLength = remainder.count &+ input.count
            let newPointer = MutableBytesPointer.allocate(capacity: newPointerLength)
            newPointer.initialize(to: 0, count: newPointerLength)

            defer {
                newPointer.deinitialize(count: newPointerLength)
                newPointer.deallocate(capacity: newPointerLength)
            }

            // Set the remainder
            remainder.withUnsafeBytes { pointer in
                newPointer.assign(from: pointer, count: remainder.count)
            }

            // Appends the input
            if input.count > 0, let inputPointer = input.baseAddress {
                newPointer.advanced(by: remainder.count).assign(from: inputPointer, count: input.count)
            }

            try process(input: ByteBuffer(start: newPointer, count: newPointerLength))
        } else {
            try process(input: input)
        }
    }

    private func process(input: ByteBuffer) throws {
        self.remainder = Data()

        // Process the bytes into the local buffer `pointer`
        let (complete, capacity, consumed) = try base64.process(input, toPointer: base64.pointer, capacity: base64.allocatedCapacity, finish: false)
        base64.currentCapacity = capacity

        // Swift doesn't recognize that Output == ByteBuffer
        // Create a buffer referencing the ouput pointer and the outputted capacity
        let writeBuffer = ByteBuffer(start: base64.pointer, count: capacity)

        // Write the output buffer to the output stream
        if writeBuffer.count > 0 {
            outputStream.onInput(writeBuffer)
            remainingOutputRequested -= 1
        }

        // If processing is complete
        if !complete {
            // Append any unprocessed data to the remainder storage
            remainder.append(
                contentsOf: ByteBuffer(
                    start: input.baseAddress?.advanced(by: consumed),
                    count: input.count &- consumed
                )
            )
        }
    }

    /// Completes the stream, flushing all remaining bytes by encoding them
    ///
    /// Any data after this will reopen the stream
    private func complete() throws {
        if remainder.count > 0 {
            let buffer: ByteBuffer = try remainder.withUnsafeBytes { (pointer: BytesPointer) in
                let buffer = ByteBuffer(start: pointer, count: remainder.count)

                /// Process the remainder
                let (_, capacity, _) = try base64.process(buffer, toPointer: base64.pointer, capacity: base64.allocatedCapacity, finish: true)

                /// Create an output buffer (having to force cast an always-success case)
                return ByteBuffer(start: base64.pointer, count: capacity)
            }
            state = .closing(buffer)
        } else {
            state = .closed
        }
    }
}

fileprivate enum Base64StreamState {
    case open
    case closing(ByteBuffer)
    case closed
}
