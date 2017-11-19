import CHTTP
import Async
import Bits
import Foundation

/// Parses requests from a readable stream.
public final class ResponseParser: CParser, Async.Stream {
    // MARK: Stream
    public typealias Input = ByteBuffer
    public typealias Output = Response
    public var outputStream: OutputHandler?
    public var errorStream: ErrorHandler?
    
    // Internal variables to conform
    // to the C HTTP parser protocol.
    var parser: http_parser
    var settings: http_parser_settings
    var state:  CHTTPParserState
    
    let maxBodySize: Int
    
    /// Creates a new Request parser.
    public init(maxBodySize: Int) {
        self.parser = http_parser()
        self.settings = http_parser_settings()
        self.state = .ready
        self.maxBodySize = maxBodySize
        reset(HTTP_RESPONSE)
    }

    /// Resets the parser so it can accept new data.
    /// Call this method if parsing fails.
    func reset() {
        http_parser_init(&parser, HTTP_REQUEST)
        initialize(&settings)
    }
    
    /// Handles incoming stream data
    public func inputStream(_ input: ByteBuffer) {
        do {
            guard let request = try parse(from: input) else {
                return
            }
            output(request)
        } catch {
            self.errorStream?(error)
            reset(HTTP_RESPONSE)
        }
    }
    
    public func parse(from data: Data) throws -> Response? {
        return try data.withUnsafeBytes { (pointer: BytesPointer) in
            let buffer = ByteBuffer(start: pointer, count: data.count)
            return try parse(from: buffer)
        }
    }
    
    /// Parses a Request from the stream.
    public func parse(from buffer: ByteBuffer) throws -> Response? {
        let results: CParseResults
        
        switch state {
        case .ready:
            // create a new results object and set
            // a reference to it on the parser
            let newResults = CParseResults.set(on: &parser, maxBodySize: maxBodySize)
            results = newResults
            state = .parsing
        case .parsing:
            // get the current parse results object
            guard let existingResults = CParseResults.get(from: &parser) else {
                return nil
            }
            results = existingResults
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

        /// get response status
        let status = Status(code: Int(parser.status_code))

        // require a version to have been parsed
        guard let version = results.version else {
            throw HTTPError.invalidMessage()
        }
        
        let body = Body(results.body)
        
        let headers = Headers(storage: results.headersData, indexes: results.headersIndexes)
        
        // create the request
        return Response(
            version: version,
            status: status,
            headers: headers,
            body: body
        )
    }
}


