import Vapor
import NIOCore
import HTTPTypes
import Testing
import VaporTesting
import Foundation

@Suite("Query Tests")
struct QueryTests {

    @Test("Test Query")
    func testQuery() async throws {
        try await withApp { app throws in
            let request = Request(application: app)
            request.headers.contentType = .json
            request.url.path = "/foo"
            request.url.query = "hello=world"
            #expect(try request.query.get(String.self, at: "hello") == "world")
        }
    }

    @Test("Test Query as Array")
    func testQueryAsArray() async throws {
        try await withApp { app throws in
            let request = Request(application: app)
            request.headers.contentType = .json
            request.url.path = "/foo"
            request.url.query = "hello=world&hello[]=you"
            #expect(try request.query.get([String].self, at: "hello") == ["world", "you"])
            #expect(try request.query.get([String].self, at: "goodbye") == [])
        }
    }

    @Test("Test Wrapped Single Value Query Decoding", .bug("https://github.com/vapor/vapor/pull/2163"))
    func testWrappedSingleValueQueryDecoding() async throws {
        try await withApp { app throws in
            let request = Request(application: app)
            request.headers.contentType = .json
            request.url.path = "/foo"
            request.url.query = ""
            
            // Think of property wrappers, or MongoKitten's ObjectId
            struct StringWrapper: Decodable {
                let string: String
                
                init(from decoder: any Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    string = try container.decode(String.self)
                }
            }

            #expect(throws: DecodingError.self) {
                try request.query.get(StringWrapper.self, at: "hello")
            }
        }
    }

    @Test("Test Does Not Crash with an Array with Percent Encoding")
    func testNotCrashingArrayWithPercentEncoding() async throws {
        try await withApp { app throws in
            let request = Request(application: app)
            request.headers.contentType = .json
            request.url.path = "/"
            request.url.query = "emailsToSearch%5B%5D=xyz"
            let parsed = try request.query.get([String].self, at: "emailsToSearch")
            #expect(parsed == ["xyz"])
        }
    }

    @Test("Test Query Get")
    func testQueryGet() async throws {
        try await withApp { app throws in
            let request1 = Request(
                application: app,
                method: .get,
                url: .init(string: "/path?foo=a"),
                on: app.eventLoopGroup.next()
            )

            #expect(try request1.query.get(String.self, at: "foo") == "a")
            let error1 = #expect(throws: (any Error).self) {
                try request1.query.get(Int.self, at: "foo")
            }
            if case .typeMismatch(_, let context) = error1 as? DecodingError {
                #expect(context.debugDescription == "Data found at 'foo' was not Int")
            } else {
                Issue.record("Caught error \"\(error1.debugDescription)\", but not the expected: \"DecodingError.typeMismatch\"")
            }

            let error2 = #expect(throws: (any Error).self) {
                try request1.query.get(String.self, at: "bar")
            }
            if case .valueNotFound(_, let context) = error2 as? DecodingError {
                #expect(context.debugDescription == "No String was found at 'bar'")
            } else {
                Issue.record("Caught error \"\(error2.debugDescription)\", but not the expected: \"DecodingError.valueNotFound\"")
            }

            #expect(request1.query[String.self, at: "foo"] == "a")
            #expect(request1.query[String.self, at: "bar"] == nil)

            let request2 = Request(
                application: app,
                method: .get,
                url: .init(string: "/path"),
                on: app.eventLoopGroup.next()
            )
            let error3 = #expect(throws: DecodingError.self) {
                try request1.query.get(Int.self, at: "bar")
            }
            #expect(error3?.status == .badRequest)
            #expect(request2.query[String.self, at: "foo"] == nil)
        }
    }

    @Test("Test Query String Running", .bug("https://github.com/vapor/vapor/issues/1537"))
    func testQueryStringRunning() async throws {
        try await withApp { app throws in
            app.routes.get("todos") { req in
                return "hi"
            }

            try await app.testing().test(.get, "/todos?a=b") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "hi")
            }
        }
    }

    @Test("Test URL Encoded Form Decode Query")
    func testURLEncodedFormDecodeQuery() async throws {
        struct User: Content {
            var name: String
            var age: Int
            var luckyNumbers: [Int]
            var pet: Pet
        }

        struct Pet: Content {
            var name: String
            var age: Int
        }

        try await withApp { app throws in
            app.get("urlencodedform") { req -> HTTPStatus in
                let foo = try req.query.decode(User.self)
                #expect(foo.name == "Vapor")
                #expect(foo.age == 3)
                #expect(foo.luckyNumbers == [5, 7])
                #expect(foo.pet.name == "Fido")
                #expect(foo.pet.age == 3)
                return .ok
            }

            let data = "name=Vapor&age=3&luckyNumbers[]=5&luckyNumbers[]=7&pet[name]=Fido&pet[age]=3"
            try await app.testing().test(.get, "/urlencodedform?\(data)") { res in
                #expect(res.status.code == 200)
            }
        }
    }

    @Test("Test URL Percent Encoded Form Decode Query")
    func testURLPercentEncodedFormDecodeQuery() async throws {
        struct User: Content {
            var name: String
            var age: Int
            var luckyNumbers: [Int]
            var pet: Pet
        }

        struct Pet: Content {
            var name: String
            var age: Int
        }

        try await withApp { app throws in
            app.get("urlencodedform") { req -> HTTPStatus in
                let foo = try req.query.decode(User.self)
                #expect(foo.name == "Vapor")
                #expect(foo.age == 3)
                #expect(foo.luckyNumbers == [5, 7])
                #expect(foo.pet.name == "Fido")
                #expect(foo.pet.age == 3)
                return .ok
            }

            let data = "name=Vapor&age=3&luckyNumbers[]=5&luckyNumbers[]=7&pet[name]=Fido&pet[age]=3".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            try await app.testing().test(.get, "/urlencodedform?\(data)") { res in
                #expect(res.status.code == 200)
            }
        }
    }

    @Test("Test Custom Encode")
    func testCustomEncode() async throws {
        try await withApp { app throws in
            app.get("custom-encode") { req -> Response in
                let res = Response(status: .ok)
                let jsonEncoder = JSONEncoder()
                jsonEncoder.outputFormatting = .prettyPrinted
                try res.content.encode(["hello": "world"], using: jsonEncoder)
                return res
            }

            try await app.testing().test(.get, "/custom-encode") { res in
                #expect(res.body.string == """
            {
              "hello" : "world"
            }
            """)
            }
        }
    }

    @Test("Test Content Decoding Does Not Hang", .bug("https://github.com/vapor/vapor/issues/1609"))
    func testGH1609() async throws {
        struct DecodeFail: Content {
            var here: String
            var missing: String
        }

        try await withApp { app throws in
            app.post("decode-fail") { req -> String in
                _ = try await req.content.decode(DecodeFail.self)
                return "ok"
            }

            var body = ByteBufferAllocator().buffer(capacity: 0)
            body.writeString(#"{"here":"hi"}"#)
            var headers = HTTPFields()
            headers[.contentLength] = body.readableBytes.description
            headers.contentType = .json

            try await app.testing().test(.post, "/decode-fail", headers: headers, body: body) { res in
                #expect(res.status == .badRequest)
                #expect(res.body.string.contains("missing"))
            }
        }
    }

    @Test("Test Request Query String Percent Encoding", .bug("https://github.com/vapor/vapor/issues/1687"))
    func testRequestQueryStringPercentEncoding() async throws {
        struct TestQueryStringContainer: Content {
            var name: String
        }
        try await withApp { app in
            let req = Request(application: app)
            try req.query.encode(TestQueryStringContainer(name: "Vapor Test"))
            #expect(req.url.query == "name=Vapor%20Test")
        }
    }

    @Test("Test Query Key Decoding", .bug("https://github.com/vapor/vapor/issues/2383"))
    func testQueryKeyDecoding() throws {
        struct Test: Codable, Equatable {
            struct Page: Codable, Equatable {
                var offset: Int
                var limit: Int
            }
            let page: Page
            struct Filter: Codable, Equatable {
                var ids: [String]
            }
            let filter: Filter
        }

        let query = "page[offset]=0&page[limit]=50&filter[ids]=auth0,abc123"
        let a = try URLEncodedFormDecoder().decode(Test.self, from: query)
        #expect(a.page.offset == 0)
        #expect(a.page.limit == 50)
        #expect(a.filter.ids == ["auth0", "abc123"])
        let b = try URLEncodedFormDecoder().decode(Test.self, from: query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)
        #expect(a == b)
    }

    @Test("Test Optional Get")
    func testOptionalGet() async throws {
        try await withApp { app in
            let req = Request(
                application: app,
                method: .get,
                url: URI(string: "/"),
                on: app.eventLoopGroup.next()
            )
            req.url = .init(path: "/foo?bar=baz")
            let page1 = try req.query.get(Int?.self, at: "page")
            #expect(page1 == nil)
            req.url = .init(path: "/foo?bar=baz&page=1")
            let page2 = try req.query.get(Int?.self, at: "page")
            #expect(page2 == 1)
            req.url = .init(path: "/foo?bar=baz&page=a")
            #expect(throws: DecodingError.self) {
                try req.query.get(Int?.self, at: "page")
            }
        }
    }

    @Test("Test Valueluss Param Get")
    func testValuelessParamGet() async throws {
        try await withApp { app throws in
            let req = Request(
                application: app,
                method: .get,
                url: URI(string: "/"),
                on: app.eventLoopGroup.next()
            )
            struct BarStruct : Content {
                let bar: Bool
            }
            struct OptionalBarStruct : Content {
                let bar: Bool?
                let baz: String?
            }

            req.url = .init(path: "/foo?bar")
            #expect(try req.query.get(Bool.self, at: "bar") == true)
            #expect(try req.query.decode(BarStruct.self).bar == true)
            #expect(try req.query.decode(OptionalBarStruct.self).bar == true)

            req.url = .init(path: "/foo?bar&baz=bop")
            #expect(try req.query.get(Bool.self, at: "bar"))
            #expect(try req.query.decode(BarStruct.self).bar)
            #expect(try req.query.decode(OptionalBarStruct.self).bar == true)

            req.url = .init(path: "/foo")
            #expect(try req.query.get(Bool.self, at: "bar") == false)
            #expect(try req.query.decode(BarStruct.self).bar == false)
            #expect(try req.query.decode(OptionalBarStruct.self).bar == nil)

            req.url = .init(path: "/foo?baz=bop")
            #expect(try req.query.get(Bool.self, at: "bar") == false)
            #expect(try req.query.decode(BarStruct.self).bar == false)
            #expect(try req.query.decode(OptionalBarStruct.self).bar == nil)
        }
    }

    @Test("Test Does Not Crash When Unkeyed Container Is At End")
    func testNotCrashingWhenUnkeyedContainerIsAtEnd() async throws {
        struct Query: Decodable {
            let closedRange: ClosedRange<Double>
        }
        
        try await withApp { app in
            let request = Request(application: app)
            request.headers.contentType = .json
            request.url.path = "/"
            request.url.query = "closedRange=1"

            let error = #expect(throws: (any Error).self) {
                try request.query.decode(Query.self)
            }
            if case .valueNotFound(_, let context) = error as? DecodingError {
                #expect(context.debugDescription == "Unkeyed container is at end.")
            } else {
                Issue.record("Caught error \"\(error.debugDescription)\", but not the expected: \"DecodingError.valueNotFound\"")
            }
        }
    }
}
