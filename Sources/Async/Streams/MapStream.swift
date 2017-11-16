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
/// [Learn More →](https://docs.vapor.codes/3.0/async/streams-introduction/#transforming-streams-without-an-intermediary-stream)
public final class MapStream<In, Out>: Stream {
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
            try output(map(input))
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
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/async/streams-introduction/#transforming-streams-without-an-intermediary-stream)
    public func map<T>(_ transform: @escaping ((Output) throws -> (T))) -> MapStream<Output, T> {
        let stream = MapStream(map: transform)
        self.drain(into: stream)
        self.errorStream = { error in
            stream.errorStream?(error)
        }
        return stream
    }
}
