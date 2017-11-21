import Foundation
import SourceKit

internal final class Parser {
    init() {}

    public func parse(files: [Data]) throws -> [Type] {
        var types: [String: Type] = [:]
        var extensions: [String: Extension] = [:]
        for file in files {
            try parse(file: file, types: &types, extensions: &extensions)
        }
        try resolve(types: &types, extensions: extensions)
        return Array(types.values)
    }

    private func resolve(types: inout [String: Type], extensions: [String: Extension]) throws {
        for (name, `extension`) in extensions {
            guard let type = types[name] else {
                throw "did not find a type for extension on \(name)"
            }

            switch type {
            case .`class`(let c):
                c.properties += `extension`.properties
                c.methods += `extension`.methods
                c.inheritedTypes += `extension`.inheritedTypes
                types[c.name] = .`class`(c)
            default:
                print("unsupported extension type: \(type)")
            }
        }
    }

    private func parse(file: Data, types: inout [String: Type], extensions: inout [String: Extension]) throws {
        let file = try SourceKit.Library.shared.parseFile(file)

        for structure in file.structures {
            switch structure.kind {
            case .`extension`:
                break
            default:
                guard types[structure.name] == nil else {
                    throw "already found a top-level type named \(structure.name)"
                }
            }

            switch structure.kind {
            case .`class`:
                let `class` = Class(
                    name: structure.name,
                    properties: parseProperties(from: structure.subStructures),
                    methods: parseMethods(from: structure.subStructures),
                    inheritedTypes: structure.inheritedTypes,
                    comment: parseComment(from: structure)
                )
                types[structure.name] = .`class`(`class`)
            case .`struct`:
                let `struct` = Struct(
                    name: structure.name,
                    properties: parseProperties(from: structure.subStructures),
                    methods: parseMethods(from: structure.subStructures)
                )
                types[structure.name] = .`struct`(`struct`)
            case .`extension`:
                if let existing = extensions[structure.name] {
                    existing.properties += parseProperties(from: structure.subStructures)
                    existing.methods += parseMethods(from: structure.subStructures)
                    existing.inheritedTypes += structure.inheritedTypes
                    var lines: [String] = []
                    lines += existing.comment?.lines ?? []
                    lines += structure.comments ?? []
                    existing.comment = lines.count > 0 ? Comment(lines: lines) : nil
                } else {
                    let `extension` = Extension(
                        typeName: structure.name,
                        properties: parseProperties(from: structure.subStructures),
                        methods: parseMethods(from: structure.subStructures),
                        inheritedTypes: structure.inheritedTypes,
                        comment: parseComment(from: structure)
                    )
                    extensions[structure.name] = `extension`
                }
            default:
                print("unsupported kind: \(structure.kind)")
                break
            }
        }
    }

    private func parseProperties(from structures: [Structure]) -> [Property] {
        return structures.flatMap { structure in
            switch structure.kind {
            case .`var`(let typeName, let isInstance):
                return Property(
                    name: structure.name,
                    typeName: typeName,
                    isInstance: isInstance,
                    comment: parseComment(from: structure)
                )
            default:
                return nil
            }
        }
    }

    private func parseMethods(from structures: [Structure]) -> [Method] {
        return structures.flatMap { structure in
            switch structure.kind {
            case .method(let isInstance):
                return Method(
                    name: structure.name,
                    isInstance: isInstance
                )
            default:
                return nil
            }
        }
    }

    private func parseComment(from structure: Structure) -> Comment? {
        let comment: Comment?
        if let comments = structure.comments {
            comment = Comment(lines: comments)
        } else {
            comment = nil
        }
        return comment
    }
}

