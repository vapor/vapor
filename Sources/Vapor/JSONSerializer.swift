import Foundation

//
//  Json.swift
//  JsonSerializer
//
//  Created by Fuji Goro on 2014/09/15.
//  Copyright (c) 2014 Fuji Goro. All rights reserved.
//

public enum Json: CustomStringConvertible, CustomDebugStringConvertible, Equatable {
    
    case NullValue
    case BooleanValue(Bool)
    case NumberValue(Double)
    case StringValue(String)
    case ArrayValue([Json])
    case ObjectValue([String:Json])
    
    // MARK: Initialization
    
    public init(_ value: Bool) {
        self = .BooleanValue(value)
    }
    
    public init(_ value: Double) {
        self = .NumberValue(value)
    }
    
    public init(_ value: String) {
        self = .StringValue(value)
    }
    
    public init(_ value: [Json]) {
        self = .ArrayValue(value)
    }
    
    public init(_ value: [String : Json]) {
        self = .ObjectValue(value)
    }
    
    // MARK: From
    
    public static func from(value: Bool) -> Json {
        return .BooleanValue(value)
    }
    
    public static func from(value: Double) -> Json {
        return .NumberValue(value)
    }
    
    public static func from(value: String) -> Json {
        return .StringValue(value)
    }
    
    public static func from(value: [Json]) -> Json {
        return .ArrayValue(value)
    }
    
    public static func from(value: [String : Json]) -> Json {
        return .ObjectValue(value)
    }
}

// MARK: Serialization

extension Json {
    public static func deserialize(source: String) throws -> Json {
        return try JsonDeserializer(source.utf8).deserialize()
    }
    
    public static func deserialize(source: [UInt8]) throws -> Json {
        return try JsonDeserializer(source).deserialize()
    }
    
    public static func deserialize<ByteSequence: CollectionType where ByteSequence.Generator.Element == UInt8>(sequence: ByteSequence) throws -> Json {
        return try JsonDeserializer(sequence).deserialize()
    }
}

extension Json {
    public enum SerializationStyle {
        case Default
        case PrettyPrint
        
        private var serializer: JsonSerializer.Type {
            switch self {
            case .Default:
                return DefaultJsonSerializer.self
            case .PrettyPrint:
                return PrettyJsonSerializer.self
            }
        }
    }
    
    public func serialize(style: SerializationStyle = .Default) -> String {
        return style.serializer.init().serialize(self)
    }
}

// MARK: Convenience

extension Json {
    public var isNull: Bool {
        guard case .NullValue = self else { return false }
        return true
    }
    
    public var boolValue: Bool? {
        if case let .BooleanValue(bool) = self {
            return bool
        } else if let integer = intValue where integer == 1 || integer == 0 {
            // When converting from foundation type `[String : AnyObject]`, something that I see as important,
            // it's not possible to distinguish between 'bool', 'double', and 'int'.
            // Because of this, if we have an integer that is 0 or 1, and a user is requesting a boolean val,
            // it's fairly likely this is their desired result.
            return integer == 1
        } else {
            return nil
        }
    }
    
    public var floatValue: Float? {
        guard let double = doubleValue else { return nil }
        return Float(double)
    }
    
    public var doubleValue: Double? {
        guard case let .NumberValue(double) = self else {
            return nil
        }
        
        return double
    }
    
    public var intValue: Int? {
        guard case let .NumberValue(double) = self where double % 1 == 0 else {
            return nil
        }
        
        return Int(double)
    }
    
    public var uintValue: UInt? {
        guard let intValue = intValue else { return nil }
        return UInt(intValue)
    }
    
    public var stringValue: String? {
        guard case let .StringValue(string) = self else {
            return nil
        }
        
        return string
    }
    
    public var arrayValue: [Json]? {
        guard case let .ArrayValue(array) = self else { return nil }
        return array
    }
    
    public var objectValue: [String : Json]? {
        guard case let .ObjectValue(object) = self else { return nil }
        return object
    }
}

extension Json {
    public subscript(index: Int) -> Json? {
        assert(index >= 0)
        guard let array = arrayValue where index < array.count else { return nil }
        return array[index]
    }
    
    public subscript(key: String) -> Json? {
        get {
            guard let dict = objectValue else { return nil }
            return dict[key]
        }
        set {
            guard let object = objectValue else { fatalError("Unable to set string subscript on non-object type!") }
            var mutableObject = object
            mutableObject[key] = newValue
            self = .from(mutableObject)
        }
    }
}

