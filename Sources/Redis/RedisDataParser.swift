import Async
import Bits
import Foundation

/// Various states the parser stream can be in
enum ProtocolParserState {
    /// normal state
    case ready
    
    /// waiting for data from upstream
    case awaitingUpstream
}

/// A streaming Redis value parser
internal final class RedisDataParser: Async.Stream, ConnectionContext {
    /// See InputStream.Input
    typealias Input = ByteBuffer
    
    /// See OutputStream.RedisData
    typealias Output = RedisData
    
    /// The in-progress parsing value
    var processing: PartialRedisData?
    
    /// The upstream providing byte buffers
    var upstream: ConnectionContext?
    
    /// Use a basic output stream to implement server output stream.
    var downstream: AnyInputStream<Output>?

    /// Remaining downstream demand
    var downstreamDemand: UInt

    /// Current state
    var state: ProtocolParserState
    
    var parsing: ByteBuffer? {
        didSet {
            parsedBytes = 0
        }
    }
    
    var parsedBytes: Int = 0
    
    /// Creates a new ValueParser
    init() {
        downstreamDemand = 0
        state = .ready
    }
    
    func input(_ event: InputEvent<ByteBuffer>) {
        switch event {
        case .close:
            downstream?.close()
        case .connect(let upstream):
            self.upstream = upstream
        case .error(let error):
            downstream?.error(error)
        case .next(let next):
            do {
                self.parsing = next
                
                try transform()
            } catch {
                self.downstream?.error(error)
            }
        }
    }
    
    func output<S>(to inputStream: S) where S : Async.InputStream, Output == S.Input {
        self.downstream = AnyInputStream(inputStream)
        inputStream.connect(to: self)
    }
    
    func connection(_ event: ConnectionEvent) {
        switch event {
        case .cancel:
            self.downstreamDemand = 0
        case .request(let demand):
            self.downstreamDemand += demand
        }
        
        guard downstreamDemand > 0, parsing != nil else {
            upstream?.request()
            return
        }
        
        do {
            try transform()
        } catch {
            self.downstream?.error(error)
        }
    }
    
    /// Parses a basic String (no \r\n's) `String` starting at the current position
    fileprivate func simpleString(from input: ByteBuffer, at offset: inout Int) -> String? {
        var carriageReturnFound = false
        var base = offset
        
        // Loops until the carriagereturn
        detectionLoop: while offset < input.count {
            offset += 1
            
            if input[offset] == .carriageReturn {
                carriageReturnFound = true
                break detectionLoop
            }
        }
        
        // Expects a carriage return
        guard carriageReturnFound else {
            return nil
        }
        
        // newline
        guard offset < input.count, input[offset + 1] == .newLine else {
            return nil
        }
        
        // past clrf
        defer { offset += 2 }
        
        // Returns a String initialized with this data
        return String(bytes: input[base..<offset], encoding: .utf8)
    }
    
    /// Parses an integer associated with the token at the provided position
    fileprivate func integer(from input: ByteBuffer, at offset: inout Int) throws -> Int? {
        // Parses a string
        guard let string = simpleString(from: input, at: &offset) else {
            return nil
        }
        
        // Instantiate the integer
        guard let number = Int(string) else {
            throw RedisError(.parsingError)
        }
        
        return number
    }
    
