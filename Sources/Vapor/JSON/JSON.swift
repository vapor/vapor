import JSON

public enum Json {
    case null
    case bool(Bool)
    case double(Double)
    case string(String)
    case array([Json])
    case object([String: Json])

    public init(_ value: JSON) {
        switch value {
        case .nullValue:
            self = .null
        case .booleanValue(let bool):
            self = .bool(bool)
        case .numberValue(let number):
            self = .double(number)
        case .stringValue(let string):
            self = .string(string)
        case .objectValue(let object):
            var mapped: [String: Json] = [:]
            object.forEach { (key, value) in
                mapped[key] = Json(value)
            }
            self = .object(mapped)
        case .arrayValue(let array):
            let mapped: [Json] = array.map { item in
                return Json(item)
            }

            self = .array(mapped)
        }
    }

    public init(_ value: Bool) {
        self = .bool(value)
    }

    public init(_ value: Double) {
        self = .double(value)
    }

    public init(_ value: Int) {
        self = .double(Double(value))
    }

    public init(_ value: String) {
        self = .string(value)
    }

    public init(_ value: [JsonRepresentable]) {
        let array: [Json] = value.map { item in
            return item.makeJson()
        }
        self = .array(array)
    }

    public init(_ value: [String: JsonRepresentable]) {
        var object: [String: Json] = [:]

        value.forEach { (key, item) in
            object[key] = item.makeJson()
        }

        self = .object(object)
    }

    public init(_ value: Data) throws {
        let json = try JSONParser().parse(data: value)
        self.init(json)
    }

    public var data: Data {
        return JSONSerializer().serialize(json: makeZewoJson())
    }

    private func makeZewoJson() -> JSON {
        switch self {
        case .null:
            return .nullValue
        case .bool(let bool):
            return .booleanValue(bool)
        case .double(let double):
            return .numberValue(double)
        case .string(let string):
            return .stringValue(string)
        case .object(let object):
            var mapped: [String: JSON] = [:]
            object.forEach { (key, value) in
                mapped[key] = value.makeZewoJson()
            }

            return .objectValue(mapped)
        case .array(let array):
            let mapped: [JSON] = array.map { item in
                return item.makeZewoJson()
            }

            return .arrayValue(mapped)
        }
    }

    public subscript(key: String) -> Node? {
        switch self {
        case .object(let object):
            return object[key]
        default:
            return nil
        }
    }

    public subscript(index: Int) -> Node? {
        switch self {
        case .array(let array):
            return array[index]
        default:
            return nil
        }
    }

    mutating func merge(with otherJson: Json) {
        switch self {
        case .object(let object):
            guard case let .object(otherObject) = otherJson else {
                self = otherJson
                return
            }

            var merged = object

            for (key, value) in otherObject {
                if let original = object[key] {
                    var newValue = original
                    newValue.merge(with: value)
                    merged[key] = newValue
                } else {
                    merged[key] = value
                }
            }

            self = .object(merged)
        case .array(let array):
            guard case let .array(otherArray) = otherJson else {
                self = otherJson
                return
            }

            self = .array(array + otherArray)
        default:
            self = otherJson
        }
    }
}

extension Json {
    static func deserialize(_ string: String) throws -> Json {
        return try JsonDeserializer(string.utf8).deserialize()
    }
}

public protocol JsonRepresentable: ResponseRepresentable {
    func makeJson() -> Json
}


extension JsonRepresentable {
    ///Allows any JsonRepresentable to be returned through closures
    public func makeResponse() -> Response {
        return makeJson().makeResponse()
    }
}

extension JSON: JsonRepresentable {
    public func makeJson() -> Json {
        return Json(self)
    }
}

extension String: JsonRepresentable {
    public func makeJson() -> Json {
        return Json(self)
    }
}

extension Int: JsonRepresentable {
    public func makeJson() -> Json {
        return Json(self)
    }
}

extension Double: JsonRepresentable {
    public func makeJson() -> Json {
        return Json(self)
    }
}

extension Bool: JsonRepresentable {
    public func makeJson() -> Json {
        return Json(self)
    }
}

extension Json: CustomStringConvertible {
    public var description: String {
        return makeZewoJson().description
    }
}

extension Json: ResponseRepresentable {
    public func makeResponse() -> Response {
        return Response(status: .ok, json: self)
    }
}

extension Json: Node {
    public var isNull: Bool {
        switch self {
        case .null:
            return true
        default:
            return false
        }
    }

    public var bool: Bool? {
        switch self {
        case .bool(let bool):
            return bool
        default:
            return nil
        }
    }

    public var int: Int? {
        switch self {
        case .double(let double) where double % 1 == 0:
            return Int(double)
        default:
            return nil
        }
    }

