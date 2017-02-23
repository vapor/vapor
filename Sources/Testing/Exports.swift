public typealias OnFail = (String, StaticString, UInt) -> ()

public var onFail: OnFail = { message, file, line in
    print("⚠️ Test failed: \(message)")
    print("File: \(file)")
    print("Line: \(line)")
    print("ℹ️ Set `Testing.onFail = XCTFail` in the setUp method to cause this error to fail Xcode and SPM tests.")
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
}
