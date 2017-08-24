import Core
import Dispatch
import Foundation
import libc

/// TCP client stream.
public final class Client: Core.Stream {
    // MARK: Stream
    public typealias Input = DispatchData
    public typealias Output = DispatchData
    public var errorStream: ErrorHandler?
    public var outputStream: OutputHandler?

    /// This client's dispatch queue. Use this
    /// for all async operations performed as a
    /// result of this client.
    public let queue: DispatchQueue

    /// The client stream's underlying socket.
    public let socket: Socket

    /// The client's dispatch IO channel
    private let io: DispatchIO

    /// Creates a new Remote Client from the ServerSocket's details
    public init(socket: Socket, queue: DispatchQueue) {
        self.socket = socket
        self.queue = queue

        io = DispatchIO(
            type: .stream,
            fileDescriptor: socket.descriptor.raw,
            queue: queue
        ) { error in
            if error == 0 {

            } else {
                // fatalError("error during cleanup: \(error)")
            }
        }

        io.setLimit(lowWater: 1)
        // io.setLimit(highWater: 64)
    }

    // MARK: Stream

    /// Handles stream input
    public func inputStream(_ input: DispatchData) {
        io.write(offset: 0, data: input, queue: queue) { done, data, error in
            if error != 0 {
                self.errorStream?("write error: \(error)")
                self.close()
            } else if done {
                // great
            } else {
                if let data = data {
                    // re write remaining
                    print("re write")
                    self.inputStream(data)
                } else {
                    self.errorStream?("no remaining data on unfinished write")
                }
            }
        }
    }

    /// Starts receiving data from the client
    public func start() {
        io.read(offset: 0, length: .untilEOF, queue: queue) { done, data, error in
            if error != 0 {
                self.errorStream?("read error: \(error)")
                self.close()
            } else {
                if done {
                    // what to do here?
                }
                if let data = data {
                    if data.count > 0 {
                        self.outputStream?(data)
                    } else {
                        self.close()
                    }
                } else {
                    self.errorStream?("no data on read?")
                }
            }
        }
    }

    /// Closes the client.
    public func close() {
        print("close")
        socket.close()
        // important! it's common for a client to drain into itself
        // we need to make sure to break that reference cycle
        outputStream = nil
    }

    /// Deallocated the pointer buffer
    deinit {
        print("deinit")
        close()
    }
}


extension Int {
    static let untilEOF = size_t.max - 1
}

extension String: Swift.Error { }
