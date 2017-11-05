extension OutputStream where Self: ClosableStream {
    /// Captures the first next result in this stream.
    ///
    /// - parameter uniquely: If `true`, this notification will temporary replace the current listener. If `false`, the current listener will still receive the results
    /// - Throws: The stream is closed prematurely
    public func captureFirst(uniquely: Bool = false) -> Future<Notification> {
        let outputStream = self.outputStream
        let promise = Promise<Notification>()
        
        self.catch(promise.fail)
        
        self.closeNotification.handleNotification {
            promise.fail(AsyncError(identifier: "stream-closed", reason: "The stream closed before returning the next result"))
        }
        
        self.drain { result in
            promise.complete(result)
            
            if uniquely {
                outputStream?(result)
            }
            
            self.outputStream = outputStream
        }
        
        return promise.future
    }
    
    /// Captures exactly the first next `n` results in this stream.
    ///
    /// - parameter uniquely: If `true`, this notification will temporary replace the current listener. If `false`, the current listener will still receive the results
    /// - Throws: The stream is closed prematurely
    public func capture(_ n: Int, uniquely: Bool = false) -> Future<[Notification]> {
        let outputStream = self.outputStream
        
        let promise = Promise<[Notification]>()
        
        var next = [Notification]()
        next.reserveCapacity(n)
        
        self.catch(promise.fail)
        
        self.closeNotification.handleNotification {
            promise.fail(AsyncError(identifier: "stream-closed", reason: "The stream closed before returning the next result"))
        }
        
        self.drain { result in
            next.append(result)
            
            if uniquely {
                outputStream?(result)
            }
            
            if next.count == n {
                self.outputStream = outputStream
            }
        }
        
        return promise.future
    }
    
    /// Captures exactly the first next `n` results in this stream unless the stream is closed
    ///
    /// - parameter uniquely: If `true`, this notification will temporary replace the current listener. If `false`, the current listener will still receive the results
    /// - Throws: If the stream is closed prematurely, all currently fetched results are completed with
    public func capture(maximum n: Int, uniquely: Bool = false) -> Future<[Notification]> {
        let outputStream = self.outputStream
        
        let promise = Promise<[Notification]>()
        
        var next = [Notification]()
        next.reserveCapacity(n)
        
        self.catch(promise.fail)
        
        self.closeNotification.handleNotification {
            promise.complete(next)
        }
        
        self.drain { result in
            next.append(result)
            
            if uniquely {
                outputStream?(result)
            }
            
            if next.count == n {
                self.outputStream = outputStream
            }
        }
        
        return promise.future
    }
}

