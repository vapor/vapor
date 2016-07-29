import HTTP
import Routing

/**
    The default Router for HTTP
    which routes paths to HTTPResponders.
*/
public typealias Router = Routing.Router<HTTP.Responder>
