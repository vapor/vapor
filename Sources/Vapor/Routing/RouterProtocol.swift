import HTTP
import Routing

public protocol RouterProtocol: class, RouteBuilder, Responder {
    var routes: [String] { get }
}
