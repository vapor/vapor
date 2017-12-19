import Async
import Dispatch
import Leaf
import Service
import XCTest

class LeafTests: XCTestCase {
    var renderer: LeafRenderer!
    var queue: Worker!

    override func setUp() {
        self.queue = DispatchEventLoop(label: "codes.vapor.leaf.test")
        self.renderer = LeafRenderer.makeTestRenderer(worker: queue)
    }

    func testRaw() throws {
        let template = "Hello!"
        try XCTAssertEqual(renderer.render(template, context: .null).blockingAwait(), "Hello!")
    }

    func testPrint() throws {
        let template = "Hello, #(name)!"
        let data = LeafData.dictionary(["name": .string("Tanner")])
        try XCTAssertEqual(renderer.render(template, context: data.context).blockingAwait(), "Hello, Tanner!")
    }

    func testConstant() throws {
        let template = "<h1>#(42)</h1>"
        try XCTAssertEqual(renderer.render(template, context: .null).blockingAwait(), "<h1>42</h1>")
    }

    func testInterpolated() throws {
        let template = """
        <p>#("foo: #(foo)")</p>
        """
        let data = LeafData.dictionary(["foo": .string("bar")])
        try XCTAssertEqual(renderer.render(template, context: data.context).blockingAwait(), "<p>foo: bar</p>")
    }

    func testNested() throws {
        let template = """
        <p>#(embed(foo))</p>
        """
        let data = LeafData.dictionary(["foo": .string("bar")])
        try XCTAssertEqual(renderer.render(template, context: data.context).blockingAwait(), "<p>Test file name: &quot;/bar.leaf&quot;</p>")
    }

    func testExpression() throws {
        let template = "#(age > 99)"

        let young = LeafData.dictionary(["age": .int(21)])
        let old = LeafData.dictionary(["age": .int(150)])
        try XCTAssertEqual(renderer.render(template, context: young.context).blockingAwait(), "false")
        try XCTAssertEqual(renderer.render(template, context: old.context).blockingAwait(), "true")
    }

    func testBody() throws {
        let template = """
        #if(show) {hi}
        """
        let noShow = LeafData.dictionary(["show": .bool(false)])
        let yesShow = LeafData.dictionary(["show": .bool(true)])
        try XCTAssertEqual(renderer.render(template, context: noShow.context).blockingAwait(), "")
        try XCTAssertEqual(renderer.render(template, context: yesShow.context).blockingAwait(), "hi")
    }

    func testRuntime() throws {
        // FIXME: need to run var/exports first and in order
        let template = """
            #set("foo", "bar")
            Runtime: #(foo)
        """

        let res = try renderer.render(template, context: .null).blockingAwait()
        print(res)
        XCTAssert(res.contains("Runtime: bar"))
    }

    func testEmbed() throws {
        let template = """
            #embed("hello")
        """
        try XCTAssert(renderer.render(template, context: .null).blockingAwait().contains("hello.leaf"))
    }

    func testError() throws {
        do {
            let template = "#if() { }"
            _ = try renderer.render(template, context: .null).blockingAwait()
        } catch {
            print("\(error)")
        }

        do {
            let template = """
            Fine
            ##bad()
            Good
            """
            _ = try renderer.render(template, context: .null).blockingAwait()
        } catch {
            print("\(error)")
        }

        renderer.render(path: "##()", context: .null).do { data in
            print(data)
            // FIXME: check for error
        }.catch { error in
            print("\(error)")
        }

        do {
            _ = try renderer.render("#if(1 == /)", context: .null).blockingAwait()
        } catch {
            print("\(error)")
        }
    }

    func testChained() throws {
        let template = """
        #ifElse(false) {

        } ##ifElse(false) {

        } ##ifElse(true) {It works!}
        """
        try XCTAssertEqual(renderer.render(template, context: .null).blockingAwait(), "It works!")
    }

    func testForSugar() throws {
        let template = """
        <p>
            <ul>
                #for(name in names) {
                    <li>#(name)</li>
                }
            </ul>
        </p>
        """

        let context = LeafData.dictionary([
            "names": .array([
                .string("Vapor"), .string("Leaf"), .string("Bits")
            ])
        ])

        let expect = """
        <p>
            <ul>
                <li>Vapor</li>
                <li>Leaf</li>
                <li>Bits</li>
            </ul>
        </p>
        """
        try XCTAssertEqual(renderer.render(template, context: context.context).blockingAwait(), expect)
    }

    func testIfSugar() throws {
        let template = """
        #if(false) {Bad} else if (true) {Good} else {Bad}
        """
        try XCTAssertEqual(renderer.render(template, context: .null).blockingAwait(), "Good")
    }

    func testCommentSugar() throws {
        let template = """
        #("foo")
        #// this is a comment!
        bar
        """

        let multilineTemplate = """
        #("foo")
        #/*
            this is a comment!
        */
        bar
        """
        try XCTAssertEqual(renderer.render(template, context: .null).blockingAwait(), "foobar")
        try XCTAssertEqual(renderer.render(multilineTemplate, context: .null).blockingAwait(), "foo\nbar")
    }

    func testHashtag() throws {
        let template = """
        #("hi") #thisIsNotATag...
        """
        try XCTAssertEqual(renderer.render(template, context: .null).blockingAwait(), "hi #thisIsNotATag...")
    }

    func testNot() throws {
        let template = """
        #if(!false) {Good} #if(!true) {Bad}
        """

        try XCTAssertEqual(renderer.render(template, context: .null).blockingAwait(), "Good")
    }

