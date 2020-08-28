import XCTVapor

final class ContentTests: XCTestCase {
    func testContent() throws {
        let app = Application()
        defer { app.shutdown() }

        let request = Request(
            application: app,
            collectedBody: .init(string: #"{"hello": "world"}"#),
            on: EmbeddedEventLoop()
        )
        request.headers.contentType = .json
        try XCTAssertEqual(request.content.get(at: "hello"), "world")
    }

    func testComplexContent() throws {
        let app = Application()
        defer { app.shutdown() }

        // http://adobe.github.io/Spry/samples/data_region/JSONDataSetSample.html
        let complexJSON = """
        {
            "id": "0001",
            "type": "donut",
            "name": "Cake",
            "ppu": 0.55,
            "batters":
                {
                    "batter":
                        [
                            { "id": "1001", "type": "Regular" },
                            { "id": "1002", "type": "Chocolate" },
                            { "id": "1003", "type": "Blueberry" },
                            { "id": "1004", "type": "Devil's Food" }
                        ]
                },
            "topping":
                [
                    { "id": "5001", "type": "None" },
                    { "id": "5002", "type": "Glazed" },
                    { "id": "5005", "type": "Sugar" },
                    { "id": "5007", "type": "Powdered Sugar" },
                    { "id": "5006", "type": "Chocolate with Sprinkles" },
                    { "id": "5003", "type": "Chocolate" },
                    { "id": "5004", "type": "Maple" }
                ]
        }
        """
        let request = Request(
            application: app,
            collectedBody: .init(string: complexJSON),
            on: app.eventLoopGroup.next()
        )
        request.headers.contentType = .json
        try XCTAssertEqual(request.content.get(at: "batters", "batter", 1, "type"), "Chocolate")
    }

    func testGH1534() throws {
        let data = """
        {"name":"hi","bar":"asdf"}
        """

        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

        app.routes.get("decode_error") { req -> String in
            struct Foo: Decodable {
                var name: String
                var bar: Int
            }
            let foo = try JSONDecoder().decode(Foo.self, from: Data(data.utf8))
            return foo.name
        }

        try app.testable().test(.GET, "/decode_error") { res in
            XCTAssertEqual(res.status, .badRequest)
            XCTAssertContains(res.body.string, "Value of type 'Int' required for key 'bar'")
        }
    }

    func testContentContainer() throws {
        struct FooContent: Content {
            var message: String = "hi"
        }
        struct FooEncodable: Encodable {
            var message: String = "hi"
        }

        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

        app.routes.get("encode") { req -> Response in
            let res = Response()
            try res.content.encode(FooContent())
            try res.content.encode(FooContent(), as: .json)
            try res.content.encode(FooEncodable(), as: .json)
            return res
        }

        try app.testable().test(.GET, "/encode") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertContains(res.body.string, "hi")
        }
    }

