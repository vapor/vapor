//import Async
//
///// Outputs all notifications for a listening client's channels
/////
///// [Learn More →](https://docs.vapor.codes/3.0/redis/pub-sub/#subscribing)
//public final class SubscriptionStream: Async.OutputStream {
//    /// See OutputStream.Output
//    public typealias Output = ChannelMessage
//
//    /// Use a basic output stream to implement output stream.
//    private var outputStream: BasicStream<Output> = .init()
//    
//    /// Drains a Redis Client's parser of it's results
//    init(reading parser: DataParser) {
//        parser.drain { data in
//            // Extracts the notification from this message
//            //
//            // - The type of notification
//            // - The channel on which the notification is emitted
//            // - The notification's payload
//            guard
//                let array = data.array,
//                array.count == 3,
//                let channel = array[1].string
//            else {
//                self.outputStream.onError(RedisError(.unexpectedResult(data)))
//                return
//            }
//            
//            // We're only accepting real notifications for now. No replies for completed subscribing and unsubscribing.
//            guard array[0].string == "message" else {
//                return
//            }
//            
//            let message = ChannelMessage(channel: channel, message: array[2])
//            
//            self.outputStream.onInput(message)
//        }.catch(onError: outputStream.onError)
//    }
//
//    /// See OutputStream.onOutput
//    public func onOutput<I>(_ input: I) where I : InputStream, SubscriptionStream.Output == I.Input {
//        outputStream.onOutput(input)
//    }
//    
//    /// See CloseableStream.close
//    public func close() {
//        outputStream.close()
//    }
//
//    /// See CloseableStream.onClose
//    public func onClose(_ onClose: ClosableStream) {
//        outputStream.onClose(onClose)
//    }
//}

