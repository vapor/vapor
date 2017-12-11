import XCTest
@testable import Console

/// - Note: While it would have been possible, even easy,
/// to construct a power set over the possible foreground
/// and background color combinations and test every single
/// one, it would've been overkill - not to mention the
/// algorithm needed to construct the test cases would be
/// a painstaking duplication of the exact code the test
/// is supposed to be testing, negating its already
/// minimal usefulness.
class TerminalTests: XCTestCase {
    
    func testForegroundColorizeLogic() throws {
        XCTAssertEqual("TEST".terminalColorize(.black),             "\u{001b}[0;30mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.brightBlack),       "\u{001b}[0;90mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.boldBlack),         "\u{001b}[1;30mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.boldBrightBlack),   "\u{001b}[1;90mTEST\u{001b}[0m")

        XCTAssertEqual("TEST".terminalColorize(.red),               "\u{001b}[0;31mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.brightRed),         "\u{001b}[0;91mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.boldRed),           "\u{001b}[1;31mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.boldBrightRed),     "\u{001b}[1;91mTEST\u{001b}[0m")

        XCTAssertEqual("TEST".terminalColorize(.green),             "\u{001b}[0;32mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.brightGreen),       "\u{001b}[0;92mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.boldGreen),         "\u{001b}[1;32mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.boldBrightGreen),   "\u{001b}[1;92mTEST\u{001b}[0m")

        XCTAssertEqual("TEST".terminalColorize(.yellow),            "\u{001b}[0;33mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.brightYellow),      "\u{001b}[0;93mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.boldYellow),        "\u{001b}[1;33mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.boldBrightYellow),  "\u{001b}[1;93mTEST\u{001b}[0m")

        XCTAssertEqual("TEST".terminalColorize(.blue),              "\u{001b}[0;34mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.brightBlue),        "\u{001b}[0;94mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.boldBlue),          "\u{001b}[1;34mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.boldBrightBlue),    "\u{001b}[1;94mTEST\u{001b}[0m")

        XCTAssertEqual("TEST".terminalColorize(.magenta),           "\u{001b}[0;35mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.brightMagenta),     "\u{001b}[0;95mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.boldMagenta),       "\u{001b}[1;35mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.boldBrightMagenta), "\u{001b}[1;95mTEST\u{001b}[0m")

        XCTAssertEqual("TEST".terminalColorize(.cyan),              "\u{001b}[0;36mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.brightCyan),        "\u{001b}[0;96mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.boldCyan),          "\u{001b}[1;36mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.boldBrightCyan),    "\u{001b}[1;96mTEST\u{001b}[0m")

        XCTAssertEqual("TEST".terminalColorize(.white),             "\u{001b}[0;37mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.brightWhite),       "\u{001b}[0;97mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.boldWhite),         "\u{001b}[1;37mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.boldBrightWhite),   "\u{001b}[1;97mTEST\u{001b}[0m")
    }
    
    func testBackgroundColorizeLogic() throws {
        XCTAssertEqual("TEST".terminalColorize(.white, background: .black),             "\u{001b}[0;37;40mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.white, background: .brightBlack),       "\u{001b}[0;37;100mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.white, background: .boldBlack),         "\u{001b}[0;37;40mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.white, background: .boldBrightBlack),   "\u{001b}[0;37;100mTEST\u{001b}[0m")

        XCTAssertEqual("TEST".terminalColorize(.white, background: .red),               "\u{001b}[0;37;41mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.white, background: .brightRed),         "\u{001b}[0;37;101mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.white, background: .boldRed),           "\u{001b}[0;37;41mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.white, background: .boldBrightRed),     "\u{001b}[0;37;101mTEST\u{001b}[0m")

        XCTAssertEqual("TEST".terminalColorize(.white, background: .green),             "\u{001b}[0;37;42mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.white, background: .brightGreen),       "\u{001b}[0;37;102mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.white, background: .boldGreen),         "\u{001b}[0;37;42mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.white, background: .boldBrightGreen),   "\u{001b}[0;37;102mTEST\u{001b}[0m")

        XCTAssertEqual("TEST".terminalColorize(.white, background: .yellow),            "\u{001b}[0;37;43mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.white, background: .brightYellow),      "\u{001b}[0;37;103mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.white, background: .boldYellow),        "\u{001b}[0;37;43mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.white, background: .boldBrightYellow),  "\u{001b}[0;37;103mTEST\u{001b}[0m")

        XCTAssertEqual("TEST".terminalColorize(.white, background: .blue),              "\u{001b}[0;37;44mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.white, background: .brightBlue),        "\u{001b}[0;37;104mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.white, background: .boldBlue),          "\u{001b}[0;37;44mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.white, background: .boldBrightBlue),    "\u{001b}[0;37;104mTEST\u{001b}[0m")

        XCTAssertEqual("TEST".terminalColorize(.white, background: .magenta),           "\u{001b}[0;37;45mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.white, background: .brightMagenta),     "\u{001b}[0;37;105mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.white, background: .boldMagenta),       "\u{001b}[0;37;45mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.white, background: .boldBrightMagenta), "\u{001b}[0;37;105mTEST\u{001b}[0m")

        XCTAssertEqual("TEST".terminalColorize(.white, background: .cyan),              "\u{001b}[0;37;46mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.white, background: .brightCyan),        "\u{001b}[0;37;106mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.white, background: .boldCyan),          "\u{001b}[0;37;46mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.white, background: .boldBrightCyan),    "\u{001b}[0;37;106mTEST\u{001b}[0m")

        XCTAssertEqual("TEST".terminalColorize(.white, background: .white),             "\u{001b}[0;37;47mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.white, background: .brightWhite),       "\u{001b}[0;37;107mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.white, background: .boldWhite),         "\u{001b}[0;37;47mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalColorize(.white, background: .boldBrightWhite),   "\u{001b}[0;37;107mTEST\u{001b}[0m")
    }
    
    static let allTests = [
        ("testForegroundColorizeLogic", testForegroundColorizeLogic),
        ("testBackgroundColorizeLogic", testBackgroundColorizeLogic),
    ]
}

