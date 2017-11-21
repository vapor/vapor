import XCTest
@testable import Code
import Core
import Leaf
import Bits

class CodeTests: XCTestCase {
    func testContext() throws {
        let data = ["hi": "hello"]

        let encoder = LeafDataEncoder()
        try! data.encode(to: encoder)

        print("Context: \(encoder.context)")
    }

    func testExample() throws {
        let parser = Code.Parser()
        let file = """
        class User {

            /// the user's name
            var name: String

            /// - dbType: double
            var age: Int

            /// the user's bio
            /// - dbType: custom
            /// - dbCustom: TEXT
            let bio: String

            static let foo: String
            static var bar: Int

            init() {

            }

            func hi() { }

            static func fuck() {}
        }

        extension User: Preparation { }
        extension User: Model { }
        extension User: JSONConvertible { }

        class Animal { }

        struct Int { }

        enum Foo {
            case bar
            case baz
        }
        """
        let types = try! parser.parse(files: [file.data(using: .utf8)!])

        let template = """
        #for(type in types) {
            #if(contains(type.inheritedTypes, "Preparation")) {
                extension #(type.name) \\{
                    public static func prepare(database: Database) {
                        try database.create(self) { builder in
                            builder.id()
                            #for(property in type.properties) {
                                #if(property.comment.attributes.dbType) {
                                    #if(property.comment.attributes.dbType == "custom") {
                                        builder.custom("#(property.comment.attributes.dbCustom)", "#(property.name)")
                                    } else {
                                        builder.#(property.comment.attributes.dbType)("#(property.name)")
                                    }
                                } else {
                                    builder.#(lowercase(property.typeName))("#(property.name)")
                                }
                            }
                        \\}
                    \\}
                \\}
            }

            #if(contains(type.inheritedTypes, "Model")) {
                extension #(type.name) \\{
                    public convenience init(row: Row) throws {
                        try self.init(
                            #for(property in type.properties) {
                                #(property.name): row.get("#(property.name)") #if(!loop.isLast) { , }
                            }
                        )
                    \\}

                    public func makeRow() throws -> Row {
                        var row = Row()
                        #for(property in type.properties) {
                            try row.set("#(property.name)", #(property.name))
                        }
                        return row
                    \\}
                \\}
            }


            #if(contains(type.inheritedTypes, "JSONRepresentable") || contains(type.inheritedTypes, "JSONConvertible")) {
                extension #(type.name) \\{
                    public func makeJSON() throws -> JSON {
                        var json = JSON()
                        #for(property in type.properties) {
                            try json.set("#(property.name)", #(property.name))
                        }
                        return json
                    \\}
                \\}
            }

            #if(contains(type.inheritedTypes, "JSONInitializable") || contains(type.inheritedTypes, "JSONConvertible")) {
                extension #(type.name) \\{
                    public convenience init(json: JSON) throws {
                        try self.init(
                            #for(property in type.properties) {
                                #(property.name): json.get("#(property.name)") #if(!loop.isLast) { , }
                            }
                        )
                    \\}
                \\}
            }
        }
        """

        let renderer = Renderer(tags: defaultTags, fileFactory: File.init)
        let encoder = LeafDataEncoder()
        let context = ["types": types]
        print(context)
        try context.encode(to: encoder)

        let json = JSONEncoder()
        json.outputFormatting = .prettyPrinted
        let string = try String(data: json.encode(context), encoding: .utf8)!
        print(string)

        print(encoder.context)
        let view = try! renderer.render(template, context: encoder.context, on: DispatchQueue.global()).blockingAwait()
        print(types)
        print(view)
    }


    static var allTests = [
        ("testExample", testExample),
    ]
}
