public protocol Helpable {
    /// A `String` array describing the possible causes of the error.
    /// - note: Defaults to an empty array.
    /// Provide a custom implementation to give more context.
    var possibleCauses: [String] { get }

    /// A `String` array listing some common fixes for the error.
    /// - note: Defaults to an empty array.
    /// Provide a custom implementation to be more helpful.
    var suggestedFixes: [String] { get }

    /// An array of string `URL`s linking to documentation pertaining to the error.
    /// - note: Defaults to an empty array.
    /// Provide a custom implementation with relevant links.
    var documentationLinks: [String] { get }

    /// An array of string `URL`s linking to related Stack Overflow questions.
    /// - note: Defaults to an empty array.
    /// Provide a custom implementation to link to useful questions.
    var stackOverflowQuestions: [String] { get }

    /// An array of string `URL`s linking to related issues on Vapor's GitHub repo.
    /// - note: Defaults to an empty array.
    /// Provide a custom implementation to a list of pertinent issues.
    var gitHubIssues: [String] { get }
}

extension Helpable {
    public func helpableHelp(format: HelpFormat) -> String {
        switch format {
        case .long:
            var print: [String] = []

            if !possibleCauses.isEmpty {
                print.append("Here are some possible causes: \(possibleCauses.bulletedList)")
            }

            if !suggestedFixes.isEmpty {
                print.append("These suggestions could address the issue: \(suggestedFixes.bulletedList)")
            }

            if !documentationLinks.isEmpty {
                print.append("Vapor's documentation talks about this: \(documentationLinks.bulletedList)")
            }

            if !stackOverflowQuestions.isEmpty {
                print.append("These Stack Overflow links might be helpful: \(stackOverflowQuestions.bulletedList)")
            }

            if !gitHubIssues.isEmpty {
                print.append("See these Github issues for discussion on this topic: \(gitHubIssues.bulletedList)")
            }

            return print.joined(separator: "\n\n")
        case .short:
            var string: [String] = []
            if possibleCauses.count > 0 {
                string.append("[Possible causes: \(possibleCauses.joined(separator: ","))]")
            }
            if suggestedFixes.count > 0 {
                string.append("[Suggested fixes: \(suggestedFixes.joined(separator: ","))]")
            }
            return string.joined(separator: " ")
        }
    }
}


// MARK: Optionals

extension Helpable {
    public var documentationLinks: [String] {
        return []
    }

    public var stackOverflowQuestions: [String] {
        return []
    }

    public var gitHubIssues: [String] {
        return []
    }
}


extension Sequence where Iterator.Element == String {
    var bulletedList: String {
        return map { "\n- \($0)" } .joined()
    }
}
