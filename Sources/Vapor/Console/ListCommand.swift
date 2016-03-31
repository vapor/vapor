//
//  ListCommand.swift
//  Vapor
//
//  Created by Shaun Harrison on 2/20/16.
//

public class ListCommand: Command {

    public override var name: String {
        return "list"
    }

    public override var help: String? {
        return "Lists commands"
    }

    public override func handle() {
        line("<info>Vapor</info> version <comment>\(Application.VERSION)</comment>")
        line("")

        comment("Usage:")
        line("  command [options] [arguments]")
        line("")


        var maxCommandNameLength = 20
        var grouped = [String: [Command]]()

        for command in console.allCommands() {
            let name = command.name
            maxCommandNameLength = max(maxCommandNameLength, name.characters.count + 4)

            let namespace: String

            if let range = name.rangeOfString(":") {
                namespace = name[name.startIndex..<range.startIndex]
            } else {
                namespace = "_"
            }

            if grouped[namespace] == nil {
                grouped[namespace] = []
            }

            grouped[namespace]!.append(command)
        }

        let keys = Array(grouped.keys).sorted()

        for key in keys {
            if key == "_" {
                comment("Available commands:")
            } else {
                comment(" \(key)")
            }

            for command in grouped[key]! {
                line("  <info>\(command.name.pad(with: " ", to: maxCommandNameLength))</info>\(command.help ?? "")")
            }
        }
    }

}
