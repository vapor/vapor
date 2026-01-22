import NIOCore
import NIOConcurrencyHelpers
import NIOWebSocket
import WebSocketKit
import Foundation

// MARK: - WebSocket.Message

extension WebSocket {
    /// A type-safe representation of WebSocket messages.
    ///
    /// `Message` encapsulates the different types of data that can be received
    /// over a WebSocket connection, providing a unified async-friendly interface.
    ///
    /// ## Usage
    /// ```swift
    /// app.webSocket("echo") { req, ws async in
    ///     for try await message in ws.messages {
    ///         switch message {
    ///         case .text(let text):
    ///             try await ws.send(text.reversed())
    ///         case .binary(let data):
    ///             try await ws.send(data)
    ///         case .ping, .pong:
    ///             break
    ///         }
    ///     }
    /// }
    /// ```
    public enum Message: Sendable {
        /// A text message containing a UTF-8 encoded string.
        case text(String)
        /// A binary message containing raw bytes.
        case binary(ByteBuffer)
        /// A ping control frame.
        case ping(ByteBuffer)
        /// A pong control frame.
        case pong(ByteBuffer)
    }
}

// MARK: - WebSocket Async Message Stream

extension WebSocket {
    /// An async sequence of incoming WebSocket messages.
    ///
    /// Use this property to receive WebSocket messages using Swift's async/await syntax
    /// with proper backpressure handling.
    ///
    /// ## Example
    /// ```swift
    /// for try await message in ws.messages {
    ///     switch message {
    ///     case .text(let text):
    ///         print("Received text: \(text)")
    ///     case .binary(let data):
    ///         print("Received \(data.readableBytes) bytes")
    ///     case .ping, .pong:
    ///         // Ping/pong frames are automatically handled
    ///         break
    ///     }
    /// }
    /// ```
    ///
    /// The stream completes when the WebSocket connection is closed.
    /// If an error occurs, it will be thrown from the iteration.
    public var messages: AsyncThrowingStream<Message, Error> {
        AsyncThrowingStream { continuation in
            self.onText { _, text in
                continuation.yield(.text(text))
            }
            
            self.onBinary { _, buffer in
                continuation.yield(.binary(buffer))
            }
            
            self.onPing { _, buffer in
                continuation.yield(.ping(buffer))
            }
            
            self.onPong { _, buffer in
                continuation.yield(.pong(buffer))
            }
            
            self.onClose.whenComplete { result in
                switch result {
                case .success:
                    continuation.finish()
                case .failure(let error):
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
