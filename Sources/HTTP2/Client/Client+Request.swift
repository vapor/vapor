import Async
import HTTP

extension HTTP2Client {
    /// Sends a request and receives a response
    /// TODO: Disconnected connection during the request cascading here
    public func send(_ request: RequestRepresentable) throws -> Future<Response> {
        do {
            // Serialize the request
            let request = try request.makeRequest()
            let promise = Promise<Response>()
            
            // Open an HTTP/2 stream
            let stream = openStream()
            
            // Create a response to build up
            let response = Response()
            
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
                        self.context.serializer.inputStream(ResetFrame(code: .protocolError, stream: frame.streamIdentifier).frame)
                        self.errorStream?(error)
                        return
                    }
                case .data:
                    response.body.data.append(contentsOf: frame.payload.data)
                    
                    // If the `END_STREAM` is set
                    if frame.flags & 0x01 != 0 {
                        promise.complete(response)
                    }
                case .reset:
                    promise.fail(Error(.clientError))
                default:
                    break
                }
            }
            
            // Fail the promise on stream errors
            stream.catch(promise.fail)
            
            // Send all header frames
            for frame in try request.headerFrames(for: stream) {
                stream.context.serializer.inputStream(frame)
            }
            
            // TODO: Send the body
            
            return promise.future
        } catch {
            return Future(error: error)
        }
    }
}
