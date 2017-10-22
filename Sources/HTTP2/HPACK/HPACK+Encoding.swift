import HTTP
import Foundation

public final class HPACKEncoder {
    let remoteTable = HeadersTable()
    var tableSize: Int = 4_096
    var currentTableSize = 0
    var maxTableSize: Int?
    
    public func encode(request: Request, chunksOf size: Int) -> [Data] {
        var frames = [Data]()
        
        frames.setAuthority(to: request.uri.path)
        
//        for entry in HeadersTable.staticEntries {
//
//        }
        
        return frames
    }
}

enum HPACKIndex {
    case none
    case incremental
}

fileprivate extension Array where Element == Data {
    mutating func setAuthority(to authority: String, index: HPACKIndex = .none) {
        let encoded =  HeadersTable.authority.index
    }
}

fileprivate extension UInt8 {
    static var completelyIndexed: UInt8 {
        return 0b10000000
    }
    
    static var headerIndexed: UInt8 {
        return 0b01000000
    }
    
    static var notIndexed: UInt8 {
        return 0b00000000
    }
}
