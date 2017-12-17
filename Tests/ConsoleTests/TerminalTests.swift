import XCTest
@testable import Console

class TerminalTests: XCTestCase {
    
    func testStylizeForeground() throws {
        XCTAssertEqual("TEST".terminalStylize(.init(color: .black)), "\u{001b}[0;30mTEST\u{001b}[0m")
    }
    
    func testStylizeBackground() throws {
        XCTAssertEqual("TEST".terminalStylize(.init(color: .white, background: .red)), "\u{001b}[0;37;41mTEST\u{001b}[0m")
    }
    
    func testStylizeBold() throws {
        XCTAssertEqual("TEST".terminalStylize(.init(color: .white, isBold: true)), "\u{001b}[0;1;37mTEST\u{001b}[0m")
    }

    func testStylizeOnlyBold() throws {
        XCTAssertEqual("TEST".terminalStylize(.init(color: nil, isBold: true)), "\u{001b}[0;1mTEST\u{001b}[0m")
    }

    func testStylizeAllAttrs() throws {
        XCTAssertEqual(
            "TEST".terminalStylize(.init(color: .brightWhite, background: .brightGreen, isBold: true)),
            "\u{001b}[0;1;97;102mTEST\u{001b}[0m"
        )
    }

    func testStylizePlain() throws {
        XCTAssertEqual("TEST".terminalStylize(.plain), "TEST")
    }

    func testStylizePaletteColor() throws {
        XCTAssertEqual("TEST".terminalStylize(.init(color: .palette(100))), "\u{001b}[0;38;5;100mTEST\u{001b}[0m")
        XCTAssertEqual("TEST".terminalStylize(.init(color: .white, background: .palette(100))), "\u{001b}[0;37;48;5;100mTEST\u{001b}[0m")
    }

    func testStylizeRGBColor() throws {
        XCTAssertEqual(
        	"TEST".terminalStylize(.init(color: .custom(r: 100, g: 100, b: 100))),
            "\u{001b}[0;38;2;100;100;100mTEST\u{001b}[0m"
        )
        XCTAssertEqual(
            "TEST".terminalStylize(.init(color: .white, background: .custom(r: 100, g: 100, b: 100))),
            "\u{001b}[0;37;48;2;100;100;100mTEST\u{001b}[0m"
        )
    }

    static let allTests = [
        ("testStylizeForeground", testStylizeForeground),
        ("testStylizeBackground", testStylizeBackground),
        ("testStylizeBold", testStylizeBold),
        ("testStylizeOnlyBold", testStylizeOnlyBold),
        ("testStylizeAllAttrs", testStylizeAllAttrs),
        ("testStylizePlain", testStylizePlain),
        ("testStylizePaletteColor", testStylizePaletteColor),
        ("testStylizeRGBColor", testStylizeRGBColor),
    ]
}

