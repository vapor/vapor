import Foundation
#if os(Linux)
import Backtrace
import CBacktrace
#endif

extension Optional where Wrapped == StackTrace {
    public static func capture(skip: Int = 0) -> Self {
        StackTrace.capture(skip: 1 + skip)
    }
}

public struct StackTrace {
    public static var isCaptureEnabled: Bool = true

    public static func capture(skip: Int = 0) -> Self? {
        guard Self.isCaptureEnabled else {
            return nil
        }
        let frames = Self.captureRaw().dropFirst(1 + skip)
        return .init(rawFrames: .init(frames))
    }

    #if os(Linux)
    private static let state = backtrace_create_state(CommandLine.arguments[0], /* supportThreading: */ 1, nil, nil)
    #endif

    static func captureRaw() -> [RawFrame] {
        #if os(Linux)
        final class Context {
            var frames: [RawFrame] = []
        }
        let context = Context()
        backtrace_full(self.state, /* skip: */ 1, { data, pc, filename, lineno, function in
            let frame = RawFrame(
                file: filename.flatMap { String(cString: $0) } ?? "unknown",
                mangledFunction: function.flatMap { String(cString: $0) } ?? "unknown"
            )
            Unmanaged<Context>.fromOpaque(data!).takeUnretainedValue().frames.append(frame)
            return 0
        }, { _, cMessage, _ in
            let message = cMessage.flatMap { String(cString: $0) } ?? "unknown"
            fatalError("Failed to capture Linux stacktrace: \(message)")
        }, Unmanaged.passUnretained(context).toOpaque())
        return context.frames
        #else
        return Thread.callStackSymbols.dropFirst(1).map { line in
            let parts = line.split(
                separator: " ",
                maxSplits: 3,
                omittingEmptySubsequences: true
            )
            let file = parts.count > 1 ? String(parts[1]) : "unknown"
            let functionPart = parts.count > 3 ? (parts[3].split(separator: "+").first.map({ String($0) }) ?? "unknown") : "unknown"
            let mangledFunction = functionPart.trimmingCharacters(in: .whitespaces)
            return .init(file: file, mangledFunction: mangledFunction)
        }
        #endif
    }

    public struct Frame {
        public var file: String
        public var function: String
    }

    public var frames: [Frame] {
        self.rawFrames.map { frame in
            Frame(
                file: frame.file,
                function: _stdlib_demangleName(frame.mangledFunction)
            )
        }
    }

    struct RawFrame {
        var file: String
        var mangledFunction: String
    }

    let rawFrames: [RawFrame]

    public func description(max: Int = 16) -> String {
        return self.frames[..<min(self.frames.count, max)].readable
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

extension Collection where Element == StackTrace.Frame, Index: BinaryInteger {
    var readable: String {
        let maxIndexWidth = self.indices.max(by: { String($0).count < String($1).count }).map { String($0).count } ?? 0
        let maxFileWidth = self.max(by: { $0.file.count < $1.file.count })?.file.count ?? 0
        return self.enumerated().map { i, frame in
            let indexPad = String(repeating: " ", count: Swift.max(0, maxIndexWidth - String(i).count))
            let filePad = String(repeating: " ", count: Swift.max(0, maxFileWidth - frame.file.count))
            
            return "\(i)\(indexPad) \(frame.file)\(filePad) \(frame.function)"
        }.joined(separator: "\n")
    }
}