extension Json {
    public var description: String {
        return serialize(DefaultJsonSerializer())
    }
    
    public var debugDescription: String {
        return serialize(PrettyJsonSerializer())
    }
}

extension Json {
    public func serialize(serializer: JsonSerializer) -> String {
        return serializer.serialize(self)
    }
}


public func ==(lhs: Json, rhs: Json) -> Bool {
    switch lhs {
    case .NullValue:
        return rhs.isNull
    case .BooleanValue(let lhsValue):
        guard let rhsValue = rhs.boolValue else { return false }
        return lhsValue == rhsValue
    case .StringValue(let lhsValue):
        guard let rhsValue = rhs.stringValue else { return false }
        return lhsValue == rhsValue
    case .NumberValue(let lhsValue):
        guard let rhsValue = rhs.doubleValue else { return false }
        return lhsValue == rhsValue
    case .ArrayValue(let lhsValue):
        guard let rhsValue = rhs.arrayValue else { return false }
        return lhsValue == rhsValue
    case .ObjectValue(let lhsValue):
        guard let rhsValue = rhs.objectValue else { return false }
        return lhsValue == rhsValue
    }
}

// MARK: Literal Convertibles

extension Json: NilLiteralConvertible {
    public init(nilLiteral value: Void) {
        self = .NullValue
    }
}

extension Json: BooleanLiteralConvertible {
    public init(booleanLiteral value: BooleanLiteralType) {
        self = .BooleanValue(value)
    }
}

extension Json: IntegerLiteralConvertible {
    public init(integerLiteral value: IntegerLiteralType) {
        self = .NumberValue(Double(value))
    }
}

extension Json: FloatLiteralConvertible {
    public init(floatLiteral value: FloatLiteralType) {
        self = .NumberValue(Double(value))
    }
}

extension Json: StringLiteralConvertible {
    public typealias UnicodeScalarLiteralType = String
    public typealias ExtendedGraphemeClusterLiteralType = String
    
    public init(unicodeScalarLiteral value: UnicodeScalarLiteralType) {
        self = .StringValue(value)
    }
    
    public init(extendedGraphemeClusterLiteral value: ExtendedGraphemeClusterType) {
        self = .StringValue(value)
    }
    
    public init(stringLiteral value: StringLiteralType) {
        self = .StringValue(value)
    }
}

extension Json: ArrayLiteralConvertible {
    public init(arrayLiteral elements: Json...) {
        self = .ArrayValue(elements)
    }
}

