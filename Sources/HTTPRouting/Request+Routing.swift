import Routing
import HTTP
import Node


private let parametersKey = "parameters"

/**
    Allows Requests to be used as a
    ParametersContainer.
 
    Request by default has a parameters dictionary
    so no additional methods are necessary.
*/
extension HTTP.Request: Routing.ParametersContainer {
    public var parameters: Node {
        get {
            let node: Node

            if let existing = storage[parametersKey] as? Node {
                node = existing
            } else {
                node = Node.object([:])
                storage[parametersKey] = node
            }

            return node
        }
        set {
            storage[parametersKey] = newValue
        }
    }
}
