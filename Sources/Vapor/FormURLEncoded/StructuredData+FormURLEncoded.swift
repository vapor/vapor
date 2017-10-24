import Foundation
import Core
import Node

extension Node {
    /// Queries allow empty values
    /// FormURLEncoded does not
    public init(formURLEncoded data: Bytes, allowEmptyValues: Bool) {
        var urlEncoded: [String: Node] = [:]

        let replacePlus: (Byte) -> (Byte) = { byte in
            guard byte == .plus else { return byte }
            return .space
        }
        
        perKeyLoop: for pair in data.split(separator: .ampersand) {
            var value: Node = .string("")
            var keyData: Bytes

            /// Allow empty subsequences
            /// value= => "value": ""
            /// value => "value": true
            let token = pair.split(
                separator: .equals,
                maxSplits: 1, // max 1, `foo=a=b` should be `"foo": "a=b"`
                omittingEmptySubsequences: !allowEmptyValues
            )
            if token.count == 2 {
                keyData = token[0].map(replacePlus)
                    .makeString()
                    .percentDecoded
                    .makeBytes()
                
                let valueData = token[1].map(replacePlus)
                    .makeString()
                    .percentDecoded
                
                value = .string(valueData)
            } else if allowEmptyValues && token.count == 1 {
                keyData = token[0].map(replacePlus)
                    .makeString()
                    .percentDecoded.makeBytes()
                
                value = .bool(true)
            } else {
                print("Found bad encoded pair \(pair.makeString()) ... continuing")
                continue
            }

            var keyIndicatedArray = false
            var keyIndicatedObject = false
            var subKey = ""

            // check if the key has `key[]` or `key[5]`
            if keyData.contains(.rightSquareBracket) && keyData.contains(.leftSquareBracket) {
                // get the key without the `[]`
                let slices = keyData
                    .split(separator: .leftSquareBracket)
                guard slices.count > 1 else {
                    print("Found bad encoded pair \(pair.makeString()) ... continuing")
                    continue
                }
                
                keyData = slices[0].array
                
                for (n, contents) in slices.dropFirst().enumerated() {
                    let content = contents.array
                    
                    if content[0] == .rightSquareBracket {
                        // Current subsequence indicates an array.
                        guard n == slices.endIndex - 2 else { // subtract 2 because we also ignore element 0
                            print("Array stem must be last in nested encoded key specifier in \(pair.makeString()) ... continuing")
                            continue perKeyLoop
                        }
                        keyIndicatedArray = true
                    } else {
                        // Current subsequence indicates an object.
                        // this can result in both keyIndicatedArray and keyIndicatedObject
                        // being true. That's okay as long as array is checked first below.
                        subKey += (subKey.count > 0 ? "." : "") + contents.dropLast().makeString()
                        keyIndicatedObject = true
                    }
                }
            }

            let key = keyData.makeString()

            if let existing = urlEncoded[key] {
                if keyIndicatedArray {
                    if subKey.count > 0 { // there's a keypath before the array
                        // This is an ugly mess. There must be a better way.
                        var obj = existing
                        if let _ = obj.object {} else { obj = Node.object([:]) }
                        var array: [Node] = []
                        if let orig = obj[subKey]?.array { array = orig }
                        else if let sub = obj[subKey] { array = [sub] }
                        array.append(value)
                        obj[subKey] = Node.array(array)
                        value = obj
                    } else {
                        var array = existing.array ?? [existing]
                        array.append(value)
                        value = .array(array)
                    }
                } else if keyIndicatedObject {
                    var obj = existing // Node is a struct, hence this (effectively) copies
                    if let _ = obj.object {
                    } else {
                        obj = Node.object([:])
                    }
                    obj[subKey] = value // invoke keypath accessor
                    value = obj
                } else {
                    // if we don't have `[]` on this pair, but it was previously assigned
                    // an array, then it is implicit and should be appended.
                    // OR if we found a subsequent value w/ same identifier, it should
                    // become an array
                    var array = existing.array ?? [existing]
                    array.append(value)
                    value = .array(array)
                }
            } else if keyIndicatedArray {
                if subKey.count > 0 {
                    var obj = Node.object([:])
                    obj[subKey] = Node.array([value])
                    value = obj
                } else {
                    value = .array([value])
                }
            } else if keyIndicatedObject {
                var obj = Node.object([:])
                obj[subKey] = value // invoke keypath accessor
                value = obj
            }

            urlEncoded[key] = value

        }
        
        self = .object(urlEncoded)
    }
    
