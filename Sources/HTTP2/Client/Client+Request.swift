import Async
import HTTP

extension HTTP2Client {
    public func send(_ request: RequestRepresentable) throws -> Future<Response> {
        do {
            let request = try request.makeRequest()
            let promise = Promise<Response>()
            
            let stream = openStream()
            let response = Response()
            
            stream.drain { frame in
                switch frame.type {
                case .headers:
                    do {
                        let headers = try self.context.localHeaders.decode(frame.payload)
                        
                        print(headers)
                    } catch {
                        self.context.serializer.inputStream(ResetFrame(code: .protocolError, stream: frame.streamIdentifier).frame)
                        self.errorStream?(error)
                        return
                    }
                case .data:
                    let body = String(data: frame.payload.data, encoding: .utf8)
                    
                    print(body)
                case .reset:
                    promise.fail(Error(.clientError))
                default:
                    break
                }
            }
            
            stream.catch(promise.fail)
            
            for frame in try request.headerFrames(for: stream) {
                stream.context.serializer.inputStream(frame)
            }
            
            return promise.future
        } catch {
            return Future(error: error)
        }
    }
}
