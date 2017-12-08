 import CHTTP
import Async
import Bits
import Foundation

/// Parses requests from a readable stream.
public final class ResponseParser: CParser, Async.Stream, ClosableStream {
    /// See InputStream.Input
    public typealias Input = ByteBuffer

    /// See OutputStream.Output
    public typealias Output = HTTPResponse
    
    // Internal variables to conform
    // to the C HTTP parser protocol.
    var parser: http_parser
    var settings: http_parser_settings
    var state:  CHTTPParserState

    /// The maxiumum possible body size
    /// larger sizes will result in an error
    internal let maxSize: Int

    /// Use a basic stream to easily implement our output stream.
    private var outputStream: BasicStream<Output>
    
    /// Creates a new Request parser.
    public init(maxSize: Int) {
        self.parser = http_parser()
        self.settings = http_parser_settings()
        self.state = .ready
        self.maxSize = maxSize
        self.outputStream = .init()
        reset(HTTP_RESPONSE)
    }

    /// Resets the parser so it can accept new data.
    /// Call this method if parsing fails.
    func reset() {
        http_parser_init(&parser, HTTP_REQUEST)
        initialize(&settings)
    }
    
    /// Handles incoming stream data
    public func onInput(_ input: ByteBuffer) {
        do {
            guard let response = try parse(from: input) else {
                return
            }
            
            outputStream.onInput(response)
        } catch {
            onError(error)
            reset(HTTP_RESPONSE)
        }
    }
    
    /// See ClosableStream.close
    public func close() {
        defer {
            self.outputStream.close()
        }
        
        guard let results = getResults(), let headers = results.headers else {
            return
        }
        
        if headers[.connection]?.lowercased() == "close" {
            
        }
    }
    
    /// See ClosableStream.onClose
    public func onClose(_ onClose: ClosableStream) {
        self.outputStream.onClose(onClose)
    }
    
    /// See InputStream.onError
    public func onError(_ error: Error) {
        outputStream.onError(error)
    }

    /// See OutputStream.onOutput
    public func onOutput<I>(_ input: I) where I: Async.InputStream, Output == I.Input {
        outputStream.onOutput(input)
    }

    /// Parses the supplied data into a response or throws an error.
    /// If the data is incomplete, a nil response will be returned.
    /// Contiguous data may be supplied as multiple calls.
    public func parse(from data: Data) throws -> HTTPResponse? {
        return try data.withUnsafeBytes { (pointer: BytesPointer) in
            let buffer = ByteBuffer(start: pointer, count: data.count)
            return try parse(from: buffer)
        }
    }
    
    func makeResponse(from results: CParseResults) throws -> HTTPResponse {
        // require a version to have been parsed
        guard
            let version = results.version,
            let headers = results.headers
        else {
            throw HTTPError.invalidMessage()
        }
        
        /// get response status
        let status = HTTPStatus(code: Int(parser.status_code))
        
        // create the request
        return HTTPResponse(
            version: version,
            status: status,
            headers: headers,
            body: results.body
        )
    }
    
    /// Parses a Request from the stream.
    public func parse(from buffer: ByteBuffer) throws -> HTTPResponse? {
        guard let results = getResults() else {
            return nil
        }
        
        /// parse the message using the C HTTP parser.
        try executeParser(max: buffer.count, from: buffer)
        
        guard results.isComplete else {
            return nil
        }
        
        // the results have completed, so we are ready
        // for a new request to come in
        state = .ready
        CParseResults.remove(from: &parser)
        
        return try makeResponse(from: results)
    }
}


