import Async
import COperatingSystem
import Foundation
import Service

/// global static array of running PIDs.
/// unfortunately we must keep track of processes that
/// have been spun up by this program in case it gets a signal.
/// If we don't manually kill all running processes that
/// we have launched, they will continue running.
private var _pids: [pid_t] = []

/// This lock ensures the array is never accessed
/// unsafely. This unfortunately means Terminal's execute
/// functions are not usable where non-blocking concurrency is critical.
private var _pidLock = NSLock()

/// Generic console that uses a mixture of Swift standard
/// library and Foundation code to fulfull protocol requirements.
public final class Terminal: Console {
    /// See Extendable.extend
    public var extend: Extend
    
    internal var applyStyle: Bool {
        #if Xcode
            return false
        #else
            return true
        #endif
    }

    /// Create a new Terminal.
    public init() {
        func kill(sig: Int32) {
            for pid in _pids {
                _ = COperatingSystem.kill(pid, sig)
            }
            exit(sig)
        }

        self.extend = Extend()

        signal(SIGINT, kill)
        signal(SIGTERM, kill)
        signal(SIGQUIT, kill)
        signal(SIGHUP, kill)
    }

    /// See ClearableConsole.clear
    public func clear(_ type: ConsoleClear) {
        switch type {
        case .line:
            command(.cursorUp)
            command(.eraseLine)
        case .screen:
            command(.eraseScreen)
        }
    }

    /// See InputConsole.input
    public func input(isSecure: Bool) -> String {
        didOutputLines(count: 1)
        if isSecure {
            // http://stackoverflow.com/a/30878869/2611971
            let entry: UnsafeMutablePointer<Int8> = getpass("")
            let pointer: UnsafePointer<CChar> = .init(entry)
            guard var pass = String(validatingUTF8: pointer) else {
                return ""
            }
            if pass.hasSuffix("\n") {
                pass = String(pass.dropLast())
            }
            return pass
        } else {
            return readLine(strippingNewline: true) ?? ""
        }
    }

    /// See ExecuteConsole.output
    public func execute(
        program: String,
        arguments: [String],
        input: ExecuteStream?,
        output: ExecuteStream?,
        error: ExecuteStream?
    ) throws {
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

        _pidLock.lock()
        _pids.append(process.processIdentifier)
        _pidLock.unlock()

        process.waitUntilExit()
        let status = process.terminationStatus

        _pidLock.lock()
        for (i, pid) in _pids.enumerated() {
            if pid == process.processIdentifier {
                _pids.remove(at: i)
            }
        }
        _pidLock.unlock()

        if status != 0 {
            throw ConsoleError(
                identifier: "executeFailed",
                reason: "Execution failed. Status code: \(Int(status))"
            )
        }
    }

    /// See OutputConsole.output
    public func output(_ string: String, style: ConsoleStyle, newLine: Bool) {
        var lines = 0
        let count = string.count
        if count > size.width && count > 0 && size.width > 0 {
            lines += (count / size.width) + 1
        }
        if newLine {
            lines += 1
        }
        didOutputLines(count: lines)

        let terminator = newLine ? "\n" : ""

        let output: String
        if applyStyle {
            output = string.terminalStylize(style)
        } else {
            output = string
        }

        Swift.print(output, terminator: terminator)
        fflush(stdout)
    }

    /// See ErrorConsole.error
    public func report(error: String, newLine: Bool) {
        let output = newLine ? error + "\n" : error
        let data = output.data(using: .utf8) ?? Data()
        FileHandle.standardError.write(data)
    }

    /// See: BaseConsole.size
    public var size: (width: Int, height: Int) {
        var w = winsize()
        _ = ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &w);
        return (Int(w.ws_col), Int(w.ws_row))
    }
}