    public var uint: UInt? {
        guard let int = self.int where int >= 0 else {
            return nil
        }
        return UInt(int)
    }

    public var float: Float? {
        switch self {
        case .double(let double):
            return Float(double)
        default:
            return nil
        }
    }

    public var double: Double? {
        switch self {
        case .double(let double):
            return Double(double)
        default:
            return nil
        }
    }

    public var string: String? {
        switch self {
        case .string(let string):
            return string
        default:
            return nil
        }
    }

    public var array: [Node]? {
        switch self {
        case .array(let array):
            return array.map { item in
                return item
            }
        default:
            return nil
        }
    }

    public var object: [String : Node]? {
        switch self {
        case .object(let object):
            var dict: [String : Node] = [:]

            object.forEach { (key, val) in
                dict[key] = val
            }

            return dict
        default:
            return nil
        }
    }

    public var json: Json? {
        return self
    }
}

// MARK: Parser Error

protocol Parser {
    var lineNumber: Int { get }
    var columnNumber: Int { get }
}

public class ParseError: ErrorProtocol, CustomStringConvertible {
    public let reason: String
    let parser: Parser

    public var lineNumber: Int {
        return parser.lineNumber
    }
    public var columnNumber: Int {
        return parser.columnNumber
    }

    public var description: String {
        return "\(Mirror(reflecting: self))[\(lineNumber):\(columnNumber)]: \(reason)"
    }

    init(_ reason: String, _ parser: Parser) {
        self.reason = reason
        self.parser = parser
    }
}

public class UnexpectedTokenError: ParseError { }

public class InsufficientTokenError: ParseError { }

public class ExtraTokenError: ParseError { }

public class NonStringKeyError: ParseError { }

public class InvalidStringError: ParseError { }

public class InvalidNumberError: ParseError { }

// MARK: Deserializer

//
//  JsonSerializer.swift
//  JsonSerializer
//
//  Created by Fuji Goro on 2014/09/11.
//  Copyright (c) 2014 Fuji Goro. All rights reserved.
//  License: The MIT License
//

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

internal final class JsonDeserializer: Parser {
    internal  typealias ByteSequence = [UInt8]
    internal  typealias Char = UInt8

    // MARK: Public Readable

    internal private(set) var lineNumber = 1
    internal private(set) var columnNumber = 1

    // MARK: Source

    private let source: [UInt8]

    // MARK: State

    private var cur: Int
    private let end: Int

    // MARK: Accessors

    private var currentChar: Char {
        return source[cur]
    }

    private var nextChar: Char {
        return source[cur.successor()]
    }

    private var currentSymbol: Character {
        return Character(UnicodeScalar(currentChar))
    }

    // MARK: Initializer

    internal required convenience init<ByteSequence: Collection where ByteSequence.Iterator.Element == UInt8>(_ sequence: ByteSequence) {
        self.init(Array(sequence))
    }

    internal required init(_ source: ByteSequence) {
        self.source = source
        self.cur = source.startIndex
        print("start: \(self.cur)")
        self.end = source.endIndex
        print("end: \(self.end)")
    }

    // MARK: Serialize

    internal func deserialize() throws -> Json {
        let json = try deserializeNextValue()
        skipWhitespaces()

        guard cur == end else {
            throw ExtraTokenError("extra tokens found", self)
        }

        return json
    }


    private func deserializeNextValue() throws -> Json {
        let next = try _deserializeNextValue()
        print("Next value serialized: \(next)")
        return next
    }


    private func _deserializeNextValue() throws -> Json {
        skipWhitespaces()
        guard cur != end else {
            throw InsufficientTokenError("unexpected end of tokens", self)
        }

        switch currentChar {
        case Char(ascii: "n"):
            return try parseSymbol("null", Json.null)
        case Char(ascii: "t"):
            return try parseSymbol("true", Json.bool(true))
        case Char(ascii: "f"):
            return try parseSymbol("false", Json.bool(false))
        case Char(ascii: "-"), Char(ascii: "0") ... Char(ascii: "9"):
            return try parseNumber()
        case Char(ascii: "\""):
            return try parseString()
        case Char(ascii: "{"):
            return try parseObject()
        case Char(ascii: "["):
            return try parseArray()
        case let c:
            throw UnexpectedTokenError("unexpected token: \(c)", self)
        }
    }

    private func parseSymbol(_ target: StaticString, @autoclosure _ iftrue:  () -> Json) throws -> Json {
        guard expect(target) else {
            throw UnexpectedTokenError("expected \"\(target)\" but \(currentSymbol)", self)
        }

        return iftrue()
    }

