extension Droplet {
    static func workingDirectory(from arguments: [String]) -> String {
        func fileWorkDirectory() -> String? {
            let parts = #file.components(separatedBy: "/Packages/Vapor-")
            guard parts.count == 2 else {
                return nil
            }

            return parts.first
        }

        let workDir = arguments.value(for: "workdir")
            ?? arguments.value(for: "workDir")
            ?? fileWorkDirectory()
            ?? "./"

        return workDir.finished(with: "/")
    }
}
