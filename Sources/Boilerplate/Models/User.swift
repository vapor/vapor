final class User: Model, Content {
    static let database: DatabaseIdentifier<SQLiteDatabase> = .beta
    static var idKey = \User.id

    var id: Int?
    var name: String
    var age: Double
//    var child: User?
//    var futureChild: Future<User>?

    init(name: String, age: Double) {
        self.name = name
        self.age = age
    }

    var pets: Children<User, Pet> {
        return children(\.ownerID)
    }
}
