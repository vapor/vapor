import Engine

public typealias Headers = [HeaderKey: String]
public typealias Request = HTTPRequest
public typealias Accept = HTTPAccept
public typealias Responder = HTTPResponder
public typealias Response = HTTPResponse
public typealias ResponseRepresentable = Engine.HTTPResponseRepresentable
public typealias HTTPBody = Engine.HTTPBody
public typealias HTTPClient = Engine.HTTPClient
public typealias HTTPServer = Engine.HTTPServer
public typealias HTTPMessage = Engine.HTTPMessage
public typealias HTTPParser = Engine.HTTPParser
public typealias HTTPSerializer = Engine.HTTPSerializer
public typealias HTTPResponder = Engine.HTTPResponder
public typealias HTTPBodyRepresentable = Engine.HTTPBodyRepresentable
public typealias ServerError = Engine.ServerError
public typealias Server = Engine.Server
public typealias ServerErrorHandler = Engine.ServerErrorHandler
public typealias SecurityLayer = Engine.SecurityLayer
#if !os(Linux)
public typealias FoundationStream = Engine.FoundationStream
#endif
