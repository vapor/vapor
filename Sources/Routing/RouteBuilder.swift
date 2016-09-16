import Foundation

/**
    Conforming to RouteBuilder allows
    an object to gain all of the available
    route building extensions.
 
    This is useful for a class that has 
    a reference to a Router or another RouteBuilder
    and would like route building methods to
    be called directly on the class.
*/
public protocol RouteBuilder {
    /**
        The type of Value this RouteBuilder
        accepts for adding. This will be equivalent
        to the underlying Router's Output.
    */
    associatedtype Value

    /**
        Adds the Value to the underlying
        Router at the given path.
    */
    func add(path: [String], value: Value)
}

/**
    Conforms the default Router to RouteBuilder.
    All route building methods are added to RouteBuilder.
*/
extension Router: RouteBuilder {
    /**
        The RouteBuilder's Value should be
        equal to the Router's Output.
     
        This means the RouteBuilder extensions
        can only add types that the router can hold.
    */
    public typealias Value = Output

    /**
        - see: RouteBuilder
    */
    public func add(path: [String], value: Value) {
        register(path: path, output: value)
    }
}
