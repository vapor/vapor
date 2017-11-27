import Async
import HTTP

extension HTTP2Client {
    /// Sends a request and receives a response
    /// TODO: Disconnected connection during the request cascading here
    public func send(_ requestType: RequestEncodable) throws -> Future<Response> {
        do {
            // Serialize the request
            var request = Request()
            
            let promise = Promise<Response>()
            
            // Open an HTTP/2 stream
            let stream = openStream()
            
            // Create a response to build up
            let response = Response()
            let stream = BodyStream()
            
            stream.drain { frame in
                switch frame.type {
                case .headers:
                    do {
                        let headers = try self.context.localHeaders.decode(frame.payload)
                        
                        response.headers = response.headers + headers
                        
                        // If the `END_STREAM` is set
                        if frame.flags & 0x01 != 0 {
                            promise.complete(response)
                        }
                    } catch {
                        self.context.serializer.onInput(ResetFrame(code: .protocolError, stream: frame.streamIdentifier).frame)
                        self.onError(error)
                        return
                    }
                case .data:
                    promise.complete(response)
                    response.body.data.append(contentsOf: frame.payload.data)
                    
                    // If the `END_STREAM` is set
                    if frame.flags & 0x01 != 0 {
                        stream.close()
                    }
                case .reset:
                    promise.fail(HTTP2Error(.clientError))
                default:
                    break
                }
            }.catch { error in
                self.onError(error)
                promise.fail(error)
            }
            
            try requestType.encode(to: &request).map {
                // Send all header frames
                for frame in try request.headerFrames(for: stream) {
                    stream.context.serializer.onInput(frame)
                }
            }.catch { error in
                self.onError(error)
                promise.fail(error)
            }
            
            // TODO: Send the body
            
            return promise.future
        } catch {
            return Future(error: error)
        }
    }
}