    func testFuture() throws {
        let template = """
        #if(false) {
            #(foo)
        }
        """

        var didAccess = false
        let context = LeafData.dictionary([
            "foo": .lazy({
                didAccess = true
                return .string("hi")
            })
        ]).context

        try XCTAssertEqual(renderer.render(template, context: context).blockingAwait(), "")
        XCTAssertEqual(didAccess, false)
    }

    func testNestedBodies() throws {
        let template = """
        #if(true) {#if(true) {Hello\\}}}
        """
        try XCTAssertEqual(renderer.render(template, context: .null).blockingAwait(), "Hello}")
    }

    func testDotSyntax() throws {
        let template = """
        #if(user.isAdmin) {Hello, #(user.name)!}
        """

        let context = LeafData.dictionary([
            "user": .dictionary([
                "isAdmin": .bool(true),
                "name": .string("Tanner")
            ])
        ]).context
        try XCTAssertEqual(renderer.render(template, context: context).blockingAwait(), "Hello, Tanner!")
    }

    func testEqual() throws {
        let template = """
        #if(user.id == 42) {User 42!} #if(user.id != 42) {Shouldn't show up}
        """

        let context = LeafData.dictionary([
            "user": .dictionary([
                "id": .int(42),
                "name": .string("Tanner")
            ])
        ]).context
        try XCTAssertEqual(renderer.render(template, context: context).blockingAwait(), "User 42!")
    }

    func testEscapeExtraneousBody() throws {
        let template = """
        extension #("User") \\{

        }
        """
        let expected = """
        extension User {

        }
        """
        try XCTAssertEqual(renderer.render(template, context: .null).blockingAwait(), expected)
    }


    func testEscapeTag() throws {
        let template = """
        #("foo") \\#("bar")
        """
        let expected = """
        foo #("bar")
        """
        try XCTAssertEqual(renderer.render(template, context: .null).blockingAwait(), expected)
    }

    func testIndentationCorrection() throws {
        let template = """
        <p>
            <ul>
                #for(item in items) {
                    #if(true) {
                        <li>#(item)</li>
                        <br>
                    }
                }
            </ul>
        </p>
        """

        let expected = """
        <p>
            <ul>
                <li>foo</li>
                <br>
                <li>bar</li>
                <br>
                <li>baz</li>
                <br>
            </ul>
        </p>
        """

        let context: LeafData = .dictionary([
            "items": .array([.string("foo"), .string("bar"), .string("baz")])
        ])

        try XCTAssertEqual(renderer.render(template, context: context.context).blockingAwait(), expected)
    }

    func testAsyncExport() throws {
        let preloaded = PreloadedFiles()

        preloaded.files["/template.leaf"] = """
        Content: #get(content)
        """.data(using: .utf8)!

        preloaded.files["/nested.leaf"] = """
        Nested!
        """.data(using: .utf8)!

        let template = """
        #set("content") {<p>#embed("nested")</p>}
        #embed("template")
        """

        let expected = """
        Content: <p>Nested!</p>
        """

        let config = LeafConfig { _ in
            return preloaded
        }
        let renderer = LeafRenderer(config: config, on: queue)
        try XCTAssertEqual(renderer.render(template, context: .null).blockingAwait(), expected)
    }

    func testService() throws {
        var services = Services()
        try services.provider(LeafProvider())

        services.register { container in
            return LeafConfig(tags: defaultTags, viewsDir: "/") { queue in
                TestFiles()
            }
        }

        let container = BasicContainer(config: Config(), environment: .development, services: services, on: queue)

        let view = try container.make(ViewRenderer.self, for: XCTest.self)

        struct TestContext: Encodable {
            var name = "test"
        }
        let rendered = try view.make(
            "foo", TestContext()
        ).blockingAwait()

        let expected = """
        Test file name: "/foo.leaf"
        """

        XCTAssertEqual(String(data: rendered.data, encoding: .utf8), expected)
    }

    func testCount() throws {
        let template = """
        count: #count(array)
        """
        let expected = """
        count: 4
        """
        let context = LeafData.dictionary(["array": .array([.null, .null, .null, .null])]).context
        try XCTAssertEqual(renderer.render(template, context: context).blockingAwait(), expected)
    }

    func testNestedSet() throws {
        let template = """
        #if(a) {
            #set("title") {A}
        }
        title: #get(title)
        """
        let expected = """

        title: A
        """

        let context = LeafData.dictionary(["a": .bool(true)]).context
        try XCTAssertEqual(renderer.render(template, context: context).blockingAwait(), expected)
    }

    static var allTests = [
        ("testPrint", testPrint),
        ("testConstant", testConstant),
        ("testInterpolated", testInterpolated),
        ("testNested", testNested),
        ("testExpression", testExpression),
        ("testBody", testBody),
        ("testRuntime", testRuntime),
        ("testEmbed", testEmbed),
        ("testChained", testChained),
        ("testIfSugar", testIfSugar),
        ("testCommentSugar", testCommentSugar),
        ("testHashtag", testHashtag),
        ("testNot", testNot),
        ("testFuture", testFuture),
        ("testNestedBodies", testNestedBodies),
        ("testDotSyntax", testDotSyntax),
        ("testEqual", testEqual),
        ("testEscapeExtraneousBody", testEscapeExtraneousBody),
        ("testEscapeTag", testEscapeTag),
        ("testIndentationCorrection", testIndentationCorrection),
        ("testAsyncExport", testAsyncExport),
        ("testService", testService),
        ("testCount", testCount),
        ("testNestedSet", testNestedSet),
    ]
}

extension LeafData {
    var context: LeafContext { return LeafContext(data: self) }
}

extension LeafContext {
    static var null: LeafContext { return LeafContext(data: .null) }
}
