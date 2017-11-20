import Async
import Bits
import TCP

/// An HTTP client wrapped around TCP client
///
/// Can handle a single `Request` at a given time.
///
/// Multiple requests at the same time are subject to unknown behaviour
///
/// [Learn More →](https://docs.vapor.codes/3.0/http/client/)
public final class HTTPClient {
    /// Serializes the inputted `Request`s
    let serializer = RequestSerializer()
    
    /// Parses the received `Response`s
    let parser: ResponseParser
    
    var promise: Promise<Response>?
    
    /// Creates a new Client wrapped around a `TCP.Client`
    public init<DuplexByteStream: Async.Stream>(stream: DuplexByteStream, maxBodySize: Int = 10_000_000) where DuplexByteStream.Input == ByteBuffer, DuplexByteStream.Output == ByteBuffer, DuplexByteStream: ClosableStream {
        self.parser = ResponseParser(maxBodySize: maxBodySize)
        
        self.serializer.drain { data in
            try data.withByteBuffer(stream.inputStream)
        }
        
        stream.drain(into: parser)
        
        parser.drain { response in
            self.promise?.complete(response)
        }.catch { error in
            self.promise?.fail(error)
        }
        
        stream.catch { error in
            self.promise?.fail(error)
        }
    }
    
    /// Sends a single `Request` and returns a future that can be completed with a `Response`
    ///
    /// The `Client` *must* not be used during the Future's completion.
    public func send(request encodable: RequestEncodable) throws -> Future<Response> {
        let promise = Promise<Response>()
        
        self.promise = promise
      
        parser.drain(promise.complete).catch(promise.fail)
        serializer.catch(promise.fail)
        
        var req = Request()
        try encodable.encode(to: &req).do {
            self.serializer.inputStream(req)
        }.catch(promise.fail)
        
        return promise.future
    }
}
