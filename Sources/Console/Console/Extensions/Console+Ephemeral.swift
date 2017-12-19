extension ClearableConsole {
    public func pushEphemeral() {
        depth += 1
        levels[depth] = 0
    }

    public func popEphemeral() throws {
        let lines = levels[depth] ?? 0
        guard lines > 0 else {
            levels[depth] = nil
            depth -= 1
            return
        }

        for _ in 0..<lines {
            clear(.line)
        }

        // remember to reset depth after or else
        // the lines will get messed up
        levels[depth] = nil
        depth -= 1
    }

    private var depth: Int {
        get { return extend["ephemeral-depth"] as? Int ?? 0 }
        set { extend["ephemeral-depth"] = newValue }
    }

    private var levels: [Int: Int] {
        get { return extend["ephemeral-levels"] as? [Int: Int] ?? [:] }
        set { extend["ephemeral-levels"] = newValue }
    }

    internal func didOutputLines(count: Int) {
        guard depth > 0 else {
            return
        }

        if let existing = levels[depth] {
            levels[depth] = existing + count
        } else {
            levels[depth] = count
        }
    }
}

