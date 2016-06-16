import Vapor

class UserController: Controller {
    required init(application: Application) {
        Log.info("User controller created")
    }

    /**
        Display many instances
     */
    func index(request: HTTP.Request) throws -> ResponseRepresentable {
        return JSON([
            "controller": "MyController.index"
        ])
    }


    /**
        Create a new instance.
     */
    func store(request: HTTP.Request) throws -> ResponseRepresentable {
        return JSON([
            "controller": "MyController.store"
        ])
    }


    /**
        Show an instance.
     */
    func show(request: HTTP.Request, item user: User) throws -> ResponseRepresentable {
        //User can be used like JSON with JsonRepresentable
        return JSON([
            "controller": "MyController.show",
            "user": user
        ])
    }

    /** 
        Update an instance.
     */
    func update(request: HTTP.Request, item user: User) throws -> ResponseRepresentable {
        //Testing JsonRepresentable
        return user.makeJson()
    }

    /**
        Modify an instance (only the fields that are present in the request)
     */
    func modify(request: HTTP.Request, item user: User) throws -> ResponseRepresentable {
        //Testing JsonRepresentable
        return user.makeJson()
    }

    /**
        Delete an instance.
     */
    func destroy(request: HTTP.Request, item user: User) throws -> ResponseRepresentable {
        //User is ResponseRepresentable by proxy of JsonRepresentable
        return user
    }

    /**
        Delete all instances.
     */
    func destroy(request: HTTP.Request) throws -> ResponseRepresentable {
        return JSON([
            "controller": "MyController.destroyAll"
        ])
    }


    func options(request: HTTP.Request) throws -> ResponseRepresentable {
        return JSON([
            "info": "This is the Users resource"
        ])
    }
}
