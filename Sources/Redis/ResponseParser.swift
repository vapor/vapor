import Async
import Bits
import Foundation

final class ResponseParser: Async.InputStream {
    typealias Input = ByteBuffer
    
    var onClose: BaseStream.CloseHandler?
    var errorStream: BaseStream.ErrorHandler?
    
    var responseQueue = [Promise<RedisValue>]()
    var responseBuffer = ""
    var parsingValue: RedisValue?
    
    var maximumRepsonseSize = 10_000_000
    
    init() {}
    
    func inputStream(_ input: ByteBuffer) {
        guard let input = String(bytes: input, encoding: .utf8) else {
            return
        }
        
        responseBuffer.append(contentsOf: input)
        
        do {
            try parseBuffer()
        } catch {
            self.parsingValue = nil
            errorStream?(error)
        }
    }
    
    fileprivate func simpleString(from position: inout String.Index) -> String? {
        var offset = 0
        var carriageReturnFound = false
        
        // Simple String
        detectionLoop: for character in responseBuffer[position...] {
            offset += 1
            
            if character == "\r" {
                carriageReturnFound = true
                break detectionLoop
            }
        }
        
        guard carriageReturnFound else {
            return nil
        }
        
        let endIndex = responseBuffer.index(position, offsetBy: offset)
        
        guard endIndex < responseBuffer.endIndex else {
            return nil
        }
        
        defer {
            position = responseBuffer.index(position, offsetBy: offset + 1)
        }
        
        return String(responseBuffer[position..<endIndex])
    }
    
    fileprivate func parseToken(_ token: Character, at position: inout String.Index) throws -> (result: RedisValue, complete: Bool)? {
        switch token {
        case "+":
            // Simple string
            guard let string = simpleString(from: &position) else {
                return nil
            }
            
            return (.basicString(string), true)
        case "-":
            // Error
            guard let string = simpleString(from: &position) else {
                return nil
            }
            
            return (.error(RedisError(string: string)), true)
        case ":":
            // Integer
            guard let string = simpleString(from: &position) else {
                return nil
            }
            
            guard
                string.count > 1,
                string.first == ":",
                let number = Int(string)
            else {
                throw ClientError.parsingError
            }
            
            return (.integer(number), true)
        case "$":
            // Bulk strings
            guard let string = simpleString(from: &position) else {
                return nil
            }
            
            guard
                string.count > 1,
                string.first == "$",
                let size = Int(string),
                size >= -1,
                size < responseBuffer.distance(from: position, to: responseBuffer.endIndex)
            else {
                throw ClientError.parsingError
            }
            
            let endPosition = responseBuffer.index(position, offsetBy: size)
            
            return (.bulkString(String(responseBuffer[position..<endPosition])), true)
        case "*":
            // Arrays
            guard let string = simpleString(from: &position) else {
                return nil
            }
            
            guard
                string.count > 1,
                string.first == "$",
                let size = Int(string),
                size >= 0
                else {
                    throw ClientError.parsingError
            }
            
            var array = [RedisValue](repeating: .notYetParsed, count: size)
            
            for index in 0..<size {
                guard remaining(1, from: position) else {
                    return (.array(array), false)
                }
                
                let oldPosition = position
                
                guard
                    let (result, complete) = try parseToken(responseBuffer[position], at: &position),
                    complete
                else {
                    position = oldPosition
                    return (.array(array), false)
                }
                
                array[index] = result
            }
            
            return (.array(array), true)
        default:
            throw ClientError.invalidTypeToken
        }
    }
    
    fileprivate func remaining(_ n: Int, from position: String.Index) -> Bool {
        return responseBuffer.distance(from: position, to: responseBuffer.endIndex) > 1
    }
    
    fileprivate func parseBuffer() throws {
        guard responseBuffer.count > 2, responseQueue.count > 0 else {
            return
        }
        
        func flush(_ result: RedisValue) {
            let completion = responseQueue.removeFirst()
            
            completion.complete(result)
            parsingValue = nil
        }
        
        while responseQueue.count > 0 {
            if let parsingValue = parsingValue {
                guard case .array(var values) = parsingValue else {
                    throw ClientError.parsingError
                }
                
                for i in 0..<values.count {
                    guard case .notYetParsed = values[i] else {
                        continue
                    }
                    
                    var index = responseBuffer.startIndex
                    
                    guard remaining(1, from: index) else {
                        return
                    }
                    
                    guard
                        let (result, complete) = try parseToken(responseBuffer[index], at: &index),
                        complete
                    else {
                        return
                    }
                    
                    values[i] = result
                }
                
                flush(parsingValue)
            }
            
            var index = responseBuffer.startIndex
            
            guard
                let token = responseBuffer.first,
                let (result, complete) = try parseToken(token, at: &index)
            else {
                return
            }
            
            responseBuffer.removeSubrange(...index)
            
            guard complete else {
                parsingValue = result
                return
            }
            
            flush(parsingValue)
        }
    }
}
