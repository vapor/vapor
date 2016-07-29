import Node
import JSON
import Vapor
import HTTP

final class UserController: ResourceRepresentable {
    init() {

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
    func store(request: Request) throws -> ResponseRepresentable {
        return JSON([
            "controller": "MyController.store"
        ])
    }


    /**
        Show an instance.
     */
    func show(request: Request, item user: User) throws -> ResponseRepresentable {
        //User can be used like JSON with JsonRepresentable
        return JSON([
            "controller": "MyController.show",
            "user": user
        ])
    }

    /** 
        Update an instance.
     */
    func update(request: Request, item user: User) throws -> ResponseRepresentable {
        //Testing JsonRepresentable
        return try user.makeJSON()
    }

    /**
        Modify an instance (only the fields that are present in the request)
     */
    func modify(request: Request, item user: User) throws -> ResponseRepresentable {
        //Testing JsonRepresentable
        return try user.makeJSON()
    }

    /**
        Delete an instance.
     */
    func destroy(request: Request, item user: User) throws -> ResponseRepresentable {
        //User is ResponseRepresentable by proxy of JsonRepresentable
        return try user.makeJSON()
    }

    /**
        Delete all instances.
     */
    func destroy(request: Request) throws -> ResponseRepresentable {
        return JSON([
            "controller": "MyController.destroyAll"
        ])
    }


    func options(request: Request) throws -> ResponseRepresentable {
        return JSON([
            "info": "This is the Users resource"
        ])
    }

    func makeResource() -> Resource<User> {
        return Resource(
            index: index
        )
    }
}
