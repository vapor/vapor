import NIOCore
import HTTPTypes
import Vapor
import Testing
import VaporTesting
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import RoutingKit

@Suite("Content Tests")
struct ContentTests {

    @Test("Test Content")
    func testContent() async throws {
        try await withApp { app throws in
            var request = Request(
                application: app,
                collectedBody: .init(string: #"{"hello": "world"}"#)
            )
            request.headers.contentType = .json
            #expect(try await request.content.get(at: "hello") == "world")
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
            var request = Request(
                application: app,
                collectedBody: .init(string: complexJSON)
            )
            request.headers.contentType = .json
            #expect(try await request.content.get(at: "batters", "batter", 1, "type") == "Chocolate")
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
                try #expect(await res.body.requireString().contains(#"Value was not of type 'Int' at path 'bar'. Expected to decode Int but found a string"#))
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
                var res = Response()
                try res.content.encode(FooContent())
                try res.content.encode(FooContent(), as: .json)
                try res.content.encode(FooEncodable(), as: .json)
                return res
            }

            try await app.testing().test(.get, "/encode") { res in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString().contains("hi"))
            }
        }
    }

    @Test("Encoding a Request's content writes back both the body and the content type")
    func testRequestContentContainerEncodeWritesBack() async throws {
        struct FooContent: Content, Equatable {
            var message: String = "hi"
        }

        try await withApp { app in
            // `content` vends a value, so `encode` mutates a copy and the setter on
            // ``Request/content`` is what puts the result back on the request. Both halves are
            // asserted deliberately: a container that reached the body through a reference but the
            // headers through a copy would still land the body while silently dropping the content
            // type the encoder sets, leaving the request undecodable for a non-obvious reason.
            var request = Request(application: app)
            try request.content.encode(FooContent())

            #expect(request.headers.contentType == .json)
            #expect(request.body.string == #"{"message":"hi"}"#)
            #expect(try await request.content.decode(FooContent.self) == FooContent())

            // Same again for the overload taking an explicit content type.
            var explicit = Request(application: app)
            try explicit.content.encode(FooContent(), as: .json)

            #expect(explicit.headers.contentType == .json)
            #expect(explicit.body.string == #"{"message":"hi"}"#)
            #expect(try await explicit.content.decode(FooContent.self) == FooContent())
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
                #expect(try await req.content.decode(FooContent.self) == FooContent())
                #expect(try await req.content.decode(FooDecodable.self, as: .json) == FooDecodable())
                return "decoded!"
            }

            try await app.testing().test(.post, "/decode") { req in
                try req.content.encode(FooContent())
            } afterResponse: { res in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString().contains("decoded!"))
            }

            app.routes.post("decode-bad-header") { req async throws -> String in
                #expect(req.headers.contentType == .audio)
                await #expect(performing: {
                    try await req.content.decode(FooContent.self)
                }, throws: { error in
                    (error as? Abort)?.status == .unsupportedMediaType
                })
                #expect(try await req.content.decode(FooDecodable.self, as: .json) == FooDecodable())
                return "decoded!"
            }

            try await app.testing().test(.post, "/decode-bad-header") { req in
                try req.content.encode(FooContent())
                req.headers.contentType = .audio
            } afterResponse: { res in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString().contains("decoded!"))
            }
        }
    }

    #if Multipart
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
                let decoded = try await req.content.decode(User.self)
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
                let decoded = try await req.content.decode(User.self)
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
                let decoded = try await req.content.decode(User.self)
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
                let decoded = try await req.content.decode(User.self)
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
                try #expect(await res.body.requireString().contains("Content-Disposition: form-data; name=\"name\""))
                try #expect(await res.body.requireString().contains("--\(boundary)"))
                try #expect(await res.body.requireString().contains("filename=\"droplet.png\""))
                try #expect(await res.body.requireString().contains("name=\"image\""))
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
                try #expect(await res.body.requireString().contains("Content-Disposition: form-data; name=\"name\""))
                try #expect(await res.body.requireString().contains("--\(boundary)"))
                try #expect(await res.body.requireString().contains("filename=\"UTF-8\'\'%E5%A5%B9%E5%9C%A8%E5%90%83%E6%B0%B4%E6%9E%9C.png\""))
                try #expect(await res.body.requireString().contains("name=\"image\""))
            }
        }
    }

    @Test("Multipart File prefers header contentType", .bug("https://github.com/vapor/vapor/issues/2571"))
    func testMultipartFileContentTypeUsesHeader() async throws {
        // A file named "your-face.jpg" but with Content-Type: image/webp
        // The decoded File.contentType should be image/webp, not image/jpeg
        let data = """
        --123\r
        Content-Disposition: form-data; name="upload"; filename="your-face.jpg"\r
        Content-Type: image/webp\r
        \r
        1234\r
        --123--\r\n
        """

        struct Payload: Content {
            let upload: File
        }

        try await withApp { app in
            app.routes.get("multipart") { req -> String in
                let payload = try await req.content.decode(Payload.self)
                #expect(payload.upload.filename == "your-face.jpg")
                #expect(payload.upload.contentType == .webp)
                return "ok"
            }

            try await app.testing().test(.get, "/multipart", headers: [
                .contentType: "multipart/form-data; boundary=123"
            ], body: .init(string: data)) { res in
                #expect(res.status == .ok)
            }
        }
    }
    #endif

    @Test("Test URLEncoded Form Decode")
    func testURLEncodedFormDecode() async throws {
        struct User: Content {
            var name: String
            var age: Int
            var luckyNumbers: [Int]
        }

        try await withApp { app in
            app.get("urlencodedform") { req -> HTTPResponse.Status in
                let foo = try await req.content.decode(User.self)
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
                try #expect(await res.body.requireString().contains("luckyNumbers[]=5"))
                try #expect(await res.body.requireString().contains("luckyNumbers[]=7"))
                try #expect(await res.body.requireString().contains("age=3"))
                try #expect(await res.body.requireString().contains("name=Vapor"))
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
                try #expect(await res.body.requireString() == "PRESENT.application/json; charset=utf-8")
            }
        }
    }

    @Test("Test JSON Allows ContentType Override")
    func testJSONAllowsContentTypeOverride() async throws {
        // Me and my sadistic sense of humor.
        var contentConfiguration = ContentConfiguration.default()
        try contentConfiguration.use(decoder: contentConfiguration.requireDecoder(for: .json), for: .xml)
        try await withApp(services: .init(contentConfiguration: contentConfiguration)) { app in
            app.get("check") { (req: Request) -> String in
                "\(req.headers[.init("X-Test-Value")!] ?? "MISSING").\(req.headers[.contentType] ?? "?")"
            }

            try await app.testing().test(.get, "/check", headers: [
                .init("X-Test-Value")!: "PRESENT"
            ], beforeRequest: { req in
                try req.content.encode(["foo": "bar"], as: .json)
                req.headers.contentType = .xml
            }) { res in
                try #expect(await res.body.requireString() == "PRESENT.application/xml; charset=utf-8")
            }
        }
    }

    @Test("Assigning content from another response copies only the content")
    func testContentAssignmentCopiesOnlyContent() throws {
        struct FooContent: Content {
            var message: String = "hi"
        }

        var source = Response(status: .ok)
        try source.content.encode(FooContent())

        var destination = Response(status: .created)
        destination.headers[.xRequestId] = "abc123"
        destination.content = source.content

        // The content — body and the headers that describe it — comes across...
        #expect(destination.body.string == source.body.string)
        #expect(destination.headers.contentType == source.headers.contentType)
        #expect(destination.headers[.contentLength] == source.headers[.contentLength])
        // ...but the rest of the response is left alone.
        #expect(destination.status == .created)
    }

    @Test("Test Before Encode Content")
    func testBeforeEncodeContent() throws {
        let content = SampleContent()
        #expect(content.name == "old name")

        var response = Response(status: .ok)
        try response.content.encode(content)

        let body = try #require(response.body.string)
        #expect(body == #"{"name":"new name"}"#)
    }

    @Test("afterDecode runs for a Request's content")
    func testAfterDecodeOnRequest() async throws {
        var body = ByteBufferAllocator().buffer(capacity: 0)
        body.writeString(#"{"name": "before decode"}"#)

        try await withApp { app in
            var request = Request(
                application: app,
                collectedBody: body
            )

            request.headers.contentType = .json

            let content = try await request.content.decode(SampleContent.self)
            #expect(content.name == "new name after decode")
        }
    }

    @Test("afterDecode runs when decoding with an explicit content type")
    func testAfterDecodeWithExplicitContentType() async throws {
        // `decode(_:as:)` used to bind a `Content` type to the `Decodable` overload, which has no
        // way to know about the hook, so the value came back unprocessed.
        try await withApp { app in
            var request = Request(
                application: app,
                collectedBody: .init(string: #"{"name": "before decode"}"#)
            )
            request.headers.contentType = .json

            let content = try await request.content.decode(SampleContent.self, as: .json)
            #expect(content.name == "new name after decode")
        }
    }

    @Test("afterDecode runs for a Response's content")
    func testAfterDecodeOnResponse() async throws {
        var response = Response(status: .ok)
        response.headers.contentType = .json
        response.body = .init(string: #"{"name": "before decode"}"#)

        #expect(try await response.content.decode(SampleContent.self).name == "new name after decode")
        #expect(try await response.content.decode(SampleContent.self, as: .json).name == "new name after decode")
    }

    @Test("afterDecode runs for a ClientResponse's content, including a streaming body")
    func testAfterDecodeOnClientResponse() async throws {
        var headers = HTTPFields()
        headers.contentType = .json
        func response() -> ClientResponse {
            ClientResponse(
                status: .ok,
                headers: headers,
                body: .init(stream: { writer in try await writer.write(#"{"name": "before decode"}"#) })
            )
        }

        #expect(try await response().content.decode(SampleContent.self).name == "new name after decode")
        #expect(try await response().content.decode(SampleContent.self, as: .json).name == "new name after decode")
    }

    @Test("afterDecode runs for a TestingHTTPResponse's content")
    func testAfterDecodeOnTestingHTTPResponse() async throws {
        var headers = HTTPFields()
        headers.contentType = .json
        let response = TestingHTTPResponse(
            status: .ok,
            headers: headers,
            body: .init(string: #"{"name": "before decode"}"#),
            contentConfiguration: .default()
        )

        #expect(try await response.content.decode(SampleContent.self).name == "new name after decode")
        #expect(try await response.content.decode(SampleContent.self, as: .json).name == "new name after decode")
    }

    @Test("afterDecode runs for a ClientRequest's content")
    func testAfterDecodeOnClientRequest() async throws {
        var request = ClientRequest(method: .post, url: "/")
        try request.content.encode(SampleContent(), as: .json)

        #expect(try await request.content.decode(SampleContent.self).name == "new name after decode")
        #expect(try await request.content.decode(SampleContent.self, as: .json).name == "new name after decode")
    }

    @Test("Test Supports JSON API")
    func testSupportsJsonApi() async throws {
        var body = ByteBufferAllocator().buffer(capacity: 0)
        body.writeString(#"{"data": ["entity0", "entity1"], "meta": {}}"#)

        try await withApp { app in
            var request = Request(
                application: app,
                collectedBody: body
            )

            request.headers.contentType = .jsonAPI

            let content = try await request.content.decode(JsonApiContent.self)
            #expect(content.data == ["entity0", "entity1"])
        }
    }

    @Test("Test Query Hooks")
    func testQueryHooks() async throws {
        try await withApp { app in
            var request = Request(
                application: app,
                collectedBody: .init(string: "")
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
            var request = Request(
                application: app,
                collectedBody: .init(string: "")
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
            var req = Request(application: app)
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
            await #expect(performing: {
                try await req.content.decode(PostInput.self)
            }, throws: { error in
                return (error as? any AbortError)?.reason ==
                        #"No such key 'is_free' at path ''. No value associated with key CodingKeys(stringValue: "is_free", intValue: nil) ("is_free")."#
            })
        }
    }

    @Test("Test Data Corruption Error")
    func testDataCorruptionError() async throws {
        try await withApp { app in
            var req = Request(
                application: app,
                method: .get,
                url: URI(string: "https://vapor.codes"),
                collectedBody: ByteBuffer(string: #"{"badJson: "Key doesn't have a trailing quote"}"#)
            )
            req.headers.contentType = .json

            struct DecodeModel: Content {
                let badJson: String
            }
            await #expect(performing: {
                try await req.content.decode(DecodeModel.self)
            }, throws: { error in
                return (error as? any AbortError)?.reason.contains(#"Data corrupted at path ''. The given data was not valid JSON"#) ?? false
            })
        }
    }

    @Test("Test ValueNotFoundError")
    func testValueNotFoundError() async throws {
        try await withApp { app in
            var req = Request(application: app)
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
            await #expect(performing: {
                try await req.content.decode(DecodeModel.self)
            }, throws: { error in
                return (error as? any AbortError)?.reason ==
                #"No value found (expected type 'String') at path 'items.Index 1'. Unkeyed container is at end."#
            })
        }
    }

    @Test("Test Type Mismatch Error")
    func testTypeMismatchError() async throws {
        try await withApp { app in
            var req = Request(application: app)
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
            await #expect(performing: {
                try await req.content.decode(DecodeModel.self)
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
                var res = Response()
                try res.content.encode(data, as: .plainText)
                return res
            }

            app.routes.get("empty-plaintext") { _ -> Response in
                var res = Response()
                try res.content.encode("", as: .plainText)
                return res
            }

            try await app.testing().test(.get, "/plaintext") { res throws in
                #expect(res.status == .ok)
                #expect(try await res.content.decode(UInt8.self) == 255)
                #expect(try await res.content.decode(String.self) == "255")
            }

            try await app.testing().test(.get, "/empty-plaintext") { res throws in
                #expect(res.status == .ok)
                #expect(try await res.content.decode(String.self) == "")
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
                _ = try await req.content.decode(WrongType.self)
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
                #expect(try await res.content.decode(Bool.self) == true)
            }
        }
    }

    @Test("Test body hooked up in request with JSON decoding")
    func jsonDecodeContent() async throws {
        struct Message: Content {
            let name: String
        }

        try await withApp { app in
            app.routes.post("json") { req in
                let body = try await req.content.decode(Message.self)
                return body.name
            }

            try await app.testing(method: .running).test(.post, "/json", beforeRequest: { req in
                try req.content.encode(Message(name: "Vapor"))
            }) { res in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "Vapor")
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
