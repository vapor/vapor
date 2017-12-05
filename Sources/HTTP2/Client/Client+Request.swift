import Async
import HTTP

extension HTTP2Client {
    /// Sends a request and receives a response
    /// TODO: Disconnected connection during the request cascading here
    public func send(request: HTTPRequest) -> Future<HTTPResponse> {
        if let client = http1Client {
            return client.send(request: request)
        } else {
            return sendHTTP2(request: request)
        }
    }
    
    /// Sends a request over HTTP/2
    func sendHTTP2(request: HTTPRequest) -> Future<HTTPResponse> {
        return then {
            let promise = Promise<HTTPResponse>()
            
            // Open an HTTP/2 stream
            let stream = self.openStream()
            
            // Create a response to build up
            var response = HTTPResponse()
            let body = BodyStream()
            
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
                    frame.payload.data.withByteBuffer(body.onInput)
                    
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
            
            // Send all header frames
            for frame in try request.headerFrames(for: stream) {
                stream.context.serializer.onInput(frame)
            }
            
            // TODO: Send the body
            
            return promise.future
        }
    }
}
