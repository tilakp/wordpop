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

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
