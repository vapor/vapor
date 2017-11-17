import Async
import libc
import Foundation
import Core

private var _pids: [pid_t] = []

/// Generic console that uses a mixture of Swift standard
/// library and Foundation code to fulfull protocol requirements.
public final class Terminal: Console {
    public var extend: Extend

    public init() {
        func kill(sig: Int32) {
            for pid in _pids {
                _ = libc.kill(pid, sig)
            }
            exit(sig)
        }

        self.extend = Extend()

        signal(SIGINT, kill)
        signal(SIGTERM, kill)
        signal(SIGQUIT, kill)
        signal(SIGHUP, kill)
    }

    @discardableResult
    /// See Console.action
    public func action(_ action: ConsoleAction) throws -> String? {
        switch action {
        case .clear(let clear):
            switch clear {
            case .line:
                try command(.cursorUp)
                try command(.eraseLine)
            case .screen:
                try command(.eraseScreen)
            }
        case .error(let string, let newLine):
            let output = newLine ? string + "\n" : string
            guard let data = output.data(using: .utf8) else {
                throw ConsoleError(
                    identifier: "errorData",
                    reason: "Could not convert error to data"
                )
            }
            FileHandle.standardError.write(data)
        case .input(let isSecure):
            if isSecure {
                // http://stackoverflow.com/a/30878869/2611971
                let entry: UnsafeMutablePointer<Int8> = getpass("")
                let pointer: UnsafePointer<CChar> = .init(entry)
                guard var pass = String(validatingUTF8: pointer) else {
                    return nil
                }
                if pass.hasSuffix("\n") {
                    pass = String(pass.dropLast())
                }
                return pass
            } else {
                return readLine(strippingNewline: true)
            }
        case .output(let string, let style, let newLine):
            let terminator = newLine ? "\n" : ""

            let output: String
            if let color = style.terminalColor {
                output = string.terminalColorize(color)
            } else {
                output = string
            }

            Swift.print(output, terminator: terminator)
            fflush(stdout)
        case .execute(let program, let arguments, let input, let output, let error):
            var program = program
            if !program.hasPrefix("/") {
                let res = try backgroundExecute(program: "/bin/sh", arguments: ["-c", "which \(program)"]) as String
                program = res.trimmingCharacters(in: .whitespaces)
            }
            // print(program + " " + arguments.joined(separator: " "))
            let process = Process()
            process.environment = ProcessInfo.processInfo.environment
            process.launchPath = program
            process.arguments = arguments
            process.standardInput = input?.either
            process.standardOutput = output?.either
            process.standardError = error?.either
            process.qualityOfService = .userInteractive

            process.launch()
            _pids.append(process.processIdentifier)

            process.waitUntilExit()
            let status = process.terminationStatus

            if status != 0 {
                throw ConsoleError(
                    identifier: "executeFailed",
                    reason: "Execution failed. Status code: \(Int(status))"
                )
            }
        }

        return nil
    }

    /// See: Console.size
    public var size: (width: Int, height: Int) {
        var w = winsize()
        _ = ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &w);
        return (Int(w.ws_col), Int(w.ws_row))
    }
}

// MARK: utility

extension ConsoleStyle {
    /// Returns the terminal console color
    /// for the ConsoleStyle.
    fileprivate var terminalColor: ConsoleColor? {
        let color: ConsoleColor?

        switch self {
        case .plain:
            color = nil
        case .info:
            color = .cyan
        case .warning:
            color = .yellow
        case .error:
            color = .red
        case .success:
            color = .green
        case .custom(let c):
            color = c
        }

        return color
    }
}

