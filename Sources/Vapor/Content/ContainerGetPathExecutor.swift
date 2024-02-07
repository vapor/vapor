/// Decodes nested single values from data at a key path.
internal struct ContainerGetPathExecutor<D: Decodable>: Decodable {
    let result: D
    
    static func userInfo(for keyPath: [CodingKey]) -> [CodingUserInfoKey: Sendable] {
        [.containerGetKeypath: keyPath]
    }
    
    init(from decoder: Decoder) throws {
        guard let keypath = decoder.userInfo[.containerGetKeypath] as? [CodingKey] else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Container getter couldn't find keypath to fetch (broken Decoder?)"))
        }
        
        let lastDecoder = try keypath.dropLast().reduce(decoder) {
            if let index = $1.intValue {
                return try $0.unkeyedContainer(startingAt: index)._unsafe_inplace_superDecoder()
            } else {
                return try $0.container(keyedBy: BasicCodingKey.self).superDecoder(forKey: .key($1.stringValue))
            }
        }
        if let index = keypath.last?.intValue {
            var container = try lastDecoder.unkeyedContainer(startingAt: index)
            self.result = try container.decode(D.self)
        } else if let key = keypath.last?.stringValue {
            self.result = try lastDecoder.container(keyedBy: BasicCodingKey.self).decode(D.self, forKey: .key(key))
        } else {
            self.result = try lastDecoder.singleValueContainer().decode(D.self)
        }
    }
}

fileprivate extension CodingUserInfoKey {
    static var containerGetKeypath: Self { .init(rawValue: "codes.vapor.containers.keypathget")! }
}

fileprivate extension UnkeyedDecodingContainer {
    /// Skip the value at the "current" index of the container.
    ///
    /// Unfortunately, it is so common for a decoder's implementation of ``UnkeyedDecodingContainer/superDecoder()`` to
    /// be broken (when not just completely missing) that we have to add an extra check to debug builds to try to detect
    /// the most common implementation error, which can easily lead to a CPU-burning infinite loop (an actually non-
    /// terminating loop, not an infinite recursion, which would at least eventually crash).
    mutating func skip() throws {
        #if DEBUG
        let entryIndex = self.currentIndex
        #endif
        
        _ = try self.superDecoder()

        #if DEBUG
        assert(self.currentIndex != entryIndex, "Broken `UnkeyedDecodingContainer.superDecoder()` implementation detected!")
        #endif
    }
    
    /// Return the result of ``superDecoder()`` without requiring `self` to be mutating.
    ///
    /// Tagged with "unsafe" because a call to this method _MUST_ be the final use of the container before it goes out
    /// of scope, which we can't make the compiler enforce.
    func _unsafe_inplace_superDecoder() throws -> Decoder {
        var inplace = self
        return try inplace.superDecoder()
    }
}

fileprivate extension Decoder {
    /// Request an unkeyed container, then "fast-forward" the container until the given index is found, the current
    /// index goes past it, or the end of the container is reached.
    func unkeyedContainer(startingAt index: Int) throws -> UnkeyedDecodingContainer {
        var container = try self.unkeyedContainer()
        
        while container.currentIndex < index, !container.isAtEnd {
            try container.skip()
        }
        guard container.currentIndex == index, !container.isAtEnd else {
            throw DecodingError.keyNotFound(BasicCodingKey.index(index), .init(codingPath: container.codingPath, debugDescription: "Missing index \(index)"))
        }
        return container
    }
}
