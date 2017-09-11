import Core
import Foundation

public final class File : Codable, Extendable {
    public var name: String
    public var data: Data
    
    public var extend = Extend()
    
    public init(named name: String, data: Data) {
        self.name = name
        self.data = data
    }
}
