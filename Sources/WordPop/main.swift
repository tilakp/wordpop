import AppKit

if let index = CommandLine.arguments.firstIndex(of: "--lookup"), index + 1 < CommandLine.arguments.count {
    let entry = DictionaryLookup.lookup(CommandLine.arguments[(index + 1)...].joined(separator: " "))
    print(EntryDump.text(for: entry))
    exit(0)
}

if let index = CommandLine.arguments.firstIndex(of: "--describe"), index + 1 < CommandLine.arguments.count {
    let description = CommandLine.arguments[(index + 1)...].joined(separator: " ")
    Task {
        print(await WritingModel.words(describedBy: description).joined(separator: ", "))
        exit(0)
    }
    dispatchMain()
}

if let index = CommandLine.arguments.firstIndex(of: "--compare"), index + 2 < CommandLine.arguments.count {
    let (first, second) = (CommandLine.arguments[index + 1], CommandLine.arguments[index + 2])
    let firstDefinition = DictionaryLookup.firstDefinition(of: first)
    let secondDefinition = DictionaryLookup.firstDefinition(of: second, partOfSpeech: firstDefinition?.partOfSpeech)
    print("\(first): \(firstDefinition?.text ?? "-")\n\(second): \(secondDefinition?.text ?? "-")")
    Task {
        print(await WritingModel.difference(between: first, firstDefinition?.text, and: second, secondDefinition?.text) ?? "-")
        exit(0)
    }
    dispatchMain()
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
