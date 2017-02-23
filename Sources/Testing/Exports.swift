public typealias OnFail = (String, StaticString, UInt) -> ()

public var onFail: OnFail = { message, file, line in
    print()
    print("❌ Set `Testing.onFail = XCTFail` to enable vapor testing errors to fail Xcode and SPM tests.")
    print()
    print("    import Testing")
    print("    import XCTest")
    print()
    print("    class ExampleTests: XCTestCase {")
    print("        override func setUp() {")
    print("            Testing.onFail = XCTFail")
    print("        }")
    print("    }")
    print()
    fatalError("`Testing.onFail` must be set.")
}
