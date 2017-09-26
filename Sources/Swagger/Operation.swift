import Foundation

public final class Operation: Encodable {
    public var tags = [String]()
    public var summary: String?
    public var description: String?
    public var externalDocs: ExternalDocumentation?
    public let operationId = UUID().uuidString
    public var parameters = [PossibleReference<Parameter>]()
    public var requestBody: PossibleReference<RequestBody>?
    public var responses: Responses
    // TODO:    public var callbacks = [String: PossibleReference<Callback>]()
    public var deprecated: Bool = false
    // TODO:    public var security = [SecurityRequirement]()
    
    public init(response: Response) {
        self.responses = Responses(response: response)
    }
    // TODO:    public var servers: [Server]
}
