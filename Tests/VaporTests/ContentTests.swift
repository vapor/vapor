import NIOCore
import HTTPTypes
import Vapor
import Testing
import VaporTesting
import Foundation

@Suite("Content Tests")
struct ContentTests {

    @Test("Test Content")
    func testContent() async throws {
        try await withApp { app throws in
            let request = Request(
                application: app,
                collectedBody: .init(string: #"{"hello": "world"}"#),
                on: app.eventLoopGroup.any()
            )
            request.headers.contentType = .json
            #expect(try request.content.get(at: "hello") == "world")
        }
    }

    @Test("Test complex content")
    func testComplexContent() async throws {
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

        try await withApp { app throws in
            let request = Request(
                application: app,
                collectedBody: .init(string: complexJSON),
                on: app.eventLoopGroup.any()
            )
            request.headers.contentType = .json
            #expect(try request.content.get(at: "batters", "batter", 1, "type") == "Chocolate")
        }
    }

    @Test("Test decoding errors return 400", .bug("https://github.com/vapor/vapor/issues/1534"))
    func testGH1534() async throws {
        let data = """
        {"name":"hi","bar":"asdf"}
        """

        try await withApp { app in
            app.routes.get("decode_error") { _ -> String in
                struct Foo: Decodable {
                    var name: String
                    var bar: Int
                }
                let foo = try JSONDecoder().decode(Foo.self, from: Data(data.utf8))
                return foo.name
            }

            try await app.testing().test(.get, "/decode_error") { res in
                #expect(res.status == .badRequest)
                #expect(res.body.string.contains(#"Value was not of type 'Int' at path 'bar'. Expected to decode Int but found a string"#))
            }
        }
    }

    @Test("Test Content Container Encode")
    func testContentContainerEncode() async throws {
        struct FooContent: Content {
            var message: String = "hi"
        }
        struct FooEncodable: Encodable {
            var message: String = "hi"
        }

        try await withApp { app in
            app.routes.get("encode") { _ -> Response in
                let res = Response()
                try res.content.encode(FooContent())
                try res.content.encode(FooContent(), as: .json)
                try res.content.encode(FooEncodable(), as: .json)
                return res
            }

            try await app.testing().test(.get, "/encode") { res in
                #expect(res.status == .ok)
                #expect(res.body.string.contains("hi"))
            }
        }
    }

    @Test("Test Content Container Decode")
    func testContentContainerDecode() async throws {
        struct FooContent: Content, Equatable {
            var message: String = "hi"
        }
        struct FooDecodable: Decodable, Equatable {
            var message: String = "hi"
        }

        try await withApp { app in
            app.routes.post("decode") { req async throws -> String in
                #expect(try req.content.decode(FooContent.self) == FooContent())
                #expect(try req.content.decode(FooDecodable.self, as: .json) == FooDecodable())
                return "decoded!"
            }

            try await app.testing().test(.post, "/decode") { req in
                try req.content.encode(FooContent())
            } afterResponse: { res in
                #expect(res.status == .ok)
                #expect(res.body.string.contains("decoded!"))
            }

            app.routes.post("decode-bad-header") { req async throws -> String in
                #expect(req.headers.contentType == .audio)
                #expect(performing: {
                    try req.content.decode(FooContent.self)
                }, throws: { error in
                    (error as? Abort)?.status == .unsupportedMediaType
                })
                #expect(try req.content.decode(FooDecodable.self, as: .json) == FooDecodable())
                return "decoded!"
            }

            try await app.testing().test(.post, "/decode-bad-header") { req in
                try req.content.encode(FooContent())
                req.headers.contentType = .audio
            } afterResponse: { res in
                #expect(res.status == .ok)
                #expect(res.body.string.contains("decoded!"))
            }
        }
    }

    @Test("Multipart Decode")
    func testMultipartDecode() async throws {
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

        try await withApp { app in
            app.routes.get("multipart") { req -> User in
                let decoded = try req.content.decode(User.self)
                #expect(decoded == expected)
                return decoded
            }

            try await app.testing().test(.get, "/multipart", headers: [
                .contentType: "multipart/form-data; boundary=123"
            ], body: .init(string: data)) { res in
                #expect(res.status == .ok)
                expectJSONEquals(res.body.string, expected)
            }
        }
    }

    @Test("Test Multipart Decoded Empty Multipart Form")
    func testMultipartDecodedEmptyMultipartForm() async throws {
        let data = """
        --123\r
        --123--\r
        """
        let expected = User(
            name: "Vapor"
        )

        struct User: Content, Equatable {
            var name: String
        }

        try await withApp { app in
            app.routes.get("multipart") { req -> User in
                let decoded = try req.content.decode(User.self)
                #expect(decoded == expected)
                return decoded
            }

            try await app.testing().test(.get, "/multipart", headers: [
                .contentType: "multipart/form-data; boundary=123"
            ], body: .init(string: data)) { res in
                #expect(res.status == .unprocessableContent)
            }
        }
    }

    @Test("Test Multipart Decoded Empty Body")
    func testMultipartDecodedEmptyBody() async throws {
        let data = ""
        let expected = User(
            name: "Vapor"
        )

        struct User: Content, Equatable {
            var name: String
        }

        try await withApp { app in
            app.routes.get("multipart") { req -> User in
                let decoded = try req.content.decode(User.self)
                #expect(decoded == expected)
                return decoded
            }

            try await app.testing().test(.get, "/multipart", headers: [
                .contentType: "multipart/form-data; boundary=123"
            ], body: .init(string: data)) { res in
                #expect(res.status == .unprocessableContent)
            }
        }
    }

    @Test("Test Multipart Decode Unicode")
    func testMultipartDecodeUnicode() async throws {
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
        Content-Disposition: form-data; name="image"; filename="她在吃水果.png"; filename*="UTF-8\'\'%E5%A5%B9%E5%9C%A8%E5%90%83%E6%B0%B4%E6%9E%9C.png"\r
        \r
        <contents of image>\r
        --123--\r

        """
        let expected = User(
            name: "Vapor",
            age: 4,
            image: File(data: "<contents of image>", filename: "UTF-8\'\'%E5%A5%B9%E5%9C%A8%E5%90%83%E6%B0%B4%E6%9E%9C.png")
        )

        struct User: Content, Equatable, Sendable {
            var name: String
            var age: Int
            var image: File
        }

        try await withApp { app in
            app.routes.get("multipart") { req -> User in
                let decoded = try req.content.decode(User.self)
                #expect(decoded == expected)
                return decoded
            }

            try await app.testing().test(.get, "/multipart", headers: [
                .contentType: "multipart/form-data; boundary=123"
            ], body: .init(string: data)) { res in
                #expect(res.status == .ok)
                expectJSONEquals(res.body.string, expected)
            }
        }
    }

    @Test("Test Multipart Encoding")
    func testMultipartEncode() async throws {
        struct User: Content {
            static let defaultContentType: HTTPMediaType = .formData
            var name: String
            var age: Int
            var image: File
        }

        try await withApp { app in
            app.get("multipart") { _ -> User in
                User(
                    name: "Vapor",
                    age: 4,
                    image: File(data: "<contents of image>", filename: "droplet.png")
                )
            }
            try await app.testing().test(.get, "/multipart") { res in
                #expect(res.status == .ok)
                let boundary = res.headers.contentType?.parameters["boundary"] ?? "none"
                #expect(res.body.string.contains("Content-Disposition: form-data; name=\"name\""))
                #expect(res.body.string.contains("--\(boundary)"))
                #expect(res.body.string.contains("filename=\"droplet.png\""))
                #expect(res.body.string.contains("name=\"image\""))
            }
        }
    }

    @Test("Test Multipart Encoding with Unicode")
    func testMultiPartEncodeUnicode() async throws {
        struct User: Content {
            static let defaultContentType: HTTPMediaType = .formData
            var name: String
            var age: Int
            var image: File
        }

        try await withApp { app in
            app.get("multipart") { _ -> User in
                User(
                    name: "Vapor",
                    age: 4,
                    image: File(data: "<contents of image>", filename: "UTF-8\'\'%E5%A5%B9%E5%9C%A8%E5%90%83%E6%B0%B4%E6%9E%9C.png")
                )
            }
            try await app.testing().test(.get, "/multipart") { res in
                #expect(res.status == .ok)
                let boundary = res.headers.contentType?.parameters["boundary"] ?? "none"
                #expect(res.body.string.contains("Content-Disposition: form-data; name=\"name\""))
                #expect(res.body.string.contains("--\(boundary)"))
                #expect(res.body.string.contains("filename=\"UTF-8\'\'%E5%A5%B9%E5%9C%A8%E5%90%83%E6%B0%B4%E6%9E%9C.png\""))
                #expect(res.body.string.contains("name=\"image\""))
            }
        }
    }

    @Test("Test URLEncoded Form Decode")
    func testURLEncodedFormDecode() async throws {
        struct User: Content {
            var name: String
            var age: Int
            var luckyNumbers: [Int]
        }

        try await withApp { app in
            app.get("urlencodedform") { req -> HTTPStatus in
                let foo = try req.content.decode(User.self)
                #expect(foo.name == "Vapor")
                #expect(foo.age == 3)
                #expect(foo.luckyNumbers == [5, 7])
                return .ok
            }

            var headers = HTTPFields()
            headers.contentType = .urlEncodedForm
            var body = ByteBufferAllocator().buffer(capacity: 0)
            body.writeString("name=Vapor&age=3&luckyNumbers[]=5&luckyNumbers[]=7")

            try await app.testing().test(.get, "/urlencodedform", headers: headers, body: body) { res in
                #expect(res.status.code == 200)
            }
        }
    }

    @Test("Test URLEncoded Form Encode")
    func testURLEncodedFormEncode() async throws {
        struct User: Content {
            static let defaultContentType: HTTPMediaType = .urlEncodedForm
            var name: String
            var age: Int
            var luckyNumbers: [Int]
        }

        try await withApp { app in
            app.get("urlencodedform") { _ -> User in
                User(name: "Vapor", age: 3, luckyNumbers: [5, 7])
            }
            try await app.testing().test(.get, "/urlencodedform") { res in
                #expect(res.status.code == 200)
                #expect(res.headers.contentType == .urlEncodedForm)
                #expect(res.body.string.contains("luckyNumbers[]=5"))
                #expect(res.body.string.contains("luckyNumbers[]=7"))
                #expect(res.body.string.contains("age=3"))
                #expect(res.body.string.contains("name=Vapor"))
            }
        }
    }

    @Test("Test JSON Preserves HTTP Headers")
    func testJSONPreservesHTTPHeaders() async throws {
        try await withApp { app in
            app.get("check") { (req: Request) -> String in
                "\(req.headers[.init("X-Test-Value")!] ?? "MISSING").\(req.headers[.contentType] ?? "?")"
            }

            try await app.testing().test(.get, "/check", headers: [.init("X-Test-Value")!: "PRESENT"], beforeRequest: { req in
                try req.content.encode(["foo": "bar"], as: .json)
            }) { res in
                #expect(res.body.string == "PRESENT.application/json; charset=utf-8")
            }
        }
    }

    @Test("Test JSON Allows ContentType Override")
    func testJSONAllowsContentTypeOverride() async throws {
        // Me and my sadistic sense of humor.
        var contentConfiguration = ContentConfiguration.default()
        try contentConfiguration.use(decoder: contentConfiguration.requireDecoder(for: .json), for: .xml)
        let app = try await Application(.testing, services: .init(contentConfiguration: contentConfiguration))
        app.get("check") { (req: Request) -> String in
            "\(req.headers[.init("X-Test-Value")!] ?? "MISSING").\(req.headers[.contentType] ?? "?")"
        }

        try await app.testing().test(.get, "/check", headers: [
            .init("X-Test-Value")!: "PRESENT"
        ], beforeRequest: { req in
            try req.content.encode(["foo": "bar"], as: .json)
            req.headers.contentType = .xml
        }) { res in
            #expect(res.body.string == "PRESENT.application/xml; charset=utf-8")
        }
        try await app.shutdown()
    }

    @Test("Test Before Encode Content")
    func testBeforeEncodeContent() throws {
        let content = SampleContent()
        #expect(content.name == "old name")

        let response = Response(status: .ok)
        try response.content.encode(content)

        let body = try #require(response.body.string)
        #expect(body == #"{"name":"new name"}"#)
    }

    @Test("Test After Content Encode")
    func testAfterContentEncode() async throws {
        var body = ByteBufferAllocator().buffer(capacity: 0)
        body.writeString(#"{"name": "before decode"}"#)

        try await withApp { app in
            let request = Request(
                application: app,
                collectedBody: body,
                on: app.eventLoopGroup.any()
            )

            request.headers.contentType = .json

            let content = try request.content.decode(SampleContent.self)
            #expect(content.name == "new name after decode")
        }
    }

    @Test("Test Supports JSON API")
    func testSupportsJsonApi() async throws {
        var body = ByteBufferAllocator().buffer(capacity: 0)
        body.writeString(#"{"data": ["entity0", "entity1"], "meta": {}}"#)

        try await withApp { app in
            let request = Request(
                application: app,
                collectedBody: body,
                on: app.eventLoopGroup.any()
            )

            request.headers.contentType = .jsonAPI

            let content = try request.content.decode(JsonApiContent.self)
            #expect(content.data == ["entity0", "entity1"])
        }
    }

    @Test("Test Query Hooks")
    func testQueryHooks() async throws {
        try await withApp { app in
            let request = Request(
                application: app,
                collectedBody: .init(string: ""),
                on: app.eventLoopGroup.any()
            )
            request.url.query = "name=before+decode"
            request.headers.contentType = .json

            let query = try request.query.decode(SampleContent.self)
            #expect(query.name == "new name after decode")
            try request.query.encode(query)
            #expect(request.url.query == "name=new%20name")
        }
    }

    @Test("Test Decode Percent Encoded Query", .bug("https://github.com/vapor/vapor/issues/3135"))
    func testDecodePercentEncodedQuery() async throws {
        try await withApp { app throws in
            let request = Request(
                application: app,
                collectedBody: .init(string: ""),
                on: app.eventLoopGroup.any()
            )
            request.url = .init(string: "/?name=value%20has%201%25%20of%20its%20percents")
            request.headers.contentType = .urlEncodedForm

            #expect(try request.query.get(String.self, at: "name") == "value has 1% of its percents")
        }
    }

    @Test("Test Encode Percent Encoded Query", .bug("https://github.com/vapor/vapor/issues/3133"))
    func testEncodePercentEncodedQuery() throws {
        struct Foo: Content {
            var status: String
        }

        var request = ClientRequest(url: .init(scheme: "https", host: "example.com", path: "/api"))
        try request.query.encode(Foo(status:
            "⬆️ taylorswift just released swift-mongodb v0.10.1 – use BSON and MongoDB in pure Swift\n\nhttps://swiftpackageindex.com/tayloraswift/swift-mongodb#releases"
        ))

        #expect(request.url.string == "https://example.com/api?status=%E2%AC%86%EF%B8%8F%20taylorswift%20just%20released%20swift-mongodb%20v0.10.1%20%E2%80%93%20use%20BSON%20and%20MongoDB%20in%20pure%20Swift%0A%0Ahttps%3A%2F%2Fswiftpackageindex.com%2Ftayloraswift%2Fswift-mongodb%23releases")
    }

    @Test("Test Snake Case Coding Key Error")
    func testSnakeCaseCodingKeyError() async throws {
        try await withApp { app in
            let req = Request(application: app, on: app.eventLoopGroup.any())
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
            #expect(performing: {
                try req.content.decode(PostInput.self)
            }, throws: { error in
                return (error as? any AbortError)?.reason ==
                        #"No such key 'is_free' at path ''. No value associated with key CodingKeys(stringValue: "is_free", intValue: nil) ("is_free")."#
            })
        }
    }

    @Test("Test Data Corruption Error")
    func testDataCorruptionError() async throws {
        try await withApp { app in
            let req = Request(
                application: app,
                method: .get,
                url: URI(string: "https://vapor.codes"),
                headersNoUpdate: [.contentType: "application/json"],
                collectedBody: ByteBuffer(string: #"{"badJson: "Key doesn't have a trailing quote"}"#),
                on: app.eventLoopGroup.any()
            )

            struct DecodeModel: Content {
                let badJson: String
            }
            #expect(performing: {
                try req.content.decode(DecodeModel.self)
            }, throws: { error in
                return (error as? any AbortError)?.reason.contains(#"Data corrupted at path ''. The given data was not valid JSON"#) ?? false
            })
        }
    }

    @Test("Test ValueNotFoundError")
    func testValueNotFoundError() async throws {
        try await withApp { app in
            let req = Request(application: app, on: app.eventLoopGroup.any())
            try req.content.encode([
                "items": ["1"]
            ], as: .json)

            struct DecodeModel: Content {
                struct Item: Content {
                    init(from decoder: any Decoder) throws {
                        var container = try decoder.unkeyedContainer()
                        _ = try container.decode(String.self)
                        _ = try container.decode(String.self)
                        fatalError()
                    }
                }

                let items: Item
            }
            #expect(performing: {
                try req.content.decode(DecodeModel.self)
            }, throws: { error in
                return (error as? any AbortError)?.reason ==
                #"No value found (expected type 'String') at path 'items.Index 1'. Unkeyed container is at end."#
            })
        }
    }

    @Test("Test Type Mismatch Error")
    func testTypeMismatchError() async throws {
        try await withApp { app in
            let req = Request(application: app, on: app.eventLoopGroup.any())
            try req.content.encode([
                "item": [
                    "title": "The title"
                ]
            ], as: .json)

            struct DecodeModel: Content {
                struct Item: Content {
                    let title: Int
                }

                let item: Item
            }
            #expect(performing: {
                try req.content.decode(DecodeModel.self)
            }, throws: { error in
                (error as? any AbortError)?.reason.contains(#"Value was not of type 'Int' at path 'item.title'. Expected to decode Int but found a string"#) ?? false
            })
        }
    }

    @Test("Test Plaintext Decode")
    func testPlaintextDecode() async throws {
        try await withApp { app in
            let data = "255"
            app.routes.get("plaintext") { _ -> Response in
                let res = Response()
                try res.content.encode(data, as: .plainText)
                return res
            }

            app.routes.get("empty-plaintext") { _ -> Response in
                let res = Response()
                try res.content.encode("", as: .plainText)
                return res
            }

            try await app.testing().test(.get, "/plaintext") { res throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode(UInt8.self) == 255)
                #expect(try res.content.decode(String.self) == "255")
            }

            try await app.testing().test(.get, "/empty-plaintext") { res throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode(String.self) == "")
            }
        }
    }

    @Test("Test Plaintext Decoder Doesn't Crash")
    func testPlaintextDecoderDoesntCrash() async throws {
        struct WrongType: Content {
            let example: String
        }

        try await withApp { app in
            app.routes.post("plaintext") { req -> String in
                _ = try req.content.decode(WrongType.self)
                return "OK"
            }

            let body = """
        {
          "example": "example"
        }
        """

            let byteBuffer = ByteBuffer(string: body)
            var headers = HTTPFields()
            headers[.contentType] = "text/plain"

            try await app.testing().test(.post, "/plaintext", headers: headers, body: byteBuffer) { res in
                // This should return a 400 Bad Request and not crash
                #expect(res.status == .badRequest)
            }
        }
    }

    @Test("Test Content Is Bool")
    func testContentIsBool() async throws {
        try await withApp { app in
            app.routes.get("success") { _ in
                true
            }

            try await app.testing().test(.get, "/success") { res throws in
                #expect(try res.content.decode(Bool.self) == true)
            }
        }
    }

    @Test("Test that JSON decoding in body works")
    func jsonDecodeContent() async throws {
        struct Message: Content {
            let name: String
        }

        try await withApp { app in
            app.routes.post("json") { req in
                let body = try req.content.decode(Message.self)
                return body.name
            }

            try await app.testing(method: .running).test(.post, "/json", beforeRequest: { req in
                try req.content.encode(Message(name: "Vapor"))
            }) { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "Vapor")
            }
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

private struct JsonApiContent: Content {
    struct Meta: Codable {}

    var data: [String]
    var meta = Meta()
}