    private func parseString() throws -> Json {
        assert(currentChar == Char(ascii: "\""), "points a double quote")
        advance()

        var buffer = [CChar]()

        while cur != end && currentChar != Char(ascii: "\"") {
            switch currentChar {
            case Char(ascii: "\\"):
                advance()

                guard cur != end else {
                    throw InvalidStringError("unexpected end of a string literal", self)
                }

                guard let escapedChar = parseEscapedChar() else {
                    throw InvalidStringError("invalid escape sequence", self)
                }

                String(escapedChar).utf8.forEach {
                    buffer.append(CChar(bitPattern: $0))
                }
            default:
                buffer.append(CChar(bitPattern: currentChar))
            }

            advance()
        }

        guard expect("\"") else {
            throw InvalidStringError("missing double quote", self)
        }

        buffer.append(0) // trailing nul

        guard let string = String(validatingUTF8: buffer) else {
            throw InvalidStringError("Unable to parse CString", self)
        }

        return .string(string)
    }

    private func parseEscapedChar() -> UnicodeScalar? {
        let character = UnicodeScalar(currentChar)

        // 'u' indicates unicode
        guard character == "u" else {
            return unescapeMapping[character] ?? character
        }

        guard let surrogateValue = parseEscapedUnicodeSurrogate() else { return nil }

        // two consecutive \u#### sequences represent 32 bit unicode characters
        if nextChar == Char(ascii: "\\") && source[cur.advanced(by: 2)] == Char(ascii: "u") {
            advance(); advance()
            guard let surrogatePairValue = parseEscapedUnicodeSurrogate() else { return nil }

            return UnicodeScalar(surrogateValue << 16 | surrogatePairValue)
        }

        return UnicodeScalar(surrogateValue)
    }
    private func parseEscapedUnicodeSurrogate() -> UInt32? {
        let requiredLength = 4

        var length = 0
        var value: UInt32 = 0
        while let d = hexToDigit(nextChar) where length < requiredLength {
            advance()
            length += 1

            value <<= 4
            value |= d
        }

        guard length == requiredLength else { return nil }
        return value
    }

    // number = [ minus ] int [ frac ] [ exp ]
    private func parseNumber() throws -> Json {
        let sign = expect("-") ? -1.0 : 1.0

        var integer: Int64 = 0
        switch currentChar {
        case Char(ascii: "0"):
            advance()
        case Char(ascii: "1") ... Char(ascii: "9"):
            while let value = digitToInt(currentChar) where cur != end {
                integer = (integer * 10) + Int64(value)
                advance()
            }
        default:
            throw InvalidNumberError("invalid token in number", self)
        }

        var fraction: Double = 0.0
        if expect(".") {
            var factor = 0.1
            var fractionLength = 0

            while let value = digitToInt(currentChar) where cur != end {
                fraction += (Double(value) * factor)
                factor /= 10
                fractionLength += 1

                advance()
            }

            guard fractionLength != 0 else {
                throw InvalidNumberError("insufficient fraction part in number", self)
            }
        }

        var exponent: Int64 = 0
        if expect("e") || expect("E") {
            var expSign: Int64 = 1
            if expect("-") {
                expSign = -1
            } else if expect("+") {
                // do nothing
            }

            exponent = 0

            var exponentLength = 0
            while let value = digitToInt(currentChar) where cur != end {
                exponent = (exponent * 10) + Int64(value)
                exponentLength += 1
                advance()
            }

            guard exponentLength != 0 else {
                throw InvalidNumberError("insufficient exponent part in number", self)
            }

            exponent *= expSign
        }

        return .double(sign * (Double(integer) + fraction) * pow(10, Double(exponent)))
    }

    private func parseObject() throws -> Json {
        return try getObject()
    }

    /**
     There is a bug in the compiler which makes this function necessary to be called from parseObject
     */
    private func getObject() throws -> Json {
        assert(currentChar == Char(ascii: "{"), "points \"{\"")
        advance()
        skipWhitespaces()

        var object = [String:Json]()

        while cur != end && !expect("}") {
            guard case let .string(key) = try deserializeNextValue() else {
                throw NonStringKeyError("unexpected value for object key", self)
            }

            skipWhitespaces()
            guard expect(":") else {
                throw UnexpectedTokenError("missing colon (:)", self)
            }
            skipWhitespaces()

            let value = try deserializeNextValue()
            object[key] = value

            skipWhitespaces()

            guard !expect("}") else {
                break
            }

            guard expect(",") else {
                throw UnexpectedTokenError("missing comma (,)", self)
            }
        }

        return .object(object)
    }

