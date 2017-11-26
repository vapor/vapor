import Async
import Bits
import Async
import Dispatch
import Foundation
import libc

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
    public let worker: Worker

    /// The client stream's underlying socket.
    public let socket: TCPSocket

    /// Bytes from the socket are read into this buffer.
    /// Views into this buffer supplied to output streams.
    let outputBuffer: MutableByteBuffer

    /// Data being fed into the client stream is stored here.
    var inputBuffer = [Data]()

    /// Stores read event source.
    var readSource: DispatchSourceRead?

    /// Stores write event source.
    var writeSource: DispatchSourceWrite?

    /// Keeps track of the writesource's active status so it's not resumed too often
    var isWriting = false

    /// Use a basic stream to easily implement our output stream.
    private var outputStream: BasicStream<Output> = .init()

    /// Creates a new Remote Client from the a socket
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/sockets/tcp-client/#creating-and-connecting-a-socket)
    public init(socket: TCPSocket, worker: Worker) {
        self.socket = socket
        self.worker = worker

        // Allocate one TCP packet
        let size = 65_507
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        self.outputBuffer = MutableByteBuffer(start: pointer, count: size)
    }

    /// See InputStream.onInput
    public func onInput(_ input: ByteBuffer) {
        inputBuffer.append(Data(input))
        ensureWriteSourceResumed()
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
    public func inputStream(_ input: DispatchData) {
        inputBuffer.append(Data(input))
        ensureWriteSourceResumed()
    }
    
    /// Handles Data input
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/sockets/tcp-client/#communicating)
    public func inputStream(_ input: Data) {
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
                queue: worker.eventLoop.queue
            )
            
            source.setEventHandler {
                // grab input buffer
                guard self.inputBuffer.count > 0 else {
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
                        _ = try self.socket.write(max: data.count, from: buffer)
                        // FIXME: we should verify the lengths match here.
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
            queue: worker.eventLoop.queue
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
                self.close()
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
        
        readSource = nil
        writeSource = nil
        socket.close()
        // important! it's common for a client to drain into itself
        // we need to make sure to break that reference cycle
        // FIXME: more performant way to do this?
        // possible make the reference weak?
        outputStream.close()
        outputStream = .init()
    }

    /// Deallocated the pointer buffer
    deinit {
        close()
        outputBuffer.baseAddress.unsafelyUnwrapped.deallocate(capacity: outputBuffer.count)
        outputBuffer.baseAddress.unsafelyUnwrapped.deinitialize()
    }
}
