/**
    When routing objects, it's common for us to want to associate the given slugs or params
    with that object. By conforming here, objects can be passed in.
*/
public protocol ParametersContainer: class {
    /**
        The contained parameters
    */
    var parameters: [String: String] { get set }
}
