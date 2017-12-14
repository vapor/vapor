 import CHTTP
import Async
import Bits
import Foundation

/// Parses requests from a readable stream.
public final class HTTPResponseParser: CHTTPParser {
    /// See HTTPParser.Message
    public typealias Message = HTTPResponse

    /// See CHTTPParser.parserType
    static let parserType: http_parser_type = HTTP_RESPONSE

    public var message: HTTPResponse?
    
    // Internal variables to conform
    // to the C HTTP parser protocol.
    var parser: http_parser
    var settings: http_parser_settings
    var state:  CHTTPParserState

    /// The maxiumum possible body size
    /// larger sizes will result in an error
    internal let maxSize: Int
    
    /// Creates a new Request parser.
    public init(maxSize: Int) {
        self.parser = http_parser()
        self.settings = http_parser_settings()
        self.state = .ready
        self.maxSize = maxSize
        reset()
    }

    /// See CHTTPParser.makeMessage
    func makeMessage(from results: CParseResults) throws -> HTTPResponse {
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
}
