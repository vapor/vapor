public struct StackTrace {
    public static var isCaptureEnabled: Bool = true

    public static func capture() -> Self? {
        guard Self.isCaptureEnabled else {
            return nil
        }
        return .init(raw: Thread.callStackSymbols)
    }

    public var frames: [Frame] {
        self.raw.dropFirst(2).map { line in
            let file: String
            let function: String
            #if os(Linux)
            let parts = line.split(
                separator: " ",
                maxSplits: 1,
                omittingEmptySubsequences: true
            )
            let fileParts = parts[0].split(separator: "(")
            file = String(fileParts[0])
            switch fileParts.count {
            case 2:
                let mangledName = String(fileParts[1].dropLast().split(separator: "+")[0])
                function = _stdlib_demangleName(mangledName)
            default:
                function = String(parts[1])
            }
            #else
            let parts = line.split(
                separator: " ",
                maxSplits: 3,
                omittingEmptySubsequences: true
            )
            file = String(parts[1])
            let functionParts = parts[3].split(separator: "+")
            let mangledName = String(functionParts[0]).trimmingCharacters(in: .whitespaces)
            function = _stdlib_demangleName(mangledName)
            #endif
            return Frame(file: file, function: function)
        }
    }

    public struct Frame {
        var file: String
        var function: String
    }

    let raw: [String]

    public func description(max: Int = 16) -> String {
        self.frames[...min(self.frames.count, max)].readable
    }
}

extension StackTrace: CustomStringConvertible {
    public var description: String {
        self.description()
    }
}

extension StackTrace.Frame: CustomStringConvertible {
    public var description: String {
        "\(self.file) \(self.function)"
    }
}

extension Collection where Element == StackTrace.Frame {
    var readable: String {
        let maxIndexWidth = String(self.count).count
        let maxFileWidth = self.map { $0.file.count }.max() ?? 0
        return self.enumerated().map { (i, frame) in
            let indexPad = String(
                repeating: " ",
                count: maxIndexWidth - String(i).count
            )
            let filePad = String(
                repeating: " ",
                count: maxFileWidth - frame.file.count
            )
            return "\(i)\(indexPad) \(frame.file)\(filePad) \(frame.function)"
        }.joined(separator: "\n")
    }
}
