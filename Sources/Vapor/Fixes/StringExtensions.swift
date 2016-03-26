// String.swift
//
// The MIT License (MIT)
//
// Copyright (c) 2015 Zewo
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import libc

#if swift(>=3.0)
    extension String {

    }
#else
    public typealias ErrorProtocol = ErrorType
    
    extension String {
        func lowercased() -> String {
            return self.lowercaseString
        }
    
        func uppercased() -> String {
            return self.uppercaseString
        }
    
        func hasPrefix(str: String) -> Bool {
            let strGen = str.characters.generate()
            let selfGen = self.characters.generate()
            let seq = Zip2Sequence(strGen, selfGen)
            for (lhs, rhs) in seq where lhs != rhs {
                return false
            }
            return true
        }

        func hasSuffix(str: String) -> Bool {
            let strGen = str.characters.reverse().generate()
            let selfGen = self.characters.reverse().generate()
            let seq = Zip2Sequence(strGen, selfGen)
            for (lhs, rhs) in seq where lhs != rhs {
                return false
            }
            return true
        }

    
        func substringToIndex(index: Int) -> String {
            var out = self
            withCString { (bytes) in
                let bytes = UnsafeMutablePointer<Int8>(bytes)
                bytes[index] = 0
                out = String.fromCString( bytes )!
            }
            return out
        }
    }
#endif

extension String {
    
    func rangeOfString(str: String) -> Range<Int>? {
        var start = -1
        withCString { (bytes) in
            str.withCString { (sbytes) in
                start = strstr( bytes, sbytes ) - UnsafeMutablePointer<Int8>( bytes )
            }
        }
        return start < 0 ? nil : start..<start+str.utf8.count
    }
    
    public static func buffer(size size: Int) -> [Int8] {
        #if swift(>=3.0)
            return [Int8](repeating: 0, count: size)
        #else
            return [Int8](count: size, repeatedValue: 0)
        #endif
    }

    public init?(pointer: UnsafePointer<UInt8>, length: Int) {
        let uPointer = UnsafePointer<Int8>(pointer)
        var buffer = String.buffer(size: length + 1)
        strncpy(&buffer, uPointer, length)

        #if swift(>=3.0)
            let cstring = String(validatingUTF8: buffer)
        #else
            let cstring = String.fromCString(buffer)
        #endif
        
        guard let string = cstring else {
            return nil
        }

        self.init(string)
    }

    public func trim(characters: CharacterSet) -> String {
        let string = trim(left: characters)
        return string.trim(right: characters)
    }

    public func trim(left characterSet: CharacterSet) -> String {
        var start = characters.count
        
        #if swift(>=3.0)
            let charactersEnumerated = characters.enumerated()
        #else
            let charactersEnumerated = characters.enumerate()
        #endif

        for (index, character) in charactersEnumerated {
            if !characterSet.contains(character) {
                start = index
                break
            }
        }
        
        #if swift(>=3.0)
            let si = startIndex.advanced(by: start)
        #else
            let si = startIndex.advancedBy(start)
        #endif

        return self[si ..< endIndex]
    }

    public func trim(right characterSet: CharacterSet) -> String {
        var end = characters.count
        
        #if swift(>=3.0)
            let charactersEnumerated = characters.reversed().enumerated()
        #else
            let charactersEnumerated = characters.reverse().enumerate()
        #endif

        for (index, character) in charactersEnumerated {
            if !characterSet.contains(character) {
                end = index
                break
            }
        }
        
        #if swift(>=3.0)
            let si = startIndex.advanced(by: characters.count - end)
        #else
            let si = startIndex.advancedBy(characters.count - end)
        #endif

        return self[startIndex ..< si]
    }

    func split(separator: Character) -> [String] {
        return self.characters.split { $0 == separator }.map(String.init)
    }
    
    func split(maxSplit: Int = Int.max, separator: Character) -> [String] {
        #if swift(>=3.0)
            return self.characters.split(separator: separator, maxSplits: maxSplit, omittingEmptySubsequences: false).map(String.init)
        #else
            return self.characters.split(maxSplit) { $0 == separator }.map(String.init)
        #endif
    }

    public func finish(ending: String) -> String {
        if hasSuffix(ending) {
            return self
        } else {
            return self + ending
        }
    }

    func replace(old: Character, new: Character) -> String {
        var buffer = [Character]()
        self.characters.forEach { buffer.append($0 == old ? new : $0) }
        return String(buffer)
    }
    
    func unquote() -> String {
        var scalars = self.unicodeScalars;
        if scalars.first == "\"" && scalars.last == "\"" && scalars.count >= 2 {
            scalars.removeFirst();
            scalars.removeLast();
            return String(scalars)
        }
        return self
    }
    
    public func trim() -> String {
        return trim(CharacterSet.whitespaceAndNewline)
    }
    
    static func fromUInt8(array: [UInt8]) -> String {
        return String(pointer: array, length: array.count) ?? ""
    }
    
    func removePercentEncoding() -> String {
        let percentEncoded = self

        let spaceCharacter: UInt8 = 32
        let percentCharacter: UInt8 = 37
        let plusCharacter: UInt8 = 43

        var encodedBytes: [UInt8] = [] + percentEncoded.utf8
        var decodedBytes: [UInt8] = []
        var i = 0

        while i < encodedBytes.count {
            let currentCharacter = encodedBytes[i]

            switch currentCharacter {
            case percentCharacter:
                let unicodeA = UnicodeScalar(encodedBytes[i + 1])
                let unicodeB = UnicodeScalar(encodedBytes[i + 2])

                let hexString = "\(unicodeA)\(unicodeB)"



                guard let character = Int(hexString, radix: 16) else {
                    return ""
                }

                decodedBytes.append(UInt8(character))
                i += 3

            case plusCharacter:
                decodedBytes.append(spaceCharacter)
                i += 1

            default:
                decodedBytes.append(currentCharacter)
                i += 1
            }
        }

        var string = ""
        var decoder = UTF8()
        var finished = false
        #if swift(>=3.0)
            var iterator = decodedBytes.makeIterator()
            while !finished {
                let decodingResult = decoder.decode(&iterator)
                switch decodingResult {
                case .scalarValue(let char): string.append(char)
                case .emptyInput: finished = true
                case .error:
                    return ""
                }
            }
        #else
            var iterator = decodedBytes.generate()
            while !finished {
                let decodingResult = decoder.decode(&iterator)
                switch decodingResult {
                case .Result(let char): string.append(char)
                case .EmptyInput: finished = true
                case .Error:
                    return ""
                }
            }
        #endif

        return string
    }
}

public struct CharacterSet: ArrayLiteralConvertible {
    public static var whitespaceAndNewline: CharacterSet {
        return [" ", "\t", "\r", "\n"]
    }

    public static var digits: CharacterSet {
        return ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
    }

    private let characters: Set<Character>
    private let isInverted: Bool

    public var inverted: CharacterSet {
        return CharacterSet(characters: characters, inverted: !isInverted)
    }

    public init(characters: Set<Character>, inverted: Bool = false) {
        self.characters = characters
        self.isInverted = inverted
    }

    public init(arrayLiteral elements: Character...) {
        self.init(characters: Set(elements))
    }

    public func contains(character: Character) -> Bool {
        let contains = characters.contains(character)
        return isInverted ? !contains : contains
    }
}