    public func formURLEncoded() throws -> Bytes {
        guard let dict = self.object else { return [] }

        var bytes: [[Byte]] = []

        for (key, val) in dict {
            var subbytes: [Byte] = []

            if let object = val.object {
                subbytes += object.formURLEncoded(forKey: key).makeBytes()
            } else if let array = val.array {
                subbytes += array.formURLEncoded(forKey: key).makeBytes()
            } else {
                subbytes += key.formUrlEscaped().makeBytes()
                subbytes.append(.equals)
                subbytes += val.string.formURLEncodedValue().makeBytes()
            }

            bytes.append(subbytes)
        }

        return bytes.joined(separator: [Byte.ampersand]).array
    }
}

extension Array where Element == Node {
    fileprivate func formURLEncoded(forKey key: String) -> String {
        let key = key.formUrlEscaped()
        let collection = map { val in
            "\(key)%5B%5D=" + val.string.formURLEncodedValue()
        }
        return collection.joined(separator: "&")
    }
}

extension Dictionary where Key == String, Value == Node {
    fileprivate func formURLEncoded(forKey key: String) -> String {
        let key = key.formUrlEscaped()
        let values = map { subKey, value in
            var encoded = key
            encoded += "%5B\(subKey.formUrlEscaped())%5D="
            encoded += value.string.formURLEncodedValue()
            return encoded
        } as [String]

        return values.joined(separator: "&")
    }
}

extension Optional where Wrapped == String {
    fileprivate func formURLEncodedValue() -> String {
        guard let value = self else { return "" }
        return value.formUrlEscaped()
    }
}

/// 
///
/// Copyright (c) 2014-2016 Alamofire Software Foundation (http://alamofire.org/)
///
///     Permission is hereby granted, free of charge, to any person obtaining a copy
///     of this software and associated documentation files (the "Software"), to deal
///     in the Software without restriction, including without limitation the rights
///     to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
///     copies of the Software, and to permit persons to whom the Software is
///     furnished to do so, subject to the following conditions:
///
///     The above copyright notice and this permission notice shall be included in
///     all copies or substantial portions of the Software.
///
///     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
///     IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
///     FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
///     AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
///     LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
///     OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
///     THE SOFTWARE.
///
///
///
/// Returns a percent-escaped string following RFC 3986 for a query string key or value.
///
/// RFC 3986 states that the following characters are "reserved" characters.
///
/// - General Delimiters: ":", "#", "[", "]", "@", "?", "/"
/// - Sub-Delimiters: "!", "$", "&", "'", "(", ")", "*", "+", ",", ";", "="
///
/// In RFC 3986 - Section 3.4, it states that the "?" and "/" characters should not be escaped to allow
/// query strings to include a URL. Therefore, all "reserved" characters with the exception of "?" and "/"
/// should be percent-escaped in the query string.
///
/// - parameter string: The string to be percent-escaped.
///
/// - returns: The percent-escaped string.
/// https://github.com/Alamofire/Alamofire/blob/4.5.0/Source/ParameterEncoding.swift#L195
extension String {
    fileprivate func formUrlEscaped() -> String {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="

        var allowedCharacterSet = CharacterSet.urlQueryAllowed
        allowedCharacterSet.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")

        var escaped = ""

        //==========================================================================================================
        //
        //  Batching is required for escaping due to an internal bug in iOS 8.1 and 8.2. Encoding more than a few
        //  hundred Chinese characters causes various malloc error crashes. To avoid this issue until iOS 8 is no
        //  longer supported, batching MUST be used for encoding. This introduces roughly a 20% overhead. For more
        //  info, please refer to:
        //
        //      - https://github.com/Alamofire/Alamofire/issues/206
        //
        //==========================================================================================================
        if #available(iOS 8.3, *) {
            escaped = self.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) ?? self
        } else {
            let batchSize = 50
            var index = self.startIndex

            while index != self.endIndex {
                let startIndex = index
                let endIndex = self.index(index, offsetBy: batchSize, limitedBy: self.endIndex) ?? self.endIndex

                // need explicit type here to properly infer on Linux
                let range: Range<String.Index> = startIndex..<endIndex

                let substring = self.substring(with: range)

                escaped += substring.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) ?? substring

                index = endIndex
            }
        }

        return escaped
    }

}