    private func parseArray() throws -> Json {
        assert(currentChar == Char(ascii: "["), "points \"[\"")
        advance()
        skipWhitespaces()

        var a = Array<Json>()

        LOOP: while cur != end && !expect("]") {
            let json = try deserializeNextValue()
            skipWhitespaces()

            a.append(json)

            if expect(",") {
                continue
            } else if expect("]") {
                break LOOP
            } else {
                throw UnexpectedTokenError("missing comma (,) (token: \(currentSymbol))", self)
            }

        }

        return .array(a)
    }

    private func expect(_ target: StaticString) -> Bool {
        guard cur != end else { return false }

        if !isIdentifier(target.utf8Start.pointee) {
            // when single character
            if target.utf8Start.pointee == currentChar {
                advance()
                return true
            } else {
                return false
            }
        }

        let start = cur
        let l = lineNumber
        let c = columnNumber

        var p = target.utf8Start
        let endp = p.advanced(by: Int(target.utf8CodeUnitCount))
        while p != endp {
            if p.pointee != currentChar {
                cur = start // unread
                lineNumber = l
                columnNumber = c
                return false
            }

            p += 1
            advance()
        }

        return true
    }

    // only "true", "false", "null" are identifiers
    private func isIdentifier(_ c: Char) -> Bool {
        switch c {
        case Char(ascii: "a") ... Char(ascii: "z"):
            return true
        default:
            return false
        }
    }

    private func advance() {
        assert(cur != end, "out of range")
        cur += 1
        guard cur != end else { return }

        switch currentChar {
        case Char(ascii: "\n"):
            lineNumber += 1
            columnNumber = 1
        default:
            columnNumber += 1
        }
    }

    private func skipWhitespaces() {
        while cur != end && currentChar.isWhitespace {
            advance()
        }
    }
}

extension JsonDeserializer.Char {
    var isWhitespace: Bool {
        let type = self.dynamicType
        switch self {
        case type.init(ascii: " "), type.init(ascii: "\t"), type.init(ascii: "\r"), type.init(ascii: "\n"):
            return true
        default:
            return false
        }
    }
}

extension Collection {
    func prefixUntil(@noescape stopCondition: Generator.Element -> Bool) -> Array<Generator.Element> {
        var prefix: [Generator.Element] = []
        for element in self {
            guard !stopCondition(element) else { return prefix }
            prefix.append(element)
        }
        return prefix
    }
}

// MARK: String Utils

//
//  StringUtils.swift
//  JsonSerializer
//
//  Created by Fuji Goro on 2014/09/15.
//  Copyright (c) 2014 Fuji Goro. All rights reserved.
//

let unescapeMapping: [UnicodeScalar: UnicodeScalar] = [
                                                          "t": "\t",
                                                          "r": "\r",
                                                          "n": "\n",
]

let escapeMapping: [Character : String] = [
                                              "\r": "\\r",
                                              "\n": "\\n",
                                              "\t": "\\t",
                                              "\\": "\\\\",
                                              "\"": "\\\"",

                                              "\u{2028}": "\\u2028", // LINE SEPARATOR
    "\u{2029}": "\\u2029", // PARAGRAPH SEPARATOR

    // XXX: countElements("\r\n") is 1 in Swift 1.0
    "\r\n": "\\r\\n",
]

let hexMapping: [UnicodeScalar : UInt32] = [
                                               "0": 0x0,
                                               "1": 0x1,
                                               "2": 0x2,
                                               "3": 0x3,
                                               "4": 0x4,
                                               "5": 0x5,
                                               "6": 0x6,
                                               "7": 0x7,
                                               "8": 0x8,
                                               "9": 0x9,
                                               "a": 0xA, "A": 0xA,
                                               "b": 0xB, "B": 0xB,
                                               "c": 0xC, "C": 0xC,
                                               "d": 0xD, "D": 0xD,
                                               "e": 0xE, "E": 0xE,
                                               "f": 0xF, "F": 0xF,
]

let digitMapping: [UnicodeScalar:Int] = [
                                            "0": 0,
                                            "1": 1,
                                            "2": 2,
                                            "3": 3,
                                            "4": 4,
                                            "5": 5,
                                            "6": 6,
                                            "7": 7,
                                            "8": 8,
                                            "9": 9,
]

extension String {
    public var escapedJsonString: String {
        let mapped = characters
            .map { escapeMapping[$0] ?? String($0) }
            .joined(separator: "")
        return "\"" + mapped + "\""
    }
}

public func escapeAsJsonString(source : String) -> String {
    return source.escapedJsonString
}

func digitToInt(_ b: UInt8) -> Int? {
    return digitMapping[UnicodeScalar(b)]
}

func hexToDigit(_ b: UInt8) -> UInt32? {
    return hexMapping[UnicodeScalar(b)]
}
