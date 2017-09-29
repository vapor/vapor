/// A basic stream implementation that maps input
/// through a closure.
///
/// Example using a number emitter and map stream to square numbers:
///
///     let numberEmitter = EmitterStream(Int.self)
///     let squareMapStream = MapStream<Int, Int> { int in
///         return int * int
///     }
///
///     var squares: [Int] = []
///
///     numberEmitter.stream(to: squareMapStream).drain { square in
///         squares.append(square)
///     }
///
///     numberEmitter.emit(1)
///     numberEmitter.emit(2)
///     numberEmitter.emit(3)
///
///     print(squares) // [1, 4, 9]
///
public final class MapStream<In, Out>: Stream {
    /// See `BaseStream.onClose`
    public var onClose: CloseHandler?
    
    /// See `InputStream.Input`
    public typealias Input = In

    /// See `OutputStream.Output`
    public typealias Output = Out

    /// See `OutputStream.outputStream`
    public var outputStream: OutputHandler?

    /// See `BaseStream.errorStream`
    public var errorStream: ErrorHandler?

    /// Maps input to output
    public typealias MapClosure = (In) throws -> (Out)

    /// The stored map closure
    public let map: MapClosure

    /// Create a new Map stream with the supplied closure.
    public init(map: @escaping MapClosure) {
        self.map = map
    }

    /// See InputStream.inputStream
    public func inputStream(_ input: In) {
        do {
            let output = try map(input)
            outputStream?(output)
        } catch {
            errorStream?(error)
        }
    }
}

extension OutputStream {
    /// Transforms the output of one stream (as the input of the transform) to another output
    ///
    /// An example of mapping ints to strings:
    ///
    ///     let integerStream: BasicOutputStream<Int>
    ///     let stringSteam:   MapStream<Int, String> = integerStream.map { integer in
    ///         return integer.description
    ///     }
    public func map<T>(_ transform: @escaping ((Output) throws -> (T))) -> MapStream<Output, T> {
        let stream = MapStream(map: transform)
        self.drain(into: stream)
        
        return stream
    }
}
