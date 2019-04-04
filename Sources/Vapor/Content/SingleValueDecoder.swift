internal extension RequestDecoder {
    /// Gets a single decodable value at the supplied key path from the data.
    func get<D>(at keyPath: [BasicCodingKey], from request: Request) throws -> D
        where D: Decodable
    {
        let decoder = try self.decode(SingleValueDecoder.self, from: request)
        return try decoder.get(at: keyPath)
    }
}

internal extension URLContentDecoder {
    /// Gets a single decodable value at the supplied key path from the data.
    func get<D>(at keyPath: [BasicCodingKey], from url: URL) throws -> D
        where D: Decodable
    {
        let decoder = try self.decode(SingleValueDecoder.self, from: url)
        return try decoder.get(at: keyPath)
    }
}

/// MARK: Private

/// Decodes nested, single values from data at a key path.
private struct SingleValueDecoder: Decodable {
    let decoder: Decoder
    init(from decoder: Decoder) throws {
        self.decoder = decoder
    }
    
    func get<D>(at keyPath: [BasicCodingKey]) throws -> D where D: Decodable {
        let unwrapper = self
        var state = try ContainerState.keyed(unwrapper.decoder.container(keyedBy: BasicCodingKey.self))
        
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
                    return try unkeyed.nestedContainer(keyedBy: BasicCodingKey.self)
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
                        state = try .keyed(keyed.nestedContainer(keyedBy: BasicCodingKey.self, forKey: key))
                    case .unkeyed(var unkeyed):
                        state = try .keyed(unkeyed.nestedContainer(keyedBy: BasicCodingKey.self))
                    }
                }
            default: fatalError("Unexpected negative key count")
            }
        }
        fatalError("`while let key = keys.popLast()` should never fallthrough")
    }
}

private enum ContainerState {
    case keyed(KeyedDecodingContainer<BasicCodingKey>)
    case unkeyed(UnkeyedDecodingContainer)
}

private extension UnkeyedDecodingContainer {
    mutating func skip(to count: Int) throws -> UnkeyedDecodingContainer {
        for _ in 0..<count {
            _ = try nestedContainer(keyedBy: BasicCodingKey.self)
        }
        return self
    }
}
