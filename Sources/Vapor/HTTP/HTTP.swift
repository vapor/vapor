import Engine

public typealias Headers = [HeaderKey: String]
public typealias Request = HTTPRequest
public typealias Accept = HTTPAccept
public typealias Responder = Engine.HTTPResponder
public typealias Response = Engine.HTTPResponse
public typealias ResponseRepresentable = Engine.HTTPResponseRepresentable
public typealias HTTPBody = Engine.HTTPBody
public typealias HTTPClient<ClientStreamType: ClientStream> = Engine.HTTPClient<ClientStreamType>
public typealias HTTPServer = Engine.HTTPServer
public typealias HTTPMessage = Engine.HTTPMessage
public typealias HTTPParser<Message: HTTPMessage> = Engine.HTTPParser<Message>
public typealias HTTPSerializer<Message: HTTPMessage> = Engine.HTTPSerializer<Message>
public typealias HTTPResponder = Engine.HTTPResponder
public typealias HTTPBodyRepresentable = Engine.HTTPBodyRepresentable
public typealias ServerError = Engine.ServerError
public typealias Server = Engine.Server
public typealias ServerErrorHandler = Engine.ServerErrorHandler
public typealias SecurityLayer = Engine.SecurityLayer
#if !os(Linux)
public typealias FoundationStream = Engine.FoundationStream
#endif
