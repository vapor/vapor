import Async
import TCP

/// An HTTP client wrapped around TCP client
///
/// Can handle a single `Request` at a given time.
///
/// Multiple requests at the same time are subject to unknown behaviour
///
/// http://localhost:8000/http/client/
public final class HTTPClient {
    /// The underlying TCP Client
    public let tcp: TCPClient
    
    /// Serializes the inputted `Request`s
    let serializer = RequestSerializer()
    
    /// Parses the received `Response`s
    let parser: ResponseParser
    
    /// Creates a new Client wrapped around a `TCP.Client`
    public init(tcp: TCPClient, maxBodySize: Int = 10_000_000) {
        self.tcp = tcp
        self.parser = ResponseParser(maxBodySize: maxBodySize)
    }
    
    /// Sends a single `Request` and returns a future that can be completed with a `Response`
    ///
    /// The `Client` *must* not be used during the Future's completion.
    public func send(request: RequestRepresentable) throws -> Future<Response> {
        let promise = Promise<Response>()
        
        tcp.stream(to: parser).drain(promise.complete)
        
        tcp.errorStream = { error in
            promise.fail(error)
        }
        
        let data = serializer.serialize(try request.makeRequest())
        tcp.inputStream(data)
        
        return promise.future
    }
}
