
import HTTP
import Foundation

public final class Packet {
    var data: Data
    var bytePosition = 0
    var bitPosition = 0
    
    init(data: Data = Data()) {
        self.data = data
    }
}

public final class HPACKDecoder {
    let table = HeadersTable()
    var tableSize: Int = 4_096
    var maxTableSize: Int?
    
    fileprivate func getEntry(at index: Int) throws -> HeadersTable.Entry {
        // First the static entries
        if index <= HeadersTable.staticEntries.count {
            return HeadersTable.staticEntries[index &- 1]
        }
        
        // Get the dynamic entry index
        let index = index &- HeadersTable.staticEntries.count &- 1
        
        // The synamic entry *must* exist
        guard index >= 0, index < table.dynamicEntries.count else {
            throw Error(.invalidStaticTableIndex(index))
        }
        
        let entry = table.dynamicEntries[index]
        
        // Check if the name exist (I.E. not a dummy index reservation)
        guard !entry.isDummy else {
            throw Error(.invalidStaticTableIndex(index))
        }
        
        return entry
    }
    
    public func decode(_ packet: Packet) throws -> Headers {
        var decoded = Headers()
        
        nextHeader: while packet.bytePosition < packet.data.count {
            let byte = packet.data[packet.bytePosition]
            
            // First 2 bits are `0`, third bit is `1`
            let dynamicTableUpdate = (byte & 0b11100000) == 0b00100000
            
            // Updating the dynamic table
            // http://httpwg.org/specs/rfc7541.html#encoding.context.update
            if dynamicTableUpdate {
                // Base size of the static entries
                let size = try packet.parseInteger(prefix: 5)
                
                // Check for the maxTableSize requirements
                if let maxTableSize = maxTableSize {
                    guard size <= maxTableSize else {
                        throw Error(.maxHeaderTableSizeOverridden(max: maxTableSize, updatedTo: size))
                    }
                }
                
                // Remove extra entries if the table shrinks
                if table.dynamicEntries.count > size {
                    table.dynamicEntries.removeLast(size - table.dynamicEntries.count)
                }
                
                self.tableSize = size
                
                continue nextHeader
            }
            
            let staticEntry = byte & 0b10000000 == 0b10000000
            
            // If this is regarding a static entry
            // http://httpwg.org/specs/rfc7541.html#rfc.section.6.1
            if staticEntry {
                // Take the index number, this is a static entry
                let index = try packet.parseInteger(prefix: 7)
                
                let entry = try getEntry(at: index)
                
                // Add the header to the decoded
                decoded[entry.name] = entry.value
                continue nextHeader
            }
            
            let incrementallyIndexed = (byte & 0b11000000) == 0b01000000
//            let notIndexed = (byte & 0b11110000) == 0
//            let neverIndexed = (byte & 0b11110000) == 0b00010000
            
            let name: Headers.Name
            
            if incrementallyIndexed {
                if (byte & 0b00111111) == 0 {
                    packet.bytePosition += 1
                    name = Headers.Name(try packet.parseString())
                } else {
                    let nameIndex = try packet.parseInteger(prefix: 6)
                    name = try getEntry(at: nameIndex).name
                }
            } else {
                if (byte & 0b00001111) == 0 {
                    packet.bytePosition += 1
                    name = Headers.Name(try packet.parseString())
                } else {
                    let nameIndex = try packet.parseInteger(prefix: 4)
                    name = try getEntry(at: nameIndex).name
                }
            }
            let value = try packet.parseString()
            
            if incrementallyIndexed {
                let newEntry = HeadersTable.Entry(name: name, value: value)
                table.dynamicEntries.insert(newEntry, at: 0)
            }
            
            decoded[name] = value
            
            continue nextHeader
        }
        
        return decoded
    }
}

struct Error: Swift.Error {
    let problem: Problem
    
    init(_ problem: Problem) {
        self.problem = problem
    }
    
    enum Problem {
        case unexpectedEOF
        case invalidPrefixSize(Int)
        case invalidUTF8String
        case maxHeaderTableSizeOverridden(max: Int, updatedTo: Int)
        case invalidStaticTableIndex(Int)
    }
}
