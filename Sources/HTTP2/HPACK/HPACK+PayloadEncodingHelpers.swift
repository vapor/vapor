import Foundation

extension Array where Element == Payload {
    mutating func withPayload(maxSize: Int, _ closure: (Payload) throws -> ()) rethrows {
        var payload: Payload
        
        if let last = self.last {
            payload = last
        } else {
            payload = Payload()
            self.append(payload)
        }
        
        var payloadSize = payload.data.count
        
        // Check if this payload has room
        if payloadSize >= maxSize {
            // Otherwise, create a new payload
            payload = Payload()
            payloadSize = 0
            
            self.append(payload)
        }
        
        try closure(payload)
        
        // If the payload became too big
        if payload.data.count > maxSize {
            // Copy the new data into a new payload
            let data = Data(payload.data[payloadSize..<payload.data.count])
            self.append(Payload(data: data))
            
            // Remove the data from the other payload
            payload.data.removeLast(payload.data.count - payloadSize)
        }
    }
}

extension UInt8 {
    static var completelyIndexed: UInt8 {
        return 0b10000000
    }
    
    static var headerIndexed: UInt8 {
        return 0b01000000
    }
    
    static var neverIndexed: UInt8 {
        return 0b00010000
    }
    
    static var notIndexed: UInt8 {
        return 0b00000000
    }
}
