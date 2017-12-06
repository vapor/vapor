import COperatingSystem

public class Bar {
    let console: OutputConsole & ClearableConsole
    let title: String
    let width: Int
    let barStyle: ConsoleStyle
    let titleStyle: ConsoleStyle
    let animated: Bool

    var hasStarted: Bool
    var hasFinished: Bool

    var mutex: UnsafeMutablePointer<pthread_mutex_t>

    init(
        console: OutputConsole & ClearableConsole,
        title: String,
        width: Int,
        barStyle: ConsoleStyle,
        titleStyle: ConsoleStyle,
        animated: Bool = true
    ) {
        self.console = console
        self.width = width
        self.title = title
        self.barStyle = barStyle
        self.titleStyle = titleStyle

        #if NO_ANIMATION
            self.animated = false
        #else
            self.animated = animated
        #endif

        hasStarted = false
        hasFinished = false

        mutex = UnsafeMutablePointer.allocate(capacity: 1)
        pthread_mutex_init(mutex, nil)
    }

    deinit {
        mutex.deinitialize()
        mutex.deallocate(capacity: 1)
    }

    public func fail(_ message: String? = nil) {
        guard !hasFinished else {
            return
        }
        hasFinished = true

        let message = message ?? "Failed"

        if animated {
            collapseBar(message: message, style: .error)
        } else {
            console.output(title, style: titleStyle, newLine: false)
            console.output(" [\(message)]", style: .error)
        }
    }

    public func finish(_ message: String? = nil) {
        guard !hasFinished else {
            return
        }
        hasFinished = true

        let message = message ?? "Done"

        if animated {
            collapseBar(message: message, style: .success)
        } else {
            console.output(title, style: titleStyle, newLine: false)
            console.output(" [\(message)]", style: .success)
        }
    }

    func collapseBar(message: String, style: ConsoleStyle) {
        pthread_mutex_lock(mutex)
        for i in 0 ..< (width - message.count) {
            prepareLine()

            console.output(title, style: titleStyle, newLine: false)

            let rate = (width - message.count) / message.count
            let charactersShowing = i / rate


            var newBar: String = " ["
            for j in 0 ..< charactersShowing {
                let index = message.index(message.startIndex, offsetBy: j)
                newBar.append(message[index])
            }
            console.output(newBar, style: style, newLine: false)

            var oldBar = ""
            for _ in 0 ..< (width - i - 1 - charactersShowing) {
                let index = bar.index(bar.endIndex, offsetBy: -2)
                oldBar.append(bar[index])
            }
            oldBar.append("]")

            console.output(oldBar, style: barStyle, newLine: true)

            console.blockingWait(seconds: 0.01)
        }

        prepareLine()
        console.output(title, style: titleStyle, newLine: false)
        console.output(" [\(message)]", style: style)
        pthread_mutex_unlock(mutex)
    }

    func update() {
        pthread_mutex_lock(mutex)
        prepareLine()

        let total = title.count + 1 + width + status.count + 2 + 3
        let trimmedTitle: String
        if console.size.width < total {
            var diff = total - console.size.width
            if diff > title.count {
                diff = title.count
            }
            diff = diff * -1
            #if swift(>=4)
            trimmedTitle = title[..<title.index(title.endIndex, offsetBy: diff)] + "..."
            #else 
            trimmedTitle = title.substring(
                to: title.index(title.endIndex, offsetBy: diff)
            ) + "..."
            #endif
        } else {
            trimmedTitle = title
        }

        console.output(trimmedTitle + " ", style: titleStyle, newLine: false)
        console.output(bar, style: barStyle, newLine: false)
        console.output(status, style: titleStyle)
        pthread_mutex_unlock(mutex)
    }

    func prepareLine() {
        if hasStarted {
            console.clear(.line)
        } else {
            hasStarted = true
        }
    }

    var bar: String {
        return ""
    }

    var status: String {
        return ""
    }
}

