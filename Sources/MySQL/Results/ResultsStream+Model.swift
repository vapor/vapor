import Async

/// A stream of decoded models related to a query
final class ModelStream<Model>: Async.Stream where Model: Decodable {
    /// See InputStream.Input
    typealias Input = Row

    /// See OutputStream.Output
    typealias Output = Model

    /// Internal mapping stream
    private var mapStream: MapStream<Row, Model>

    /// Creates a new Model stream.
    init(_ model: Model.Type = Model.self) {
        mapStream = .init { row in
            let decoder = try RowDecoder(keyed: row, lossyIntegers: true, lossyStrings: true)
            return try Model(from: decoder)
        }
    }

    /// See InputStream.onInput
    func onInput(_ input: Row) {
        mapStream.onInput(input)
    }

    /// See InputStream.onError
    func onError(_ error: Error) {
        mapStream.onError(error)
    }

    /// See OutuptStream.onOutput
    func onOutput<I>(_ input: I) where I: InputStream, Model == I.Input {
        mapStream.onOutput(input)
    }
    
    func close() {
        mapStream.close()
    }
    
    func onClose(_ onClose: ClosableStream) {
        mapStream.onClose(onClose)
    }
}
