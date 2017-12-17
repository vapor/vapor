import Async
import Bits
import Foundation

/// A streaming Redis value parser
internal final class RedisDataParser: Async.Stream, ConnectionContext {
    /// See InputStream.Input
    typealias Input = ByteBuffer
    
    /// See OutputStream.RedisData
    typealias Output = RedisData
    
    /// The in-progress parsing values
    ///
    /// An array, for when a single TCP message has > 1 entity
    var parsingValues: [PartialRedisData]
    
    /// The upstream providing byte buffers
    private var upstream: ConnectionContext?
    
    /// Use a basic output stream to implement server output stream.
    private var downstream: AnyInputStream<Output>?

    /// Remaining downstream demand
    private var downstreamDemand: UInt

    /// Current state
    private var state: RedisDataParserState
    
    /// Creates a new ValueParser
    init() {
        downstreamDemand = 0
        self.parsingValues = []
        state = .ready
    }

    /// InputStream.onInput
    func input(_ event: InputEvent<ByteBuffer>) {
        switch event {
        case .close: downstream?.close()
        case .connect(let upstream):
            self.upstream = upstream
        case .error(let error): downstream?.error(error)
        case .next(let input):
            state = .ready
            do {
                try parseBuffer(input)
            } catch {
                self.parsingValues = []
                downstream?.error(error)
            }
        }
        
        update()
    }

    func connection(_ event: ConnectionEvent) {
        switch event {
        case .request(let count):
            /// downstream has requested output
            downstreamDemand += count
        case .cancel:
            /// FIXME: handle
            downstreamDemand = 0
        }
        
        update()
    }
    
    /// Flushes parsed values
    private func flush() {
        while parsingValues.count > 0, downstreamDemand > 0, let value = parsingValues.first {
            guard case .parsed(let data) = value else {
                return
            }
            
            parsingValues.removeFirst()
            
            downstream?.next(data)
        }
    }

    /// updates the parser's state
    private func update() {
        /// if demand is 0, we don't want to do anything
        guard downstreamDemand > 0 else {
            return
        }
        
        flush()

        switch state {
        case .awaitingUpstream:
            /// we are waiting for upstream, nothing to be done
            break
        case .ready:
            /// ask upstream for some data
            state = .awaitingUpstream
            upstream?.request()
        }
    }

    func output<S>(to inputStream: S) where S: Async.InputStream, Output == S.Input {
        downstream = AnyInputStream(inputStream)
        inputStream.connect(to: self)
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
    fileprivate func parseBuffer(_ input: ByteBuffer) throws {
        // flush first, so the order of information stays correct
        flush()
        
        var offset = 0
        var success: Bool
        var value: PartialRedisData
        
        // Continues parsing while there are still pending requests
        repeat {
            if self.parsingValues.count == 0 {
                value = .notYetParsed
            } else {
                value = self.parsingValues.removeLast()
            }
            
            success = try continueParsing(partial: &value, from: input, at: &offset)
            self.parsingValues.append(value)
            
            flush()
        } while offset < input.count && success
    }
}

/// Various states the parser stream can be in
enum RedisDataParserState {
    /// normal state
    case ready
    
    /// waiting for data from upstream
    case awaitingUpstream
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
