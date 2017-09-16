import Core
import TCP

/// An HTTP client wrapped around TCP client
public final class Client {
    public let tcp: TCP.Client
    
    let serializer = RequestSerializer()
    let parser = ResponseParser()
    
    public init(tcp: TCP.Client) {
        self.tcp = tcp
    }
    
    public func send(request: Request) throws -> Future<Response> {
        let promise = Promise<Response>()
        
        parser.drain(promise.complete)
        tcp.drain(into: parser)
        
        let data = serializer.serialize(request)
        tcp.inputStream(data)
        
        return promise.future
    }
}
