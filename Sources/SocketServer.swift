import Foundation

#if os(Linux)
    import Glibc
#endif

public class SocketServer {
    
    /**
     * A socket open to the port the server is listening on. Usually 80.
     */
    private var listenSocket: Socket = Socket(socketFileDescriptor: -1)

    /**
     * A set of connected client sockets.
     */
    private var clientSockets: Set<Socket> = []

    /**
     * The shared lock for notifying new connections.
     */
    private let clientSocketsLock = NSLock()
    
    /**
     * Starts the server on a given port.
     * @param listenPort The port to listen on.
     */
    func start(listenPort: in_port_t) throws {
        //stop the server if it's running
        self.stop()

        //open a socket, might fail
        self.listenSocket = try Socket.tcpSocketForListen(listenPort)

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {

            //creates the infinite loop that will wait for client connections
            while let socket = try? self.listenSocket.acceptClientSocket() {

                //wait for lock to notify a new connection
                self.lock(self.clientSocketsLock) {
                    //keep track of open sockets
                    self.clientSockets.insert(socket)
                }

                //handle connection in background thread
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), {
                    self.handleConnection(socket)

                    //set lock to wait for another connection
                    self.lock(self.clientSocketsLock) {
                        self.clientSockets.remove(socket)
                    }
                })
            }

            //stop the server in case something didn't work
            self.stop()
        }
    }

    /**
     * Starts an infinite loop to keep the server alive while it
     * waits for inbound connections.
     */
    func loop() {
        #if os(Linux)
            while true {
                sleep(1)
            }
        #else
            NSRunLoop.mainRunLoop().run()
        #endif
    }
    
    func handleConnection(socket: Socket) {
        //try to get the ip address of the incoming request (like 127.0.0.1)
        let address = try? socket.peername()

        //create a request parser
        let parser = Parser()

        while let request = try? parser.readHttpRequest(socket) {
            //dispatch the server to handle the request
            let dispatchResponse = self.dispatch(request.method, path: request.path)

            //add parameters to request
            request.address = address
            request.parameters = dispatchResponse.parameters

            let response = dispatchResponse.handler(request)
            var keepConnection = parser.supportsKeepAlive(request.headers)
            do {
                keepConnection = try self.respond(socket, response: response, keepAlive: keepConnection)
            } catch {
                print("Failed to send response: \(error)")
                break
            }
            if !keepConnection { break }
        }

        //release the connection
        socket.release()
    }

    /**
     * Typealias for the enum returned by Server dispatch method.
     */
    typealias DispatchResponse = (parameters: [String: String], handler: (Request -> Response))
    
    /**
     * Returns a closure that given a Request returns a Response
     *
     * @return DispatchResponse
     */
    func dispatch(method: Method, path: String) -> DispatchResponse {
        return ([:], { _ in 
            return .NotFound 
        })
    }
    
    /**
     * Stops the server
     */
    func stop() {
        //free the port
        self.listenSocket.release()

        //shutdown all client sockets
        self.lock(self.clientSocketsLock) {
            for socket in self.clientSockets {
                socket.shutdwn()
            }
            self.clientSockets.removeAll(keepCapacity: true)
        }
    }
    
    /**
     * Locking mechanism for holding thread until a 
     * new socket connection is ready.
     * 
     * @param handle NSLock
     * @param closure Code that will run when the lock has been altered.
     */
    private func lock(handle: NSLock, closure: () -> ()) {
        handle.lock()
        closure()
        handle.unlock();
    }
    
    private struct InnerWriteContext: ResponseBodyWriter {
        let socket: Socket
        func write(data: [UInt8]) {
            let _ = try? socket.writeUInt8(data)
        }
    }
    
    /**
     * Writes the response to the client socket.
     */
    private func respond(socket: Socket, response: Response, keepAlive: Bool) throws -> Bool {
        try socket.writeUTF8("HTTP/1.1 \(response.statusCode()) \(response.reasonPhrase())\r\n")
        
        let content = response.content()
        
        if content.length >= 0 {
            try socket.writeUTF8("Content-Length: \(content.length)\r\n")
        }
        
        if keepAlive && content.length != -1 {
            try socket.writeUTF8("Connection: keep-alive\r\n")
        }
        
        for (name, value) in response.headers() {
            try socket.writeUTF8("\(name): \(value)\r\n")
        }
        
        try socket.writeUTF8("\r\n")
    
        if let writeClosure = content.writeClosure {
            let context = InnerWriteContext(socket: socket)
            try writeClosure(context)
        }
        
        return keepAlive && content.length != -1;
    }
}
