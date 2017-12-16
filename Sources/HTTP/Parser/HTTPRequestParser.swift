import Bits
import CHTTP
import Async
import Dispatch
import Foundation

/// Parses requests from a readable stream.
public final class HTTPRequestParser: CHTTPParser {
    /// See CParser.Message
    public typealias Message = HTTPRequest

    /// See CHTTPParser.parserType
    static let parserType: http_parser_type = HTTP_REQUEST

    // Internal variables to conform
    // to the C HTTP parser protocol.
    var parser: http_parser
    var settings: http_parser_settings
    var state:  CHTTPParserState

    /// The maxiumum possible body size
    /// larger sizes will result in an error
    internal let maxSize: Int

    public var message: Message?

    /// Creates a new Request parser.
    public init(maxSize: Int) {
        self.parser = http_parser()
        self.settings = http_parser_settings()
        self.state = .ready
        self.maxSize = maxSize
        reset()
    }

    func makeMessage(from results: CParseResults) throws -> HTTPRequest {
        // require a version to have been parsed
        guard
            let version = results.version,
            let headers = results.headers
        else {
            throw HTTPError.invalidMessage()
        }
        
        /// switch on the C method type from the parser
        let method: HTTPMethod
        switch http_method(parser.method) {
        case HTTP_DELETE:
            method = .delete
        case HTTP_GET:
            method = .get
        case HTTP_POST:
            method = .post
        case HTTP_PUT:
            method = .put
        case HTTP_OPTIONS:
            method = .options
        case HTTP_PATCH:
            method = .patch
        default:
            /// custom method detected,
            /// convert the method into a string
            /// and use Engine's other type
            guard
                let pointer = http_method_str(http_method(parser.method)),
                let string = String(validatingUTF8: pointer)
            else {
                throw HTTPError.invalidMessage()
            }
            method = HTTPMethod(string)
        }
        
        // parse the uri from the url bytes.
        var uri = URIParser.shared.parse(data: results.url)
        
        // if there is no scheme, use http by default
        if uri.scheme?.isEmpty == true {
            uri.scheme = "http"
        }
        
        // create the request
        return HTTPRequest(
            method: method,
            uri: uri,
            version: version,
            headers: headers,
            body: results.body
        )
    }
}

