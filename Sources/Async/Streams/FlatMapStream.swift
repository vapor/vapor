/// A basic stream implementation that flatMaps input
/// through a closure.
///
/// Example using a data buffer emmitter and a data->string flatmapper:
///
///     let dataEmitter = EmitterStream(Data.self)
///     let squareMapStream = FlatMapStream<Data, String> { data in
///         // If initialization fails,
///         return String(bytes: data, encoding: .utf8)
///     }
///
///     var squares: [String] = []
///
///     dataEmitter.stream(to: squareMapStream).drain { square in
///         squares.append(square)
///     }
///
///     dataEmitter.emit(Data("one".utf8))
///     dataEmitter.emit(Data("two".utf8))
///     dataEmitter.emit(Data("three".utf8))
///
///     // Random invalid string data
///     dataEmitter.emit(Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10] as [UInt8))
///
///     // The invalid string didn't get serialized (resulting in `nil`), which was flatMapped out
///     print(squares) // ["one", "two", "three"]
///
public final class FlatMapStream<In, Out>: Stream {
    /// See InputStream.Input
    public typealias Input = In
    
    /// See OutputStream.Output
    public typealias Output = Out
    
    /// See OutputStream.outputStream
    public var outputStream: OutputHandler?
    
    /// See BaseStream.errorStream
    public var errorStream: ErrorHandler?
    
    /// Maps input to output
    public typealias FlatMapClosure = (In) throws -> (Out?)
    
    /// The stored map closure
    public let transform: FlatMapClosure
    
    /// Create a new Map stream with the supplied closure.
    public init(transform: @escaping FlatMapClosure) {
        self.transform = transform
    }
    
    /// See InputStream.inputStream
    public func inputStream(_ input: In) {
        do {
            if let output = try transform(input) {
                outputStream?(output)
            }
        } catch {
            errorStream?(error)
        }
    }
}

extension OutputStream {
    public func flatMap<T>(_ transform: @escaping ((Output) throws -> (T?))) -> FlatMapStream<Output, T> {
        let stream = FlatMapStream(transform: transform)
        self.drain(into: stream)
        return stream
    }
}
