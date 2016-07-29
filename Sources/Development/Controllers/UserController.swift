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
        return try JSON([
            "controller": "MyController.index"
        ])
    }


    /**
        Create a new instance.
     */
    func store(request: Request) throws -> ResponseRepresentable {
        return try JSON([
            "controller": "MyController.store"
        ])
    }


    /**
        Show an instance.
     */
    func show(request: Request, item user: User) throws -> ResponseRepresentable {
        //User can be used like JSON with JsonRepresentable
        return try JSON([
            "controller": "MyController.show",
            "user": user
            ] as [String: NodeRepresentable])
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
        return try JSON([
            "controller": "MyController.destroyAll"
        ])
    }


    func options(request: Request) throws -> ResponseRepresentable {
        return try JSON([
            "info": "This is the Users resource"
        ])
    }

    func makeResource() -> Resource<User> {
        return Resource(
            index: index
        )
    }
}

extension User: ResponseRepresentable {
    func makeResponse(for request: Request) throws -> HTTPResponse {
        return try makeJSON().makeResponse(for: request)
    }
}
