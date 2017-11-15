/// A basic output stream.
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
public final class EmitterStream<Out>: OutputStream {
    /// See OutputStream.Output
    public typealias Output = Out

    /// See OutputStream.outputStream
    public var outputStream: OutputHandler?

    /// See BaseStream.errorStream
    public var errorStream: ErrorHandler?

    /// Create a new emitter stream.
    public init(_ type: Out.Type = Out.self) { }

    /// Emits an output.
    public func emit(_ output: Output) {
        self.output(output)
    }

    /// Emits an error.
    public func report(_ error: Error) {
        errorStream?(error)
    }
}