    func testMultipartDecode() throws {
        let data = """
        --123\r
        Content-Disposition: form-data; name="name"\r
        \r
        Vapor\r
        --123\r
        Content-Disposition: form-data; name="age"\r
        \r
        4\r
        --123\r
        Content-Disposition: form-data; name="image"; filename="droplet.png"\r
        \r
        <contents of image>\r
        --123--\r

        """
        let expected = User(
            name: "Vapor",
            age: 4,
            image: File(data: "<contents of image>", filename: "droplet.png")
        )

        struct User: Content, Equatable {
            var name: String
            var age: Int
            var image: File
        }

        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

        app.routes.get("multipart") { req -> User in
            let decoded = try req.content.decode(User.self)
            XCTAssertEqual(decoded, expected)
            return decoded
        }

        try app.testable().test(.GET, "/multipart", headers: [
            "Content-Type": "multipart/form-data; boundary=123"
        ], body: .init(string: data)) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqualJSON(res.body.string, expected)
        }
    }

    func testMultipartEncode() throws {
        struct User: Content {
            static var defaultContentType: HTTPMediaType = .formData
            var name: String
            var age: Int
            var image: File
        }

        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

        app.get("multipart") { req -> User in
            return User(
                name: "Vapor",
                age: 4,
                image: File(data: "<contents of image>", filename: "droplet.png")
            )
        }
        try app.testable().test(.GET, "/multipart") { res in
            XCTAssertEqual(res.status, .ok)
            let boundary = res.headers.contentType?.parameters["boundary"] ?? "none"
            XCTAssertContains(res.body.string, "Content-Disposition: form-data; name=\"name\"")
            XCTAssertContains(res.body.string, "--\(boundary)")
            XCTAssertContains(res.body.string, "filename=droplet.png")
            XCTAssertContains(res.body.string, "name=\"image\"")
        }
    }

    func testURLEncodedFormDecode() throws {
        struct User: Content {
            var name: String
            var age: Int
            var luckyNumbers: [Int]
        }

        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

        app.get("urlencodedform") { req -> HTTPStatus in
            let foo = try req.content.decode(User.self)
            XCTAssertEqual(foo.name, "Vapor")
            XCTAssertEqual(foo.age, 3)
            XCTAssertEqual(foo.luckyNumbers, [5, 7])
            return .ok
        }

        var headers = HTTPHeaders()
        headers.contentType = .urlEncodedForm
        var body = ByteBufferAllocator().buffer(capacity: 0)
        body.writeString("name=Vapor&age=3&luckyNumbers[]=5&luckyNumbers[]=7")

        try app.testable().test(.GET, "/urlencodedform", headers: headers, body: body) { res in
            XCTAssertEqual(res.status.code, 200)
        }
    }

    func testURLEncodedFormEncode() throws {
        struct User: Content {
            static let defaultContentType: HTTPMediaType = .urlEncodedForm
            var name: String
            var age: Int
            var luckyNumbers: [Int]
        }

        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

        app.get("urlencodedform") { req -> User in
            return User(name: "Vapor", age: 3, luckyNumbers: [5, 7])
        }
        try app.testable().test(.GET, "/urlencodedform") { res in
            debugPrint(res)
            XCTAssertEqual(res.status.code, 200)
            XCTAssertEqual(res.headers.contentType, .urlEncodedForm)
            XCTAssertContains(res.body.string, "luckyNumbers[]=5")
            XCTAssertContains(res.body.string, "luckyNumbers[]=7")
            XCTAssertContains(res.body.string, "age=3")
            XCTAssertContains(res.body.string, "name=Vapor")
        }
    }

    func testJSONPreservesHTTPHeaders() throws {
        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

        app.get("check") { (req: Request) -> String in
            return "\(req.headers.first(name: .init("X-Test-Value")) ?? "MISSING").\(req.headers.first(name: .contentType) ?? "?")"
        }

        try app.test(.GET, "/check", headers: ["X-Test-Value": "PRESENT"], beforeRequest: { req in
            try req.content.encode(["foo": "bar"], as: .json)
        }) { res in
            XCTAssertEqual(res.body.string, "PRESENT.application/json; charset=utf-8")
        }
    }

    func testJSONAllowsContentTypeOverride() throws {
        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

        app.get("check") { (req: Request) -> String in
            return "\(req.headers.first(name: .init("X-Test-Value")) ?? "MISSING").\(req.headers.first(name: .contentType) ?? "?")"
        }
        // Me and my sadistic sense of humor.
        ContentConfiguration.global.use(decoder: try! ContentConfiguration.global.requireDecoder(for: .json), for: .xml)

        try app.testable().test(.GET, "/check", headers: [
            "X-Test-Value": "PRESENT"
            ], beforeRequest: { req in
                try req.content.encode(["foo": "bar"], as: .json)
                req.headers.contentType = .xml
        }) { res in
            XCTAssertEqual(res.body.string, "PRESENT.application/xml; charset=utf-8")
        }
    }

    func testBeforeEncodeContent() throws {
        let content = SampleContent()
        XCTAssertEqual(content.name, "old name")

        let response = Response(status: .ok)
        try response.content.encode(content)

        let body = try XCTUnwrap(response.body.string)
        XCTAssertEqual(body, #"{"name":"new name"}"#)
    }

    func testAfterContentEncode() throws {
        let app = Application()
        defer { app.shutdown() }

        var body = ByteBufferAllocator().buffer(capacity: 0)
        body.writeString(#"{"name": "before decode"}"#)

        let request = Request(
            application: app,
            collectedBody: body,
            on: EmbeddedEventLoop()
        )

        request.headers.contentType = .json

        let content = try request.content.decode(SampleContent.self)
        XCTAssertEqual(content.name, "new name after decode")
    }

    func testQueryHooks() throws {
        let app = Application()
        defer { app.shutdown() }

        let request = Request(
            application: app,
            collectedBody: .init(string:""),
            on: EmbeddedEventLoop()
        )
        request.url.query = "name=before+decode"
        request.headers.contentType = .json

        let query = try request.query.decode(SampleContent.self)
        XCTAssertEqual(query.name, "new name after decode")
        try request.query.encode(query)
        XCTAssertEqual(request.url.query, "name=new%20name")
    }

    func testSnakeCaseCodingKeyError() throws {
        let app = Application()
        defer { app.shutdown() }

        let req = Request(application: app, on: app.eventLoopGroup.next())
        try req.content.encode([
            "title": "The title"
        ], as: .json)

        struct PostInput: Content {
            enum CodingKeys: String, CodingKey {
                case id, title, isFree = "is_free"
            }
            let id: UUID?
            let title: String
            let isFree: Bool
        }
        XCTAssertThrowsError(try req.content.decode(PostInput.self)) { error in
            XCTAssertEqual(
                (error as? AbortError)?.reason,
                "Value required for key 'is_free'."
            )
        }
    }
}

private struct SampleContent: Content {
    var name = "old name"

    mutating func beforeEncode() throws {
        name = "new name"
    }

    mutating func afterDecode() throws {
        name = "new name after decode"
    }
}
