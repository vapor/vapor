extension Console {
    /// Requests yes/no confirmation from
    /// the console.
    public func confirm(_ prompt: String, style: ConsoleStyle = .info) throws -> Bool {
        var i = 0
        var result = ""
        while result != "y" && result != "yes" && result != "n" && result != "no" {
            try output(prompt, style: style)
            if i >= 1 {
                try output("[y]es or [n]o> ", style: style, newLine: false)
            } else {
                try output("y/n> ", style: style, newLine: false)
            }

            // Defaults for all confirms for headless environments
            if let override = confirmOverride {
                let message = override ? "yes" : "no"
                try output(message, style: .warning)
                return override
            }

            result = try input().lowercased()
            i += 1
        }

        return result == "y" || result == "yes"
    }
}

extension Console {
    var confirmOverride: Bool? {
        get { return extend["confirmOverride"] as? Bool }
        set { extend["confirmOverride"] = newValue }
    }
}
