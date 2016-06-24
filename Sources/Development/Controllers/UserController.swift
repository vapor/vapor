import Vapor

class UserController: Controller {
    required init(application: Application) {
        application.log.info("User controller created")
    }

    /**
        Display many instances
     */
    func index(request: Request) throws -> ResponseRepresentable {
        return JSON([
            "controller": "MyController.index"
        ])
    }


    /**
        Create a new instance.
     */
    func post(request: Request) throws -> ResponseRepresentable {
        return JSON([
            "controller": "MyController.post"
        ])
    }


    /**
        Show an instance.
     */
    func get(request: Request, item user: User) throws -> ResponseRepresentable {
        //User can be used like JSON with JsonRepresentable
        return JSON([
            "controller": "MyController.get",
            "user": user
        ])
    }

    /** 
        Update an instance.
     */
    func put(request: Request, item user: User) throws -> ResponseRepresentable {
        //Testing JsonRepresentable
        return user.makeJson()
    }

    /**
        Modify an instance (only the fields that are present in the request)
     */
    func patch(request: Request, item user: User) throws -> ResponseRepresentable {
        //Testing JsonRepresentable
        return user.makeJson()
    }

    /**
        Delete an instance.
     */
    func delete(request: Request, item user: User) throws -> ResponseRepresentable {
        //User is ResponseRepresentable by proxy of JsonRepresentable
        return user
    }

    /**
        Delete all instances.
     */
    func delete(request: Request) throws -> ResponseRepresentable {
        return JSON([
            "controller": "MyController.destroyAll"
        ])
    }


    func options(request: Request) throws -> ResponseRepresentable {
        return JSON([
            "info": "This is the Users resource"
        ])
    }
}
