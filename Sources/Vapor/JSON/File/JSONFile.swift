struct JSONFile {
    let name: String
    let json: JSON

    private static let suffix = ".json"

    init(name: String, json: JSON) {
        if
            let nameSequence = name.characters.split(separator: ".").first,
            name.hasSuffix(JSONFile.suffix)
        {
            self.name = String(nameSequence)
        } else {
            self.name = name
        }
        self.json = json
    }
}
