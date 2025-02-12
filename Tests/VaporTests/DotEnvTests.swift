@testable import Vapor
import NIOPosix
import NIOCore
import Testing
import VaporTesting

@Suite("DotEnv Tests")
struct DotEnvTests {
    @Test("Test Reading a File")
    func testReadFile() async throws {
        let folder = #filePath.split(separator: "/").dropLast().joined(separator: "/")
        let path = "/" + folder + "/Utilities/test.env"
        let file = try await DotEnvFile.read(path: path)
        let test = file.lines.map { $0.description }.joined(separator: "\n")
        #expect(test == """
        NODE_ENV=development
        BASIC=basic
        AFTER_LINE=after_line
        UNDEFINED_EXPAND=$TOTALLY_UNDEFINED_ENV_KEY
        EMPTY=
        SINGLE_QUOTES=single_quotes
        DOUBLE_QUOTES=double_quotes
        EXPAND_NEWLINES=expand\nnewlines
        DONT_EXPAND_NEWLINES_1=dontexpand\\nnewlines
        DONT_EXPAND_NEWLINES_2=dontexpand\\nnewlines
        EQUAL_SIGNS=equals==
        RETAIN_INNER_QUOTES={"foo": "bar"}
        RETAIN_INNER_QUOTES_AS_STRING={"foo": "bar"}
        INCLUDE_SPACE=some spaced out string
        USERNAME=therealnerdybeast@example.tld
        """)
    }

    @Test("Test Parsing works without a trailing newline")
    func testNoTrailingNewline() throws {
        let env = "FOO=bar\nBAR=baz"
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        buffer.writeString(env)
        var parser = DotEnvFile.Parser(source: buffer)
        let lines = parser.parse()
        #expect(lines == [
            .init(key: "FOO", value: "bar"),
            .init(key: "BAR", value: "baz"),
        ])
    }

    @Test("Test Parsing comments")
    func testCommentWithNoTrailingNewline() throws {
        let env = "FOO=bar\n#BAR=baz"
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        buffer.writeString(env)
        var parser = DotEnvFile.Parser(source: buffer)
        let lines = parser.parse()
        #expect(lines == [
            .init(key: "FOO", value: "bar")
        ])
    }
}
