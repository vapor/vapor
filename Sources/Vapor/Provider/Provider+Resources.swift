import Core

extension Provider {
    /// The top level directory that hosts
    /// the repository encapsulating a given provider
    internal static var providedDirectory: String? {
        if let existing = providedDirectories[repositoryName] {
            return existing
        }
        
        let directory = checkouts.path(forRepository: repositoryName)
            ?? packages.path(forRepository: repositoryName)
            ?? sources.path(forRepository: repositoryName)
        providedDirectories[repositoryName] = directory
        
        return directory?.finished(with: "/")
    }
}

/// When testing a provider, defaults to workingDir
private let workingDirectory = Core.workingDirectory()

/// A cache of directories found for a given provider
private var providedDirectories: [String: String] = [:]

/// when using a dependency, the currently used
/// version will be in .build/checkouts/
private let checkouts: [String] = {
    let checkouts = workingDirectory.finished(with: "/") + ".build/checkouts/"
    do {
        return try FileManager.contentsOfDirectory(checkouts)
    } catch {
        return []
    }
}()

/// When editing a package, it will be in Packages/ directory
private let packages: [String] = {
    let checkouts = workingDirectory.finished(with: "/") + "Packages/"
    do {
        return try FileManager.contentsOfDirectory(checkouts)
    } catch {
        return []
    }
}()

/// When a provider is in the same package
private let sources: [String] = {
    let checkouts = workingDirectory.finished(with: "/") + "Sources/"
    do {
        return try FileManager.contentsOfDirectory(checkouts)
    } catch {
        return []
    }
}()

extension Sequence where Iterator.Element == String {
    func path(forRepository repository: String) -> String? {
        return self.first { $0.contains(repository) }?.finished(with: "/")
    }
}
