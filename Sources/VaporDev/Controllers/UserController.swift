import Vapor

class UserController: Controller {
    required init(application: Application) {
        Log.info("User controller created")
    }
    
    /// Display many instances
    func index(request: Request) throws -> ResponseRepresentable {
        return Json([
            "controller": "MyController.index"
        ])
    }
    
    /// Create a new instance.
    func store(request: Request) throws -> ResponseRepresentable {
        return Json([
            "controller": "MyController.store"
        ])
    }
    
    /// Show an instance.
    func show(request: Request, item: User) throws -> ResponseRepresentable {
        return Json([
            "controller": "MyController.show",
            "user": item
        ])
    }
    
    /// Update an instance.
    func update(request: Request, item: User) throws -> ResponseRepresentable {
        return Json([
            "controller": "MyController.update",
            "user": item
        ])
    }
    
    /// Delete an instance.
    func destroy(request: Request, item: User) throws -> ResponseRepresentable {
        Log.info("Delete: \(item)")
        
        return item
    }
    
}
