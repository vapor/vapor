
import HTTP
import Foundation

extension HeadersTable.Entry {
    var octets: Int {
        return self.name.description.utf8.count + self.value.utf8.count + 32
    }
}

public final class HPACKDecoder {
    let table = HeadersTable()
    
    /// Decodes HPACK encoded headers using the statically defined HPACK table
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
                if let maxTableSize = table.maxTableSize {
                    guard size <= maxTableSize else {
                        throw Error(.maxHeaderTableSizeOverridden(max: maxTableSize, updatedTo: size))
                    }
                }
                
                table.tableSize = size
                table.cleanTable()
                
                continue nextHeader
            }
            
            let staticEntry = byte & 0b10000000 == 0b10000000
            
            // If this is regarding a static entry
            // http://httpwg.org/specs/rfc7541.html#rfc.section.6.1
            if staticEntry {
                // Take the index number, this is a static entry
                let index = try packet.parseInteger(prefix: 7)
                
                let entry = try table.getEntry(at: index)
                
                // Add the header to the decoded
                decoded[entry.name] = entry.value
                continue nextHeader
            }
            
            let incrementallyIndexed = (byte & 0b11000000) == 0b01000000
            let neverIndexed = (byte & 0b11110000) == 0b00010000
            
            let name: Headers.Name
            
            if incrementallyIndexed {
                // Incrementally indexed
                if (byte & 0b00111111) == 0 {
                    // Header not indexed
                    packet.bytePosition += 1
                    name = Headers.Name(try packet.parseString())
                } else {
                    // Header indexed
                    let nameIndex = try packet.parseInteger(prefix: 6)
                    name = try table.getEntry(at: nameIndex).name
                }
            } else if neverIndexed {
                // Never indexed, ignore index
                let nameIndex = try packet.parseInteger(prefix: 4)
                
                if nameIndex == 0 {
                    // Header not indexed
                    name = Headers.Name(try packet.parseString())
                } else {
                    // Header indexed
                    name = try table.getEntry(at: nameIndex, dynamicTable: false).name
                }
            } else {
                // Not indexed
                if (byte & 0b00001111) == 0 {
                    // Header not indexed
                    packet.bytePosition += 1
                    name = Headers.Name(try packet.parseString())
                } else {
                    // Header indexed
                    let nameIndex = try packet.parseInteger(prefix: 4)
                    name = try table.getEntry(at: nameIndex).name
                }
            }
            
            let value = try packet.parseString()
            
            if incrementallyIndexed {
                let newEntry = HeadersTable.Entry(name: name, value: value)
                table.dynamicEntries.insert(newEntry, at: 0)
                table.currentTableSize += newEntry.octets
                table.cleanTable()
            }
            
            decoded[name] = value
            
            continue nextHeader
        }
        
        return decoded
    }
}