    /// Parses the value for the provided Token at the current position
    ///
    /// - throws: On an unexpected result
    /// - returns: The value (and if it's completely parsed) as a tuple, or `nil` if more data is needed to continue
    fileprivate func parseToken(_ token: UInt8, from input: ByteBuffer, at position: inout Int) throws -> PartialRedisData {
        switch token {
        case .plus:
            // Simple string
            guard let string = simpleString(from: input, at: &position) else {
                throw RedisError(.parsingError)
            }
            
            return .parsed(.basicString(string))
        case .hyphen:
            // Error
            guard let string = simpleString(from: input, at: &position) else {
                throw RedisError(.parsingError)
            }
            
            return .parsed(.error(RedisError(.serverSide(string))))
        case .colon:
            // Integer
            guard let number = try integer(from: input, at: &position) else {
                throw RedisError(.parsingError)
            }
            
            return .parsed(.integer(number))
        case .dollar:
            // Bulk strings start with their length
            guard let size = try integer(from: input, at: &position) else {
                throw RedisError(.parsingError)
            }
            
            // Negative bulk strings are `null`
            if size < 0 {
                return .parsed(.null)
            }
            
            // Parse the following length in data
            guard
                size > -1,
                size < input.distance(from: position, to: input.endIndex)
            else {
                throw RedisError(.parsingError)
            }
            
            let endPosition = input.index(position, offsetBy: size)
            
            defer {
                position = input.index(position, offsetBy: size + 2)
            }
            
            return .parsed(.bulkString(Data(input[position..<endPosition])))
        case .asterisk:
            // Arrays start with their element count
            guard let size = try integer(from: input, at: &position) else {
                throw RedisError(.parsingError)
            }
            
            guard size >= 0 else {
                throw RedisError(.parsingError)
            }
            
            var array = [PartialRedisData](repeating: .notYetParsed, count: size)
            
            // Parse all elements
            for index in 0..<size {
                guard input.count - position >= 1 else {
                    return .parsing(array)
                }
                
                let token = input[position]
                position += 1
                
                // Parse the individual nested element
                let result = try parseToken(token, from: input, at: &position)
                
                array[index] = result
            }
            
            let values = try array.map { value -> RedisData in
                guard case .parsed(let value) = value else {
                    throw RedisError(.parsingError)
                }
                
                return value
            }
            
            // All elements have been parsed, return the complete array
            return .parsed(.array(values))
        default:
            throw RedisError(.invalidTypeToken)
        }
    }
    
    fileprivate func continueParsing(partial value: inout PartialRedisData, from input: ByteBuffer, at offset: inout Int) throws -> Bool {
        // Parses every `notyetParsed`
        switch value {
        case .parsed(_):
            return true
        case .notYetParsed:
            // need 1 byte for the token
            guard input.count - offset >= 1 else {
                return false
            }
            
            let token = input[offset]
            offset += 1
            
            value = try parseToken(token, from: input, at: &offset)
            
            if case .parsed(_) = value {
                return true
            }
        case .parsing(var values):
            for i in 0..<values.count {
                guard try continueParsing(partial: &values[i], from: input, at: &offset) else {
                    value = .parsing(values)
                    return false
                }
            }
            
            let values = try values.map { value -> RedisData in
                guard case .parsed(let value) = value else {
                    throw RedisError(.parsingError)
                }
                
                return value
            }
            
            value = .parsed(.array(values))
            return true
        }
        
        return false
    }
    
    /// Continues parsing the `Data` buffer
    func transform() throws {
        guard downstreamDemand > 0 else {
            return
        }
        
        guard let parsing = parsing else {
            upstream?.request()
            return
        }
        
        var value: PartialRedisData
        
        // Continues parsing while there are still pending requests
        repeat {
            if let processing = self.processing {
                value = processing
            } else {
                value = .notYetParsed
            }
            
            if try continueParsing(partial: &value, from: parsing, at: &parsedBytes) {
                guard case .parsed(let value) = value else {
                    throw RedisError(.parsingError)
                }
                
                self.processing = nil
                flush(value)
            } else {
                self.processing = value
            }
        } while parsedBytes < parsing.count && downstreamDemand > 0
        
        upstream?.request()
    }
    
    private func flush(_ data: RedisData) {
        self.downstreamDemand -= 1
        self.downstream?.next(data)
    }
}

/// A parsing-in-progress Redis value
indirect enum PartialRedisData {
    /// Placeholder for values in arrays
    case notYetParsed
    
    /// An array that's being parsed
    case parsing([PartialRedisData])
    
    /// A correctly parsed value
    case parsed(RedisData)
}
