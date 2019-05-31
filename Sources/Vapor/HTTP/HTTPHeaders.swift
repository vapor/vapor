///// An HTTP message.
///// This is the basis of `HTTPRequest` and `HTTPResponse`. It has the general structure of:
/////
/////     <status line> HTTP/1.1
/////     Content-Length: 5
/////     Foo: Bar
/////
/////     hello
/////
///// - note: The status line contains information that differentiates requests and responses.
/////         If the status line contains an HTTP method and URI it is a request.
/////         If the status line contains an HTTP status code it is a response.
/////
///// This protocol is useful for adding methods to both requests and responses, such as the ability to serialize
///// content to both message types.
//public protocol HTTPMessage: CustomStringConvertible, CustomDebugStringConvertible {
//    /// The HTTP version of this message.
//    var version: HTTPVersion { get set }
//
//    /// The HTTP headers.
//    var headers: HTTPHeaders { get set }
//
//    /// The optional HTTP body.
//    var body: HTTPBody { get set }
//}

extension HTTPHeaders {
    /// `MediaType` specified by this message's `"Content-Type"` header.
    public var contentType: HTTPMediaType? {
        get { return self.firstValue(name: .contentType).flatMap(HTTPMediaType.parse) }
        set {
            if let new = newValue?.serialize() {
                self.replaceOrAdd(name: .contentType, value: new)
            } else {
                self.remove(name: .contentType)
            }
        }
    }
    
    /// Returns a collection of `MediaTypePreference`s specified by this HTTP message's `"Accept"` header.
    ///
    /// You can returns all `MediaType`s in this collection to check membership.
    ///
    ///     httpReq.accept.mediaTypes.contains(.html)
    ///
    /// Or you can compare preferences for two `MediaType`s.
    ///
    ///     let pref = httpReq.accept.comparePreference(for: .json, to: .html)
    ///
    public var accept: [HTTPMediaTypePreference] {
        return self.firstValue(name: .accept).flatMap([HTTPMediaTypePreference].parse) ?? []
    }
}
