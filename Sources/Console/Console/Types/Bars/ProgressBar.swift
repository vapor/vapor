/// A loading bar that indicates ongoing activity.
///
/// progress = 0.5 // updated progress
/// Loading Item [===    ] 50%
///
/// fail()
/// Loading Item [Failed]
///
/// finish()
/// Loading Item [Done]
public class ProgressBar: Bar {
    public var progress: Double = 0 {
        didSet {
            if animated { try? update() }
        }
    }

    override func update() throws {
        try super.update()
    }

    override var bar: String {
        let result: Double = progress * Double(width)
        if result.isNaN || result.isInfinite {
            return "[ NaN or Infinite Value ]"
        }

        let current = Int(result)

        var string: String = "["

        for i in 0 ..< width {
            if i <= current {
                string += "="
            } else {
                string += " "
            }
        }

        string += "]"

        return string
    }

    override var status: String {
        let result: Double = progress * 100.0
        if result.isNaN || result.isInfinite {
            return ""
        }

        let percent = Int(result)
        return " \(percent)%"
    }
}
