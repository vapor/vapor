extension Bool {
    /**
        This function seeks to replicate the expected 
        behavior of `var boolValue: Bool` on `NSString`.  
        Any variant of `yes`, `y`, `true`, `t`, or any 
        numerical value greater than 0 will be considered `true`
    */
    public init(_ string: String) {
        let cleaned = string
            .lowercased()
            .characters
            .first ?? "n"

        switch cleaned {
        case "t", "y", "1":
            self = true
        default:
            if let int = Int(String(cleaned)) where int > 0 {
                self = true
            } else {
                self = false
            }

        }
    }
}
