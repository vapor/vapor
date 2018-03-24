import Foundation
import NIO

extension DataDecoder {
    /// Gets a single decodable value at the supplied key path from the data.
    internal func get<D>(at keyPath: [BasicKey], from data: Data) throws -> D where D: Decodable {
        return try self.decode(DecoderUnwrapper.self, from: data).get(at: keyPath)

    }
}

extension HTTPBodyDecoder {
    /// Gets a single decodable value at the supplied key path from the data.
    internal func get<D>(at keyPath: [BasicKey], from body: HTTPBody, maxSize: Int, on worker: Worker) throws -> Future<D> where D: Decodable {
        return try self.decode(DecoderUnwrapper.self, from: body, maxSize: maxSize, on: worker).map(to: D.self) { decoder in
            return try decoder.get(at: keyPath)
        }
    }
}

/// MARK: Private

fileprivate struct DecoderUnwrapper: Decodable {
    let decoder: Decoder
    init(from decoder: Decoder) throws {
        self.decoder = decoder
    }
    
    func get<D>(at keyPath: [BasicKey]) throws -> D where D: Decodable {
        let unwrapper = self
        var state = try ContainerState.keyed(unwrapper.decoder.container(keyedBy: BasicKey.self))

        var keys = Array(keyPath.reversed())
        if keys.count == 0 {
            return try unwrapper.decoder.singleValueContainer().decode(D.self)
        }

        while let key = keys.popLast() {
            switch keys.count {
            case 0:
                switch state {
                case .keyed(let keyed):
                    return try keyed.decode(D.self, forKey: key)
                case .unkeyed(var unkeyed):
                    return try unkeyed.nestedContainer(keyedBy: BasicKey.self)
                        .decode(D.self, forKey: key)
                }
            case 1...:
                let next = keys.last!
                if let index = next.intValue {
                    switch state {
                    case .keyed(let keyed):
                        var new = try keyed.nestedUnkeyedContainer(forKey: key)
                        state = try .unkeyed(new.skip(to: index))
                    case .unkeyed(var unkeyed):
                        var new = try unkeyed.nestedUnkeyedContainer()
                        state = try .unkeyed(new.skip(to: index))
                    }
                } else {
                    switch state {
                    case .keyed(let keyed):
                        state = try .keyed(keyed.nestedContainer(keyedBy: BasicKey.self, forKey: key))
                    case .unkeyed(var unkeyed):
                        state = try .keyed(unkeyed.nestedContainer(keyedBy: BasicKey.self))
                    }
                }
            default: fatalError("Unexpected negative key count")
            }
        }
        fatalError("`while let key = keys.popLast()` should never fallthrough")
    }
}

fileprivate enum ContainerState {
    case keyed(KeyedDecodingContainer<BasicKey>)
    case unkeyed(UnkeyedDecodingContainer)
}

extension UnkeyedDecodingContainer {
    fileprivate mutating func skip(to count: Int) throws -> UnkeyedDecodingContainer {
        for _ in 0..<count {
            _ = try self.nestedContainer(keyedBy: BasicKey.self)
        }
        return self
    }
}
