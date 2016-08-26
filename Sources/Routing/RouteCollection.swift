/**
    A RouteCollection accepts a RouteBuilder
    and applies routes and RouteGroups.
 
    This is useful for separating and organizing
    routing into multiple files.
*/
public protocol RouteCollection {
    associatedtype Wrapped
    func build<Builder: RouteBuilder>(_ builder: Builder) where Builder.Value == Wrapped
}
