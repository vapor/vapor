import Async
import Bits
import CodableKit
import HTTP

public final class JSONEncoderStream {
    public init() {}
    
    public func encode(_ encodable: Encodable) throws -> HTTPBody {
        let encoder = _JSONEncoderStream()
        try encodable.encode(to: encoder)
        
        return HTTPBody(chunked: encoder)
    }
}

fileprivate final class _JSONEncoderStream: Encoder, StreamEncoder, FutureEncoder, Async.OutputStream, ConnectionContext {
    typealias Output = ByteBuffer
    
    indirect enum Value {
        enum Literal {
            case null
            case string(String)
            case bool(Bool)
            case int(Int)
            case double(Double)
        }
        
        case array([Value])
        case dictionary([String: Value])
        case literal(Literal)
        case future(Future<Encodable>)
        case stream(EncodableStream)
    }
    
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey : Any]
    var downstream: AnyInputStream<ByteBuffer>?
    var downstreamDemand: UInt = 0
    var topLevel = true
    
    var value: Value?
    
    var encodingStream: EncodableStream?
    var complete = Promise<Encodable>()
    
    init() {
        self.userInfo = [:]
        self.codingPath = []
    }
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        defer { topLevel = false }
        return KeyedEncodingContainer(KeyedJSONencodingContainer<Key>(encoderStream: self, topLevel: topLevel))
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        defer { topLevel = false }
        
        fatalError()
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        defer { topLevel = false }
        return SingleValueJSONEncodingContainer(encoderStream: self, topLevel: topLevel)
    }
    
    func encodeFuture<E>(_ future: Future<E>) throws {
        let future = future.map(to: Encodable.self) { entity in
            guard let entity = entity as? Encodable else {
                throw VaporError(identifier: "future-encodable", reason: "The value in the future \(future) was not encodable")
            }
            
            return entity
        }
        
        value = .future(future)
    }
    
    func encodeStream<O>(_ stream: O) throws where O : ConnectionContext, O : OutputStream, O.Output == Encodable {
        value = .stream(stream.encode())
    }
    
    func output<S>(to inputStream: S) where S : InputStream, Output == S.Input {
        self.downstream = AnyInputStream(inputStream)
        inputStream.connect(to: self)
    }
    
    func connection(_ event: ConnectionEvent) {
        switch event {
        case .cancel:
            downstream?.close()
        case .request(let amount):
            self.downstreamDemand += amount
        }
    }
    
    func finishSerialization() {
        
    }
    
    deinit {
        self.cancel()
    }
}

fileprivate final class KeyedJSONencodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
    typealias Key = K
    
    var codingPath: [CodingKey] = []
    var encoderStream: _JSONEncoderStream
    var topLevel: Bool
    
    var dict = [String: _JSONEncoderStream.Value]()
    
    init(encoderStream: _JSONEncoderStream, topLevel: Bool) {
        self.encoderStream = encoderStream
        self.topLevel = topLevel
    }
    
    func encodeNil(forKey key: K) throws {
        dict[key.stringValue] = .literal(.null)
    }
    
    func encode(_ value: Bool, forKey key: K) throws {
        dict[key.stringValue] = .literal(.bool(value))
    }
    
    func encode(_ value: String, forKey key: K) throws {
        dict[key.stringValue] = .literal(.string(value))
    }
    
    func encode(_ value: Int, forKey key: K) throws {
        dict[key.stringValue] = .literal(.int(value))
    }
    
    func encode(_ value: Double, forKey key: K) throws {
        dict[key.stringValue] = .literal(.double(value))
    }
    
    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: K) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        let stream = _JSONEncoderStream()
        dict[key.stringValue] = .future(stream.complete.future)
        return KeyedEncodingContainer(KeyedJSONencodingContainer<NestedKey>(encoderStream: stream, topLevel: false))
    }
    
    func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
        fatalError()
//        let stream = _JSONEncoderStream()
//        try value.encode(to: stream)
//
//        dict[key.stringValue] = stream.value
    }
    
    func encode<T>(_ value: T, forKey key: K) throws where T : Encodable {
        let stream = _JSONEncoderStream()
        try value.encode(to: stream)
        
        dict[key.stringValue] = stream.value
    }
    
    func superEncoder() -> Encoder {
        return encoderStream
    }
    
    func superEncoder(forKey key: K) -> Encoder {
        return encoderStream
    }
    
    deinit {
        if topLevel {
            encoderStream.finishSerialization()
        }
    }
}

fileprivate struct SingleValueJSONEncodingContainer: SingleValueEncodingContainer {
    var codingPath: [CodingKey] = []
    var encoderStream: _JSONEncoderStream
    var topLevel: Bool
    
    init(encoderStream: _JSONEncoderStream, topLevel: Bool) {
        self.encoderStream = encoderStream
        self.topLevel = topLevel
    }
    
    func encodeNil() throws {
        encoderStream.value = .literal(.null)
    }
    
    func encode(_ value: Bool) throws {
        encoderStream.value = .literal(.bool(value))
    }
    
    func encode(_ value: Double) throws {
        encoderStream.value = .literal(.double(value))
    }
    
    func encode(_ value: String) throws {
        encoderStream.value = .literal(.string(value))
    }
    
    func encode(_ value: Int) throws {
        encoderStream.value = .literal(.int(value))
    }
    
    func encode<T>(_ value: T) throws where T : Encodable {
        try value.encode(to: encoderStream)
    }
}

