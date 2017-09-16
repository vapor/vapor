import Foundation

public struct ExternalDocumentation: Encodable {
    public var description: String?
    public var url: URL
    
    public init(url: URL) {
        self.url = url
    }
}
