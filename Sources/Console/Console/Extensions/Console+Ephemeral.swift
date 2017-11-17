extension Console {
    public func pushEphemeral() {
        depth += 1
        // Swift.print("PUSH \(depth)\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n")
        levels[depth] = 0
    }

    public func popEphemeral() throws {
        let lines = levels[depth] ?? 0
        // Swift.print("POP \(depth) = \(lines)\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n")
        guard lines > 0 else {
            levels[depth] = nil
            depth -= 1
            return
        }

        for _ in 0..<lines {
            try clear(.line)
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

        // Swift.print("DID OUTPUT \(depth): +\(count)")

        if let existing = levels[depth] {
            levels[depth] = existing + count
        } else {
            levels[depth] = count
        }
    }
}

