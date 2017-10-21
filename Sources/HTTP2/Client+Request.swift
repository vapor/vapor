import Async
import HTTP

extension HTTP2Client {
    public func send(_ request: RequestRepresentable) throws -> Future<Response> {
        do {
            let request = try request.makeRequest()
            let promise = Promise<Response>()
            
            let stream = openStream()
            
            stream.drain { frame in
                
            }
            
            for frame in request.headerFrames {
                stream.inputStream(frame)
            }
            
            return promise.future
        } catch {
            return Future(error: error)
        }
    }
}
