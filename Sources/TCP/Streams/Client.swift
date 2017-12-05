import Async
import Bits
import Async
import Dispatch
import Foundation
import libc
import Service

/// TCP client stream.
///
/// [Learn More →](https://docs.vapor.codes/3.0/sockets/tcp-client/)
public final class TCPClient: Async.Stream, ClosableStream {
    /// See InputStream.Input
    public typealias Input = ByteBuffer

    /// See OutputStream.Output
    public typealias Output = ByteBuffer

    /// This client's dispatch queue. Use this
    /// for all async operations performed as a
    /// result of this client.
    public let eventLoop: EventLoop

    /// The client stream's underlying socket.
    public private(set) var socket: TCPSocket
    
    /// Will be triggered before closing the socket, as part of the cleanup process
    public var didClose: BasicStream.OnClose = { }

    /// Bytes from the socket are read into this buffer.
    /// Views into this buffer supplied to output streams.
    let outputBuffer: MutableByteBuffer
    
    /// Data being fed into the client stream is stored here.
    var inputBuffer = [Data]()

    /// Stores read event source.
    var readSource: DispatchSourceRead?

    /// All promises waiting for this client to become readable
    var readableWaiters = [Promise<Void>]()
    
    /// Stores write event source.
    var writeSource: DispatchSourceWrite?
    
    /// All promises waiting for this client to become writeable
    var writableWaiters = [Promise<Void>]()

    /// Keeps track of the writesource's active status so it's not resumed too often
    var isWriting = false

    /// Use a basic stream to easily implement our output stream.
    private var outputStream: BasicStream<Output> = .init()

    /// Creates a new Remote Client from the a socket
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/sockets/tcp-client/#creating-and-connecting-a-socket)
    public init(socket: TCPSocket, on eventLoop: EventLoop) {
        self.socket = socket
        self.eventLoop = eventLoop

        // Allocate one TCP packet
        let size = 65_507
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        self.outputBuffer = MutableByteBuffer(start: pointer, count: size)
    }
    
    public convenience init(on eventLoop: EventLoop) throws {
        let socket = try TCPSocket()
        socket.disablePipeSignal()
        self.init(socket: socket, on: eventLoop)
    }

    /// See InputStream.onInput
    public func onInput(_ input: ByteBuffer) {
        do {
            let count = try socket.write(from: input)
            
            guard count == input.count else {
                let data = Data(input[input.count...])
                
                inputBuffer.append(data)
                ensureWriteSourceResumed()
                return
            }
        } catch {
            inputBuffer.append(Data(input))
            ensureWriteSourceResumed()
        }
    }

    /// See InputStream.onError
    public func onError(_ error: Error) {
        /// pass the error on to our output stream
        outputStream.onError(error)
    }

    /// See OutputStream.onOutput
    public func onOutput<I>(_ input: I) where I: Async.InputStream, TCPClient.Output == I.Input {
        outputStream.onOutput(input)
    }

    /// See ClosableStream.onClose
    public func onClose(_ onClose: ClosableStream) {
        outputStream.onClose(onClose)
    }
    
    /// Handles DispatchData input
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/sockets/tcp-client/#communicating)
    public func onInput(_ input: DispatchData) {
        inputBuffer.append(Data(input))
        ensureWriteSourceResumed()
    }
    
    /// Handles Data input
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/sockets/tcp-client/#communicating)
    public func onInput(_ input: Data) {
        inputBuffer.append(input)
        ensureWriteSourceResumed()
    }
    
    private func ensureWriteSourceResumed() {
        if !isWriting {
            ensureWriteSource().resume()
            isWriting = true
        }
    }
    
