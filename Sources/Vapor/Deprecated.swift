// nothing here yet...

@_exported import Console
@_exported import Command
@_exported import Foundation
@_exported import NIO
@_exported import NIOHTTP1
@_exported import HTTP
@_exported import Routing
@_exported import ServiceKit

@available(*, deprecated, renamed: "EventLoopFuture")
public typealias Future<T> = EventLoopFuture<T>

@available(*, deprecated, renamed: "HTTPResponse")
public typealias Response = HTTPResponse
