import Core

extension Provider {
    /// If a provider provides resources
    /// within itself, it should be here.
    /// follows pattern of the containing 
    /// repository + "/Resources/"
    public static var resourcesDir: String? {
        guard let pdir = providedDirectory else { return nil }
        return pdir + "Resources/"
    }

    /// If a provider provides views
    /// within itself, it should be here.
    /// follows pattern of the containing
    /// repository + "/Resources/Views"
    public static var viewsDir: String? {
        guard let rdir = resourcesDir else { return nil }
        return rdir + "Views/"
    }

    /// The top level directory that hosts
    /// the repository encapsulating a given provider
    fileprivate static var providedDirectory: String? {
        let repositoryName = self.repositoryName
        if let existing = providedDirectories[repositoryName] { return existing }
        let directory = checkouts.path(forRepository: repositoryName)
            ?? packages.path(forRepository: repositoryName)
        providedDirectories[repositoryName] = directory
        return directory
    }
}

/// When testing a provider, defaults to workingDir
private let workingDirectory = Core.workingDirectory()

/// A cache of directories found for a given provider
private var providedDirectories: [String: String] = [:]

/// when using a dependency, the currently used
/// version will be in .build/checkouts/
private let checkouts: [String] = {
    let workingDirectory = Core.workingDirectory()
    let checkouts = workingDirectory.finished(with: "/") + ".build/checkouts/"
    do {
        return try FileManager.contentsOfDirectory(checkouts)
    } catch {
        print("Error loading checkouts \(error). Provider resources may not work.")
        return []
    }
}()

/// When editing a package, it will be in Packages/ directory
private let packages: [String] = {
    let workingDirectory = Core.workingDirectory()
    let checkouts = workingDirectory.finished(with: "/") + "Packages/"
    do {
        return try FileManager.contentsOfDirectory(checkouts)
    } catch {
        print("Error loading Packages \(error). Provider resources may not work.")
        return []
    }
}()

extension Sequence where Iterator.Element == String {
    func path(forRepository repository: String) -> String? {
        return self.first { $0.contains(repository) }?.finished(with: "/")
    }
}
