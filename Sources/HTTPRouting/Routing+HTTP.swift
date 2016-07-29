import HTTP
import Routing

/**
    The default Router for HTTP
    which routes paths to Responders.
*/
public typealias Router = Routing.Router<HTTP.Responder>
