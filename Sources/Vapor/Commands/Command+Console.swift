/**
    Console additions.
*/
extension Command {
    /**
        Prints a message to the app's console.
    */
    public func print(_ string: String, style: ConsoleStyle = .plain, newLine: Bool = true) {
        app.console.output(string, style: style, newLine: newLine)
    }

    /**
        Prints an informational message.
    */
    public func info(_ string: String) {
        print(string, style: .info)
    }

    /**
        Prints a warning message.
    */
    public func warning(_ string: String) {
        print(string, style: .warning)
    }

    /**
        Prints an error message.
    */
    public func error(_ string: String) {
        print(string, style: .error)
    }

    /**
        Prints a success message.
    */
    public func success(_ string: String) {
        print(string, style: .success)
    }

    /**
        Requests input from the console
        after displaying the desired prompt.
    */
    public func ask(_ prompt: String, style: ConsoleStyle = .info) -> Polymorphic {
        print(prompt, style: style)
        return app.console.input()
    }

    /**
        Requests yes/no confirmation from 
        the console.
    */
    public func confirm(_ prompt: String, style: ConsoleStyle = .info) -> Bool {
        var i = 0
        var result = ""
        while result != "y" && result != "yes" && result != "n" && result != "no" {
            print(prompt, style: style)
            if i >= 1 {
                print("[y]es or [n]o: ", style: style, newLine: false)
            }
            result = app.console.input().lowercased()
            i += 1
        }
        
        return result == "y" || result == "yes"
    }
    
}
