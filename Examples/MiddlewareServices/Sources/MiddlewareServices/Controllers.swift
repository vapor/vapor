import FluentKit
import HTTPTypes
import Logging
import RoutingKit
import Vapor
import VaporMacros

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// As in vapor/template's vapor5 branch, the application owns a configured Databases
// service and its lifecycle. Controllers receive that service through their initializer.
func registerServiceRoutes(on app: Application, databases: Databases, client: any Client) async throws {
    try await app.register(collection: UserController(databases: databases, client: client))
}

@Controller
struct UserController {
    let databases: Databases
    let client: any Client

    var authentication: DatabaseAuthenticator {
        DatabaseAuthenticator(databases: databases)
    }

    #Middleware(using: { (controller: Self) in APIServiceMiddleware(client: controller.client) }) {
        #AuthMiddleware(DatabaseUser.self, using: \Self.authentication) {
            @GET("users", "me")
            func me(req: Request, user: DatabaseUser) async throws -> String {
                user.name
            }
        }
    }

    @GET("users", "profile")
    @AuthMiddleware(DatabaseUser.self, using: { (controller: Self) in DatabaseAuthenticator(databases: controller.databases) })
    func profile(req: Request, user: DatabaseUser) async throws -> String {
        user.name
    }
}

struct DatabaseAuthenticator: Middleware {
    let databases: Databases

    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        if let token = request.headers.bearerAuthorization?.token,
            let database = databases.database(logger: Logger.current, on: databases.eventLoopGroup.any()),
            let user = try await DatabaseUser.query(on: database).filter(\.$token == token).first()
        {
            request.auth.login(user)
        }
        return try await next.respond(to: request)
    }
}

struct APIServiceMiddleware: Middleware {
    let client: any Client

    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        _ = try await client.get("https://service.example/status")
        return try await next.respond(to: request)
    }
}

final class DatabaseUser: Model, Authenticatable, @unchecked Sendable {
    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "token")
    var token: String

    init() {}
}