    /// Creates a new WriteSource is there is no write source yet
    private func ensureWriteSource() -> DispatchSourceWrite {
        guard let source = writeSource else {
            let source = DispatchSource.makeWriteSource(
                fileDescriptor: socket.descriptor,
                queue: eventLoop.queue
            )
            
            source.setEventHandler {
                for waiter in self.writableWaiters {
                    waiter.complete()
                }
                
                self.writableWaiters = []
                
                // grab input buffer
                guard self.inputBuffer.count > 0 else {
                    self.writeSource?.suspend()
                    return
                }
                
                let data = self.inputBuffer.removeFirst()
                
                if self.inputBuffer.count == 0 {
                    // important: make sure to suspend or else writeable
                    // will keep calling.
                    self.writeSource?.suspend()
                    
                    self.isWriting = false
                }
                
                data.withUnsafeBytes { (pointer: BytesPointer) in
                    let buffer = ByteBuffer(start: pointer, count: data.count)
                    
                    do {
                        let length = try self.socket.write(from: buffer)
                        
                        if length < buffer.count {
                            self.inputBuffer.insert(Data(buffer[length...]), at: 0)
                        }
                    } catch {
                        // any errors that occur here cannot be thrown,
                        // so send them to stream error catcher.
                        self.onError(error)
                    }
                }
            }
            
            source.setCancelHandler {
                self.close()
            }
            
            writeSource = source
            return source
        }
        
        return source
    }

    /// Starts receiving data from the client
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/sockets/tcp-client/#communicating)
    public func start() {
        let source = DispatchSource.makeReadSource(
            fileDescriptor: socket.descriptor,
            queue: eventLoop.queue
        )

        source.setEventHandler {
            let read: Int
            do {
                read = try self.socket.read(
                    max: self.outputBuffer.count,
                    into: self.outputBuffer.baseAddress!
                )
            } catch {
                // any errors that occur here cannot be thrown,
                //selfso send them to stream error catcher.
                self.outputStream.onError(error)
                return
            }

            guard read > 0 else {
                // need to close!!! gah
                source.cancel()
                return
            }

            // create a view into our internal buffer and
            // send to the output stream
            let bufferView = ByteBuffer(
                start: self.outputBuffer.baseAddress,
                count: read
            )
            self.outputStream.onInput(bufferView)
        }

        source.setCancelHandler {
            self.close()
        }

        source.resume()
        readSource = source
    }

    /// Closes the client.
    public func close() {
        // important!!!!!!
        // for some reason you can't cancel a suspended write source
        // if you remove this line, your life will be ruined forever!!!
        if self.inputBuffer.count == 0 {
            writeSource?.resume()
        }
        
        for waiter in readableWaiters + writableWaiters {
            waiter.fail(TCPError(identifier: "socket-closed", reason: "The socket closed before triggering the required notification"))
        }
        
        readSource = nil
        
        // TODO: This crashes on Linux
        // writeSource = nil
        
        socket.close()
        // important! it's common for a client to drain into itself
        // we need to make sure to break that reference cycle
        // FIXME: more performant way to do this?
        // possible make the reference weak?
        outputStream.close()
        outputStream = .init()
        didClose()
    }
    
    /// Attempts to connect to a server on the provided hostname and port
    public func connect(hostname: String, port: UInt16) throws -> Future<Void> {
        try self.socket.connect(hostname: hostname, port: port)
        return writable()
    }
    
    /// Gets called when the connection becomes readable.
    ///
    /// This operation *must* once at a time.
    public func readable() -> Future<Void> {
        let promise = Promise<Void>()
        
        self.readableWaiters.append(promise)
        
        return promise.future
    }
    
    /// Gets called when the connection becomes writable.
    ///
    /// This operation *must* once at a time.
    public func writable() -> Future<Void> {
        let promise = Promise<Void>()
        
        self.writableWaiters.append(promise)
        ensureWriteSourceResumed()
        
        return promise.future
    }

    /// Deallocated the pointer buffer
    deinit {
        close()
        outputBuffer.baseAddress.unsafelyUnwrapped.deallocate(capacity: outputBuffer.count)
        outputBuffer.baseAddress.unsafelyUnwrapped.deinitialize()
    }
}
