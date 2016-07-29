import Routing
import HTTP

/**
    Allows Requests to be used as a
    ParametersContainer.
 
    Request by default has a parameters dictionary
    so no additional methods are necessary.
*/
extension HTTP.Request: Routing.ParametersContainer { }
