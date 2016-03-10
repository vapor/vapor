import Vapor //Travis will fail without this

class MyController: BasicController {
    required init() {
        
    }
    
    /// Display many instances
    func index(request: Request) throws -> ResponseConvertible {
        return "index"
    }
    
    /// Create a new instance.
    func store(request: Request) throws -> ResponseConvertible {
        return "store"
    }
    
    /// Show an instance.
    func show(request: Request) throws -> ResponseConvertible {
        return "show"
    }
    
    /// Update an instance.
    func update(request: Request) throws -> ResponseConvertible {
        return "update"
    }
    
    /// Delete an instance.
    func destroy(request: Request) throws -> ResponseConvertible {
        return "destroy"
    }
    
}
