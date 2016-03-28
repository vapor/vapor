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
    func show(request: Request, item user: User) throws -> ResponseRepresentable {
        //User can be used like JSON with JsonRepresentable
        return Json([
            "controller": "MyController.show",
            "user": user
        ])
    }
    
    /// Update an instance.
    func update(request: Request, item user: User) throws -> ResponseRepresentable {
        //Testing JsonRepresentable
        return user.makeJson()
    }
    
    /// Delete an instance.
    func destroy(request: Request, item user: User) throws -> ResponseRepresentable {
        //User is ResponseRepresentable by proxy of JsonRepresentable
        return user
    }
    
}
