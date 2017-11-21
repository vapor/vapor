import XCTest
@testable import Code
import Core
import Leaf
import Bits

class CodeTests: XCTestCase {
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
        /// MARK: Model

        #for(type in types) {
            #if(contains(type.inheritedTypes, "Model")) {
                extension #(type.name): Model {
                    /// See Model.keyFieldMap
                    static var keyFieldMap: KeyFieldMap {
                        return [
                            #for(property in type.properties) {
                                key(\\.#(property.name)): field("#(property.name)"),
                            }
                        ]
                    \\}
                \\}
            }
        }
        """

        let renderer = Renderer(tags: defaultTags, fileFactory: File.init)
        let encoder = LeafDataEncoder()
        let context = ["types": types]
        try context.encode(to: encoder)

//        let json = JSONEncoder()
//        json.outputFormatting = .prettyPrinted
//        let string = try String(data: json.encode(context), encoding: .utf8)!
//        print(string)

        print("CONTEXT:")
        print(encoder.context)
        let view = try! renderer.render(template, context: encoder.context, on: DispatchQueue.global()).blockingAwait()
        print("VIEW:")
        print(view)
    }


    static var allTests = [
        ("testExample", testExample),
    ]
}
