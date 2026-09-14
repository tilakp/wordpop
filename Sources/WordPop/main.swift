import AppKit

if let index = CommandLine.arguments.firstIndex(of: "--lookup"), index + 1 < CommandLine.arguments.count {
    let entry = DictionaryLookup.lookup(CommandLine.arguments[(index + 1)...].joined(separator: " "))
    print(EntryDump.text(for: entry))
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
