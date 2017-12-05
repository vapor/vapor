import Command
import Console
import Core
import Foundation
import Leaf

public final class Generate: Command {
    /// See Command.arguments
    public var arguments: [Argument] = []

    /// See Command.options
    public var options: [Option] = [
        Option(name: "dir"),
        Option(name: "watch"),
    ]

    /// See Command.help
    public var help: [String] = ["Generates boilerplate code from templates."]

    /// Create a new generate command.
    public init() {}

    /// See Command.run
    public func run(using console: Console, with input: Input) throws {
        var files: [Data] = []

        func readFiles(dir: String) throws {
            for file in try FileManager.default.contentsOfDirectory(atPath: dir) {
                let path = dir + file
                print(path)
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
                if isDirectory.boolValue == true {
                    try readFiles(dir: path + "/")
                } else {
                    if path.hasSuffix(".swift"), let data = FileManager.default.contents(atPath: path) {
                        files.append(data)
                    }
                }
            }
        }

        let dir = try input.requireOption("dir").finished(with: "/")
        try readFiles(dir: dir)

        let parser = CodeParser()
        let types = try parser.parse(files: files)

        let queue = DispatchQueue(label: "codes.vapor.generate")
        let config = LeafConfig()
        let renderer = LeafRenderer(config: config, on: queue)
        let context = try LeafEncoder().encode(["types": types])

        let json = JSONEncoder()
        json.outputFormatting = .prettyPrinted
        let string = try String(data: json.encode(["types": types]), encoding: .utf8)!
        print(string)

        var generated = Data()

        let code = dir + "Code/"
        for file in try FileManager.default.contentsOfDirectory(atPath: code) {
            let path = code + file
            print(path)
            if path.hasSuffix(".leaf"), let data = FileManager.default.contents(atPath: path) {
                let view = try renderer.render(
                    template: data,
                    context: context
                ).blockingAwait()
                generated.append(view)
            }
        }

        let url = URL(fileURLWithPath: dir + "Code/generated.swift")
        try generated.write(to: url)
        console.success("Done")
    }
}
