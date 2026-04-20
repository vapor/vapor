//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2022 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// Provides Dictionary like indexing, but uses a flat array of key
/// value pairs, plus an array of hash keys for lookup for storage.
///
/// Useful for dictionary lookup on small collection that don't need
/// a tree lookup to optimise indexing.
///
/// The FlatDictionary also allows for key clashes. Standard lookup
/// functions will always return the first key found, but if you
/// iterate through the key,value pairs you can access all values
/// for a key
public struct FlatDictionary<Key: Hashable, Value>: Collection, ExpressibleByDictionaryLiteral {
    public typealias Element = (key: Key, value: Value)
    public typealias Index = Array<Element>.Index

    // MARK: Collection requirements

    /// The position of the first element
    public var startIndex: Index { self.elements.startIndex }
    /// The position of the element just after the last element
    public var endIndex: Index { self.elements.endIndex }
    /// Access element at specific position
    public subscript(_ index: Index) -> Element { self.elements[index] }
    /// Returns the index immediately after the given index
    public func index(after index: Index) -> Index { self.elements.index(after: index) }

    /// Create a new FlatDictionary
    public init() {
        self.elements = []
        self.hashKeys = []
    }

    /// Create a new FlatDictionary initialized with a dictionary literal
    public init(dictionaryLiteral elements: (Key, Value)...) {
        self.elements = elements.map { (key: $0.0, value: $0.1) }
        self.hashKeys = elements.map {
            Self.hashKey($0.0)
        }
    }

    /// Create a new FlatDictionary from an array of key value pairs
    public init(_ values: [Element]) {
        self.elements = values
        self.hashKeys = values.map {
            Self.hashKey($0.key)
        }
    }

    /// Access the value associated with a given key for reading and writing
    ///
    /// Because FlatDictionary allows for key clashes this function will
    /// return the first entry in the array with the associated key
    public subscript(_ key: Key) -> Value? {
        get {
            let hashKey = Self.hashKey(key)
            if let index = hashKeys.firstIndex(of: hashKey) {
                return self.elements[index].value
            } else {
                return nil
            }
        }
        set {
            let hashKey = Self.hashKey(key)
            if let index = hashKeys.firstIndex(of: hashKey) {
                if let newValue {
                    self.elements[index].value = newValue
                } else {
                    self.elements.remove(at: index)
                    self.hashKeys.remove(at: index)
                }
            } else if let newValue {
                self.elements.append((key: key, value: newValue))
                self.hashKeys.append(hashKey)
            }
        }
    }

    /// Return all the values, associated with a given key
    public subscript(values key: Key) -> [Value] {
        var values: [Value] = []
        let hashKey = Self.hashKey(key)

        for hashIndex in 0..<self.hashKeys.count {
            if self.hashKeys[hashIndex] == hashKey {
                values.append(self.elements[hashIndex].value)
            }
        }
        return values
    }

    ///  Return if dictionary has this value
    /// - Parameter key:
    public func has(_ key: Key) -> Bool {
        let hashKey = Self.hashKey(key)
        return self.hashKeys.firstIndex(of: hashKey) != nil
    }

    /// Append a new key value pair to the list of key value pairs
    public mutating func append(key: Key, value: Value) {
        let hashKey = Self.hashKey(key)
        self.elements.append((key: key, value: value))
        self.hashKeys.append(hashKey)
    }

    private static func hashKey(_ key: Key) -> Int {
        var hasher = Hasher()
        hasher.combine(key)
        return hasher.finalize()
    }

    private var elements: [Element]
    private var hashKeys: [Int]
}

// FlatDictionary is Sendable when Key and Value are Sendable
extension FlatDictionary: Sendable where Key: Sendable, Value: Sendable {}
