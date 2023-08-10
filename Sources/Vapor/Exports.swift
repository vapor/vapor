#if swift(>=5.8)

@_documentation(visibility: internal) @_exported import AsyncKit
@_documentation(visibility: internal) @_exported import class AsyncHTTPClient.HTTPClient
@_documentation(visibility: internal) @_exported import struct AsyncHTTPClient.HTTPClientError
@_documentation(visibility: internal) @_exported import Crypto
@_documentation(visibility: internal) @_exported import RoutingKit
@_documentation(visibility: internal) @_exported import ConsoleKit
@_documentation(visibility: internal) @_exported import Foundation
@_documentation(visibility: internal) @_exported import Logging
@_documentation(visibility: internal) @_exported import struct NIO.ByteBuffer
@_documentation(visibility: internal) @_exported import struct NIO.ByteBufferAllocator
@_documentation(visibility: internal) @_exported import protocol NIO.Channel
@_documentation(visibility: internal) @_exported import class NIO.EmbeddedChannel
@_documentation(visibility: internal) @_exported import class NIO.EmbeddedEventLoop
@_documentation(visibility: internal) @_exported import protocol NIO.EventLoop
@_documentation(visibility: internal) @_exported import class NIO.EventLoopFuture
@_documentation(visibility: internal) @_exported import protocol NIO.EventLoopGroup
@_documentation(visibility: internal) @_exported import struct NIO.EventLoopPromise
@_documentation(visibility: internal) @_exported import class NIO.MultiThreadedEventLoopGroup
@_documentation(visibility: internal) @_exported import struct NIO.NonBlockingFileIO
@_documentation(visibility: internal) @_exported import class NIO.NIOThreadPool
@_documentation(visibility: internal) @_exported import enum NIO.System
@_documentation(visibility: internal) @_exported import class NIOConcurrencyHelpers.Lock
@_documentation(visibility: internal) @_exported import struct NIOHTTP1.HTTPHeaders
@_documentation(visibility: internal) @_exported import enum NIOHTTP1.HTTPMethod
@_documentation(visibility: internal) @_exported import struct NIOHTTP1.HTTPVersion
@_documentation(visibility: internal) @_exported import enum NIOHTTP1.HTTPResponseStatus
@_documentation(visibility: internal) @_exported import enum NIOHTTPCompression.NIOHTTPDecompression
@_documentation(visibility: internal) @_exported import struct NIOSSL.TLSConfiguration
@_documentation(visibility: internal) @_exported import WebSocketKit
@_documentation(visibility: internal) @_exported import MultipartKit

#else

@_exported import AsyncKit
@_exported import class AsyncHTTPClient.HTTPClient
@_exported import struct AsyncHTTPClient.HTTPClientError
@_exported import Crypto
@_exported import RoutingKit
@_exported import ConsoleKit
@_exported import Foundation
@_exported import Logging
@_exported import struct NIO.ByteBuffer
@_exported import struct NIO.ByteBufferAllocator
@_exported import protocol NIO.Channel
@_exported import class NIO.EmbeddedChannel
@_exported import class NIO.EmbeddedEventLoop
@_exported import protocol NIO.EventLoop
@_exported import class NIO.EventLoopFuture
@_exported import protocol NIO.EventLoopGroup
@_exported import struct NIO.EventLoopPromise
@_exported import class NIO.MultiThreadedEventLoopGroup
@_exported import struct NIO.NonBlockingFileIO
@_exported import class NIO.NIOThreadPool
@_exported import enum NIO.System
@_exported import class NIOConcurrencyHelpers.Lock
@_exported import struct NIOHTTP1.HTTPHeaders
@_exported import enum NIOHTTP1.HTTPMethod
@_exported import struct NIOHTTP1.HTTPVersion
@_exported import enum NIOHTTP1.HTTPResponseStatus
@_exported import enum NIOHTTPCompression.NIOHTTPDecompression
@_exported import struct NIOSSL.TLSConfiguration
@_exported import WebSocketKit
@_exported import MultipartKit
#endif
