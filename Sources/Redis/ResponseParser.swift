import Async
import Bits
import Foundation

/// A streaming Redis value parser
final class ValueParser: Async.InputStream {
    /// See `InputStream.Input`
    typealias Input = ByteBuffer
    
    /// See `BaseStream.errorStream`
    var errorStream: BaseStream.ErrorHandler?
    
    /// A set of promises awaiting a response
    var responseQueue = [Promise<_RedisValue>]()
    
    /// The currently accumulated data from the socket
    var responseBuffer = Data()
    
    /// The in-progress parsing value
    var parsingValue: _RedisValue?
    
    /// The maximum size of a response RedisValue
    var maximumResponseSize = 10_000_000
    
    /// Creates a new ValueParser
    init() {}
    
    /// Accepts input binary and processes it to a RedisValue
    func inputStream(_ input: ByteBuffer) {
        responseBuffer.append(contentsOf: Data(input))
        
        do {
            try parseBuffer()
        } catch {
            self.parsingValue = nil
            errorStream?(error)
        }
    }
    
    /// Parses a basic String (no \r\n's) `String` starting at the current position
    fileprivate func simpleString(from position: inout Int) -> String? {
        var offset = 0
        var carriageReturnFound = false
        
        // Loops until the carriagereturn
        detectionLoop: for character in responseBuffer[position...] {
            offset += 1
            
            if character == .carriageReturn {
                carriageReturnFound = true
                break detectionLoop
            }
        }
        
        // Expects a carriage return
        guard carriageReturnFound else {
            return nil
        }
        
        // The last index must be a newLine
        let endIndex = responseBuffer.index(position, offsetBy: offset)
        
        guard
            endIndex < responseBuffer.endIndex,
            responseBuffer[endIndex] == .newLine
        else {
            return nil
        }
        
        defer {
            // Updates the position with a new value
            position = responseBuffer.index(position, offsetBy: offset + 1)
        }
        
        // Returns a String initialized with this data
        return String(bytes: responseBuffer[position..<endIndex], encoding: .utf8)
    }
    
    /// Parses an integer associated with the token at the provided position
    fileprivate func integer(from position: inout Int) throws -> Int? {
        // Parses a string
        guard let string = simpleString(from: &position) else {
            return nil
        }
        
        // Skip past the token and until before the carriage return
        let integerIndex = string.index(after: string.startIndex)
        let integerEnd = string.index(string.endIndex, offsetBy: -1)
        
        // Instantiate the integer
        guard
            string.count > 1,
            let number = Int(string[integerIndex..<integerEnd])
        else {
            throw ClientError.parsingError
        }
        
        return number
    }
    
    /// Parses the value for the provided Token at the current position
    ///
    /// - throws: On an unexpected result
    /// - returns: The value (and if it's completely parsed) as a tuple, or `nil` if more data is needed to continue
    fileprivate func parseToken(_ token: Character, at position: inout Int) throws -> (result: _RedisValue, complete: Bool)? {
        switch token {
        case "+":
            // Simple string
            guard let string = simpleString(from: &position) else {
                return nil
            }
            
            return (.parsed(.basicString(string)), true)
        case "-":
            // Error
            guard let string = simpleString(from: &position) else {
                return nil
            }
            
            return (.parsed(.error(RedisError(string: string))), true)
        case ":":
            // Integer
            guard let number = try integer(from: &position) else {
                return nil
            }
            
            return (.parsed(.integer(number)), true)
        case "$":
            // Bulk strings start with their length
            guard let size = try integer(from: &position) else {
                return nil
            }
            
            // Parse the following length in data
            guard
                size >= -1,
                size < responseBuffer.distance(from: position, to: responseBuffer.endIndex)
            else {
                throw ClientError.parsingError
            }
            
            let endPosition = responseBuffer.index(position, offsetBy: size)
            
            defer {
                position = responseBuffer.index(position, offsetBy: size + 2)
            }
            
            return (.parsed(.bulkString(Data(responseBuffer[position..<endPosition]))), true)
        case "*":
            // Arrays start with their element count
            guard let size = try integer(from: &position) else {
                return nil
            }
            
            guard size >= 0 else {
                throw ClientError.parsingError
            }
            
            var array = [_RedisValue](repeating: .notYetParsed, count: size)
            
            // Parse all elements
            for index in 0..<size {
                guard remaining(1, from: position) else {
                    return (.parsing(array), false)
                }
                
                let oldPosition = position
                
                // Parse the individual nested element
                guard
                    let (result, complete) = try parseToken(Character(Unicode.Scalar(responseBuffer[position])), at: &position),
                    complete
                else {
                    position = oldPosition
                    return (.parsing(array), false)
                }
                
                array[index] = result
            }
            
            // All elements have been parsed, return the complete array
            return (.parsed(.array(try array.map { value in
                guard case .parsed(let value) = value else {
                    throw ClientError.parsingError
                }
                
                return value
            })), true)
        default:
            throw ClientError.invalidTypeToken
        }
    }
    
    /// Returns `true` if the requested remaining count is available from this position
    fileprivate func remaining(_ n: Int, from position: Int) -> Bool {
        return responseBuffer.distance(from: position, to: responseBuffer.endIndex) > 1
    }
    
    /// Helper that flushes the value into the first response
    fileprivate func flush(_ result: _RedisValue) {
        assert(responseQueue.count > 0, "ResponseQueue received a response and wasn't checked")
        
        let completion = responseQueue.removeFirst()
        
        completion.complete(result)
        parsingValue = nil
    }
    
    /// Continues parsing the `Data` buffer
    fileprivate func parseBuffer() throws {
        // If not enough characters are available, it's not even worth trying.
        guard responseBuffer.count > 2 else {
            return
        }
        
        // Continues parsing while there are still pending requests
        while responseQueue.count > 0 {
            // Continue parsing if a value is partially parsed
            if let parsingValue = parsingValue {
                // The only half-parsed values can be arrays
                guard case .parsing(var values) = parsingValue else {
                    throw ClientError.parsingError
                }
                
                // Loops over all elements
                for i in 0..<values.count {
                    // Parses every `notyetParsed`
                    guard case .notYetParsed = values[i] else {
                        continue
                    }
                    
                    // Fetch the token
                    var index = responseBuffer.startIndex
                    
                    guard remaining(1, from: index) else {
                        return
                    }
                    
                    // Parses the value associated with the token
                    guard
                        let (result, complete) = try parseToken(Character(Unicode.Scalar(responseBuffer[index])), at: &index),
                        complete
                    else {
                        // Parsing halted, stop
                        return
                    }
                    
                    // Remove the parsed data
                    responseBuffer.removeSubrange(..<index)
                    
                    // Changes the value in this array
                    values[i] = result
                }
                
                // Flushes the resulting array to a request
                flush(parsingValue)
            }
            
            var index = responseBuffer.startIndex
            
            // Parses an element
            guard
                let token = responseBuffer.first,
                let (result, complete) = try parseToken(Character(Unicode.Scalar(token)), at: &index)
            else {
                return
            }
            
            // Remove the parsed data
            responseBuffer.removeSubrange(..<index)
            
            // If parsing is complete, flush
            guard complete else {
                // Else, store the half-parsed value
                parsingValue = result
                return
            }
            
            flush(result)
        }
    }
}

/// A parsing-in-progress Redis value
indirect enum _RedisValue {
    /// Placeholder for values in arrays
    case notYetParsed
    
    /// An array that's being parsed
    case parsing([_RedisValue])
    
    /// A correctly parsed value
    case parsed(RedisValue)
}
