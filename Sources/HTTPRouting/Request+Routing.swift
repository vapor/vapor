import Routing
import Engine

/**
    Allows Requests to be used as a
    ParametersContainer.
 
    Request by default has a parameters dictionary
    so no additional methods are necessary.
*/
extension HTTPRequest: ParametersContainer { }
