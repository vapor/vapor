#if swift(>=5.8)

@_documentation(visibility: internal) @_exported import AsyncKit
@_documentation(visibility: internal) @_exported import class AsyncHTTPClient.HTTPClient
@_documentation(visibility: internal) @_exported import struct AsyncHTTPClient.HTTPClientError
@_documentation(visibility: internal) @_exported import Crypto
@_documentation(visibility: internal) @_exported import RoutingKit
@_documentation(visibility: internal) @_exported import ConsoleKit
@_documentation(visibility: internal) @_exported import Foundation
@_documentation(visibility: internal) @_exported import Logging
@_documentation(visibility: internal) @_exported import struct NIOCore.ByteBuffer
@_documentation(visibility: internal) @_exported import struct NIOCore.ByteBufferAllocator
@_documentation(visibility: internal) @_exported import protocol NIOCore.Channel
@_documentation(visibility: internal) @_exported import class NIOEmbedded.EmbeddedChannel
@_documentation(visibility: internal) @_exported import class NIOEmbedded.EmbeddedEventLoop
@_documentation(visibility: internal) @_exported import protocol NIOCore.EventLoop
@_documentation(visibility: internal) @_exported import class NIOCore.EventLoopFuture
@_documentation(visibility: internal) @_exported import protocol NIOCore.EventLoopGroup
@_documentation(visibility: internal) @_exported import struct NIOCore.EventLoopPromise
@_documentation(visibility: internal) @_exported import class NIOPosix.MultiThreadedEventLoopGroup
@_documentation(visibility: internal) @_exported import struct NIOPosix.NonBlockingFileIO
@_documentation(visibility: internal) @_exported import class NIOPosix.NIOThreadPool
@_documentation(visibility: internal) @_exported import enum NIOCore.System
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
@_exported import struct NIOCore.ByteBuffer
@_exported import struct NIOCore.ByteBufferAllocator
@_exported import protocol NIOCore.Channel
@_exported import class NIOEmbedded.EmbeddedChannel
@_exported import class NIOEmbedded.EmbeddedEventLoop
@_exported import protocol NIOCore.EventLoop
@_exported import class NIOCore.EventLoopFuture
@_exported import protocol NIOCore.EventLoopGroup
@_exported import struct NIOCore.EventLoopPromise
@_exported import class NIOPosix.MultiThreadedEventLoopGroup
@_exported import struct NIOPosix.NonBlockingFileIO
@_exported import class NIOPosix.NIOThreadPool
@_exported import enum NIOCore.System
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