extension Json: DictionaryLiteralConvertible {
    public init(dictionaryLiteral elements: (String, Json)...) {
        var object = [String : Json](minimumCapacity: elements.count)
        elements.forEach { key, value in
            object[key] = value
        }
        self = .ObjectValue(object)
    }
}





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
    
    internal required convenience init<ByteSequence: CollectionType where ByteSequence.Generator.Element == UInt8>(_ sequence: ByteSequence) {
        self.init(Array(sequence))
    }
    
    internal required init(_ source: ByteSequence) {
        self.source = source
        self.cur = source.startIndex
        self.end = source.endIndex
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
        skipWhitespaces()
        guard cur != end else {
            throw InsufficientTokenError("unexpected end of tokens", self)
        }
        
        switch currentChar {
        case Char(ascii: "n"):
            return try parseSymbol("null", Json.NullValue)
        case Char(ascii: "t"):
            return try parseSymbol("true", Json.BooleanValue(true))
        case Char(ascii: "f"):
            return try parseSymbol("false", Json.BooleanValue(false))
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
    
    private func parseSymbol(target: StaticString, @autoclosure _ iftrue:  () -> Json) throws -> Json {
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
        
        guard let string = String.fromCString(buffer) else {
            throw InvalidStringError("Unable to parse CString", self)
        }
        
        return .StringValue(string)
    }
    
    private func parseEscapedChar() -> UnicodeScalar? {
        let character = UnicodeScalar(currentChar)
        
        // 'u' indicates unicode
        guard character == "u" else {
            return unescapeMapping[character] ?? character
        }
        
        var length = 0 // 2...8
        var value: UInt32 = 0
        while let d = hexToDigit(nextChar) {
            advance()
            length += 1
            
            guard length <= 8 else { break }
            value <<= 4
            value |= d
        }
        
        guard length >= 2 else { return nil }
        
        // TODO: validate the value
        return UnicodeScalar(value)
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
        
        return .NumberValue(sign * (Double(integer) + fraction) * pow(10, Double(exponent)))
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
            guard case let .StringValue(key) = try deserializeNextValue() else {
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
        
        return .ObjectValue(object)
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
        
        return .ArrayValue(a)
    }
    
    private func expect(target: StaticString) -> Bool {
        guard cur != end else { return false }
        
        if !isIdentifier(target.utf8Start.memory) {
            // when single character
            if target.utf8Start.memory == currentChar {
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
        let endp = p.advancedBy(Int(target.byteSize))
        while p != endp {
            if p.memory != currentChar {
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
    private func isIdentifier(c: Char) -> Bool {
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

extension CollectionType {
    func prefixUntil(@noescape stopCondition: Generator.Element -> Bool) -> Array<Generator.Element> {
        var prefix: [Generator.Element] = []
        for element in self {
            guard !stopCondition(element) else { return prefix }
            prefix.append(element)
        }
        return prefix
    }
}









//
//  JsonSerializer.swift
//  JsonSerializer
//
//  Created by Fuji Goro on 2014/09/18.
//  Copyright (c) 2014年 Fuji Goro. All rights reserved.
//

public protocol JsonSerializer {
    init()
    func serialize(_: Json) -> String
}

internal class DefaultJsonSerializer: JsonSerializer {
    
    required init() {}
    
    internal func serialize(json: Json) -> String {
        switch json {
        case .NullValue:
            return "null"
        case .BooleanValue(let b):
            return b ? "true" : "false"
        case .NumberValue(let n):
            return serializeNumber(n)
        case .StringValue(let s):
            return escapeAsJsonString(s)
        case .ArrayValue(let a):
            return serializeArray(a)
        case .ObjectValue(let o):
            return serializeObject(o)
        }
    }
    
    func serializeNumber(n: Double) -> String {
        if n == Double(Int64(n)) {
            return Int64(n).description
        } else {
            return n.description
        }
    }
    
    func serializeArray(array: [Json]) -> String {
        var string = "["
        string += array
            .map { $0.serialize(self) }
            .joinWithSeparator(",")
        return string + "]"
    }
    
    func serializeObject(object: [String : Json]) -> String {
        var string = "{"
        string += object
            .map { key, val in
                let escapedKey = escapeAsJsonString(key)
                let serializedVal = val.serialize(self)
                return "\(escapedKey):\(serializedVal)"
            }
            .joinWithSeparator(",")
        return string + "}"
    }
    
}

internal class PrettyJsonSerializer: DefaultJsonSerializer {
    private var indentLevel = 0
    
    required init() {
        super.init()
    }
    
    override internal func serializeArray(array: [Json]) -> String {
        indentLevel += 1
        defer {
            indentLevel -= 1
        }
        
        let indentString = indent()
        
        var string = "[\n"
        string += array
            .map { val in
                let serialized = val.serialize(self)
                return indentString + serialized
            }
            .joinWithSeparator(",\n")
        return string + " ]"
    }
    
    override internal func serializeObject(object: [String : Json]) -> String {
        indentLevel += 1
        defer {
            indentLevel -= 1
        }
        
        let indentString = indent()
        
        var string = "{\n"
        string += object
            .map { key, val in
                let escapedKey = escapeAsJsonString(key)
                let serializedValue = val.serialize(self)
                let serializedLine = "\(escapedKey): \(serializedValue)"
                return indentString + serializedLine
            }
            .joinWithSeparator(",\n")
        string += " }"
        
        return string
    }
    
    func indent() -> String {
        return Array(1...indentLevel)
            .map { _ in "  " }
            .joinWithSeparator("")
    }
}







//
//  ParseError.swift
//  JsonSerializer
//
//  Created by Fuji Goro on 2014/09/15.
//  Copyright (c) 2014 Fuji Goro. All rights reserved.
//

protocol Parser {
    var lineNumber: Int { get }
    var columnNumber: Int { get }
}

public class ParseError: ErrorType, CustomStringConvertible {
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
            .joinWithSeparator("")
        return "\"" + mapped + "\""
    }
}

public func escapeAsJsonString(source : String) -> String {
    return source.escapedJsonString
}

func digitToInt(b: UInt8) -> Int? {
    return digitMapping[UnicodeScalar(b)]
}

func hexToDigit(b: UInt8) -> UInt32? {
    return hexMapping[UnicodeScalar(b)]
}

