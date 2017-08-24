import CHTTP
import Core
import Foundation

/// Parses requests from a readable stream.
public final class ResponseParser: CParser {
    // MARK: Stream
    public typealias Input = DispatchData
    public typealias Output = Response
    public var outputStream: OutputHandler?
    public var errorStream: ErrorHandler?
    
    // Internal variables to conform
    // to the C HTTP parser protocol.
    var parser: http_parser
    var settings: http_parser_settings
    var state:  CHTTPParserState
    
    /// Creates a new Request parser.
    public init() {
        self.parser = http_parser()
        self.settings = http_parser_settings()
        self.state = .ready
        reset(HTTP_RESPONSE)
    }

    /// Resets the parser so it can accept new data.
    /// Call this method if parsing fails.
    func reset() {
        http_parser_init(&parser, HTTP_REQUEST)
        initialize(&settings)
    }
    
    /// Handles incoming stream data
    public func inputStream(_ input: DispatchData) {
        do {
            let data = Data(input)
            guard let request = try parse(from: data) else {
                return
            }
            outputStream?(request)
        } catch {
            self.errorStream?(error)
            reset(HTTP_RESPONSE)
        }
    }
    
    public func parse(from data: Data) throws -> Response? {
        let buffer = ByteBuffer(start: data.withUnsafeBytes { $0 }, count: data.count)
        return try parse(from: buffer)
    }
    
    /// Parses a Request from the stream.
    public func parse(from buffer: ByteBuffer) throws -> Response? {
        let results: CParseResults
        
        switch state {
        case .ready:
            // create a new results object and set
            // a reference to it on the parser
            let newResults = CParseResults.set(on: &parser)
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
        let headers = Headers(storage: results.headers)

        // require a version to have been parsed
        guard let version = results.version else {
            throw Error.invalidMessage()
        }
        
        let body: Body
        if let data = results.body {
            let copied = Data(data)
            body = Body(copied)
        } else {
            body = Body()
        }
        
        // create the request
        return Response(
            version: version,
            status: status,
            headers: headers,
            body: body
        )
    }
}


