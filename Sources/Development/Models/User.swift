import Foundation
import Async
import HTTP
import Leaf
import Vapor
import Fluent

final class User: Model, ResponseRepresentable {
    var id: UUID?
    var name: String
    var age: Int
//    var child: User?
//    var futureChild: Future<User>?
    let storage = Storage()
    
    func makeResponse(for request: Request) throws -> Response {
        let body = Body(try JSONEncoder().encode(self))
        
        return Response(body: body)
    }

    init(name: String, age: Int) {
        self.name = name
        self.age = age
    }
}

extension Future: Codable {
    public func encode(to encoder: Encoder) throws {
        guard var single = encoder.singleValueContainer() as? FutureEncoder else {
            throw "need a future encoder"
        }

        try single.encode(self)
    }

    public convenience init(from decoder: Decoder) throws {
        fatalError("blah")
    }
}

extension User: Migration {
    static func prepare(_ database: DatabaseConnection) -> Future<Void> {
        return database.create(User.self) { user in
            user.data("id", length: 16, isIdentifier: true)
            user.string("name")
            user.int("age")
        }
    }

    static func revert(_ database: DatabaseConnection) -> Future<Void> {
        return database.delete(User.self)
    }
}

struct AddUsers: Migration {
    static func prepare(_ database: DatabaseConnection) -> Future<Void> {
        let bob = User(name: "Bob", age: 42)
        let vapor = User(name: "Vapor", age: 3)

        return [
            bob.save(to: database),
            vapor.save(to: database)
        ].combine()
    }

    static func revert(_ database: DatabaseConnection) -> Future<Void> {
        return Future(())
    }
}

extension Array where Element: FutureType {
    public func combine() -> Future<[Element.Expectation]> {
        let many = ManyFutures(self)
        return many.promise.future
    }
}

extension Array where Element: FutureType, Element.Expectation == Void {
    public func combine() -> Future<Void> {
        let many = ManyFutures(self)
        let promise = Promise(Void.self)
        many.promise.future.then { _ in
            promise.complete()
        }.catch(promise.fail)
        return promise.future
    }
}

final class ManyFutures<F: FutureType> {
    /// The future's result will be stored
    /// here when it is resolved.
    var promise: Promise<[F.Expectation]>

    /// The futures completed.
    private var results: [F.Expectation]

    /// Ther errors caught.
    private var errors: [Swift.Error]

    /// All the awaited futures
    private var many: [F]

    /// Create a new many future.
    public init(_ many: [F]) {
        self.many = many
        self.results = []
        self.errors = []
        self.promise = Promise<[F.Expectation]>()

        for future in many {
            future.then { res in
                self.results.append(res)
                self.update()
            }.catch { err in
                self.errors.append(err)
                self.update()
            }
        }
    }

    /// Updates the many futures
    func update() {
        if results.count + errors.count == many.count {
            if errors.count > 0 {
                promise.complete(results)
            } else {
                promise.fail(errors.first!) // FIXME: combine errors
            }
        }
    }
}
