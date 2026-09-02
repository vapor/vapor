#warning("This should be internal")
public import NIOCore
import NIOFoundationEssentialsCompat
import NIOConcurrencyHelpers
public import Vapor
public import HTTPTypes
#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

/// What a tester should do with a response body before handing the response back.
public enum ResponseBodyCollection: Sendable {
    /// Read the whole body before returning. The default.
    ///
    /// A test that only asserts on headers would otherwise leave the body unread, and dropping an
    /// unread body cancels the request - which the server sees as the client hanging up mid-response.
    /// For a handler streaming a file that surfaces as a spurious failure, raced against however
    /// quickly the server finishes writing.
    case collect(max: Int?)

    /// Hand the body back still streaming, for asserting on chunk boundaries or for a response too
    /// large to hold in memory.
    ///
    /// The test is then responsible for consuming it - see ``Vapor/Response/Body/withStreamingBytes(_:)``.
    case stream

    /// Read the whole body before returning, with no size limit.
    public static var collect: Self { .collect(max: nil) }
}

public struct TestingHTTPRequest: Sendable {
    public var method: HTTPRequest.Method
    public var url: URI
    public var headers: HTTPFields
    public var body: ByteBuffer
    public var contentConfiguration: ContentConfiguration
    /// How the tester should hand back the response body. Defaults to ``ResponseBodyCollection/collect``.
    public var responseBodyCollection: ResponseBodyCollection

    public init(
        method: HTTPRequest.Method,
        url: URI,
        headers: HTTPFields,
        body: ByteBuffer,
        contentConfiguration: ContentConfiguration,
        responseBodyCollection: ResponseBodyCollection = .collect
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
        self.contentConfiguration = contentConfiguration
        self.responseBodyCollection = responseBodyCollection
    }

    private struct _ContentContainer: ContentContainer {
        var body: Data
        var headers: HTTPFields
        let contentConfiguration: ContentConfiguration

        var contentType: HTTPMediaType? {
            self.headers.contentType
        }

        mutating func encode<E>(_ encodable: E, using encoder: any ContentEncoder) throws where E : Encodable {
            try encoder.encode(encodable, to: &self.body, headers: &self.headers, userInfo: [:])
        }

        func decode<D>(_ decodable: D.Type, using decoder: any ContentDecoder) throws -> D where D : Decodable {
            fatalError("Decoding from test request is not supported.")
        }

        mutating func encode<C>(_ content: C, using encoder: any ContentEncoder) throws where C : Content {
            var content = content
            try content.beforeEncode()
            try encoder.encode(content, to: &self.body, headers: &self.headers, userInfo: [:])
        }
    }

    public var content: any ContentContainer {
        get { _ContentContainer(body: self.body.getData(at: 0, length: self.body.readableBytes) ?? Data(), headers: self.headers, contentConfiguration: self.contentConfiguration) }
        set {
            let content = (newValue as! _ContentContainer)
            self.body = ByteBuffer(data: content.body)
            self.headers = content.headers
        }
    }

    private struct _URLQueryContainer: URLQueryContainer {
        var url: URI
        let contentConfiguration: ContentConfiguration

        func decode<D>(_ decodable: D.Type, using decoder: any URLQueryDecoder) throws -> D
            where D: Decodable
        {
            fatalError("Decoding from test request is not supported.")
        }

        mutating func encode(_ encodable: some Encodable, using encoder: any URLQueryEncoder) throws {
            try encoder.encode(encodable, to: &self.url)
        }
    }

    public var query: any URLQueryContainer {
        get { _URLQueryContainer(url: url, contentConfiguration: self.contentConfiguration) }
        set {
            let query = (newValue as! _URLQueryContainer)
            self.url = query.url
        }
    }
}
