#if !os(Linux)
import Foundation

let generator = Generator(max: 5)
let code = generator.generate()

if Process.arguments.count < 2 {
    print("⚠️ IMPORTANT")
    print("To run the Generator, you must pass the $(SRCROOT)")
    print("as the first argument to the executable.")
    print("")
    print("This can be done using 'Edit Scheme'")
    print("")
    fatalError("$(SRCROOT) must be passed as a parameter")
}

let path = ProcessInfo.processInfo.arguments[1].replacingOccurrences(of: "XcodeProject", with: "")
let url = URL(fileURLWithPath: path + "/Sources/Vapor/Routing/Generated.swift")

do{
    let lines = code.characters.split(separator: "\n").count
    let functions = code.components(separatedBy: "func").count - 1

    // writing to disk
    try code.write(to: url, atomically: true, encoding: .utf8)
    print("✅ Code successfully generated.")
    print("Functions: \(functions)")
    print("Lines: \(lines)")
    print("Location: \(url)")
    print("Date: \(NSDate())")
} catch let error as NSError {
    print("Error writing generated file at \(url)")
    print(error.localizedDescription)
}
    
#else
    print("Linux not supported by generator.")
#endif

