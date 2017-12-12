import Console

extension OutputConsole {
    /// Outputs autocomplete for a command.
    public func outputAutocomplete(for runnable: Runnable, executable: String) throws {
        var names = runnable.options.map { $0.name }
        if let group = runnable as? Group {
            names += group.commands.keys
        }
        if let command = runnable as? Command {
            names += command.arguments.map { $0.name }
        }
        
        if let command = runnable as? Command {
            if command.arguments.count > 0 {
                for arg in command.arguments {
                    outputAutocompleteListItem(
                        name: arg.name,
                        prefix: ""
                    )
                }
            }
        }
        
        if let group = runnable as? Group {
            if group.commands.count > 0 {
                for (key, runnable) in group.commands {
                    outputAutocompleteListItem(
                        name: key,
                        prefix: ""
                    )
                }
            }
        }
        
        if runnable.options.count > 0 {
            for opt in runnable.options {
                outputAutocompleteListItem(
                    name: opt.name,
                    prefix: "--"
                )
            }
        }
    }
    
    private func outputAutocompleteListItem(name: String, prefix: String) {
        output(prefix + name + " ", style: .plain, newLine: false)
    }
}
