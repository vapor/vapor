import COperatingSystem
import Dispatch

/// A loading bar that indicates ongoing activity.
///
/// start() // dot moves
/// Loading Item [      •  ]
///
/// fail()
/// Loading Item [Failed]
///
/// finish()
/// Loading Item [Done]
public final class LoadingBar: Bar {
    var current: Int
    var inc: Int
    let cycles: Int
    private var running: Bool

    override init(
        console: OutputConsole & ClearableConsole,
        title: String,
        width: Int,
        barStyle: ConsoleStyle,
        titleStyle: ConsoleStyle,
        animated: Bool = true
    ) {
        current = -1
        inc = 1
        cycles = width
        running = true

        super.init(
            console: console,
            title: title,
            width: width,
            barStyle: barStyle,
            titleStyle: titleStyle,
            animated: animated
        )
    }

    public override func finish(_ message: String? = nil) {
        stop()
        super.finish(message)
    }

    public override func fail(_ message: String? = nil) {
        stop()
        super.fail(message)
    }

    override func update() {
        if current == -1 {
            current = 0
        } else {
            usleep(25 * 1000)
        }

        guard running else {
            return
        }

        super.update()
    }

    func stop() {
        running = false
    }

    override var bar: String {
        current += inc
        if current == cycles || current == 0 {
            inc *= -1
        }

        var string: String = "["

        let pos = (width / cycles) * current
        for i in 0 ..< width {
            if i == pos {
                string += "•"
            } else {
                string += " "
            }
        }

        string += "]"

        return string
    }

    public func start() {
        if animated {
            DispatchQueue.global().async { [weak self] in
                guard let welf = self else { return }
                while welf.running {
                    self?.update()
                }
            }
        } else {
            console.info("\(title) ...")
        }
    }

    deinit {
        finish()
    }
}

