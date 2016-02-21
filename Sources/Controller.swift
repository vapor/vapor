/**
 * Organize your routing logic with a subclass of
 * `Controller`. Controlls group related route logic into
 * a single class that, by default, conforms to standard
 * CRUD operations.
 */
public class Controller {

	///Create a default controller
	public init() {}

    ///Display many instances
	public func index(request: Request) throws -> ResponseConvertible {
        print("Ran idx")
		return "index"
	}

	///Create a new instance.
	public func store(request: Request) throws -> ResponseConvertible {
        print("Ran store")
		return "store"
	}

	///Show an instance.
	public func show(request: Request) throws -> ResponseConvertible {
        print("Ran show")
		return "show"
	}

    ///Update an instance.
	public func update(request: Request) throws -> ResponseConvertible {
        print("Ran update")
		return "update"
	}

	///Delete an instance.
	public func destroy(request: Request) throws -> ResponseConvertible {
        print("Ran destroy")
		return "destroy"
	}
    
}
