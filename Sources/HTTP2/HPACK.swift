
import HTTP
import Foundation

extension HeadersTable.Entry {
    var octets: Int {
        return self.name.description.utf8.count + self.value.utf8.count + 32
    }
}

public final class HPACKDecoder {
    let table = HeadersTable()
    var tableSize: Int = 4_096
    var currentTableSize = 0
    var maxTableSize: Int?
    
    fileprivate func getEntry(at index: Int) throws -> HeadersTable.Entry {
        // First the static entries
        if index >= 0, index <= HeadersTable.staticEntries.count {
            return HeadersTable.staticEntries[index &- 1]
        }
        
        // Get the dynamic entry index
        let index = index &- HeadersTable.staticEntries.count &- 1
        
        // The synamic entry *must* exist
        guard index < table.dynamicEntries.count else {
            throw Error(.invalidStaticTableIndex(index))
        }
        
        let entry = table.dynamicEntries[index]
        
        // Check if the name exist (I.E. not a dummy index reservation)
        guard !entry.isDummy else {
            throw Error(.invalidStaticTableIndex(index))
        }
        
        return entry
    }
    
    fileprivate func cleanTable() {
        // Remove extra entries if the table shrinks
        while currentTableSize > self.tableSize {
            let nextEntry = table.dynamicEntries.removeLast()
            currentTableSize -= nextEntry.octets
        }
    }
    
    public func decode(_ packet: Payload) throws -> Headers {
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
                
                self.tableSize = size
                cleanTable()
                
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
                currentTableSize += newEntry.octets
                cleanTable()
            }
            
            decoded[name] = value
            
            continue nextHeader
        }
        
        return decoded
    }
}
