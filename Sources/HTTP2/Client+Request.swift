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
                    fatalError()
                case .data:
                    fatalError()
                default:
                    break
                }
            }
            
            for frame in request.headerFrames(for: stream) {
                stream.inputStream(frame)
            }
            
            return promise.future
        } catch {
            return Future(error: error)
        }
    }
}
