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
    public typealias Notification = Out

    /// See OutputStream.outputStream
    public var outputStream: NotificationCallback?

    /// See BaseStream.errorNotification
    public let errorNotification = SingleNotification<Error>()
    
    /// Create a new emitter stream.
    public init(_ type: Out.Type = Out.self) { }

    /// Emits an output.
    public func emit(_ output: Notification) {
        outputStream?(output)
    }

    /// Emits an error.
    public func report(_ error: Error) {
        errorNotification.notify(of: error)
    }
}
