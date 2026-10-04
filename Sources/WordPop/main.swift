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

if let index = CommandLine.arguments.firstIndex(of: "--collocations"), index + 1 < CommandLine.arguments.count {
    let word = CommandLine.arguments[index + 1]
    Task {
        print(await WritingModel.collocations(for: word, partOfSpeech: DictionaryLookup.firstDefinition(of: word)?.partOfSpeech).joined(separator: ", "))
        exit(0)
    }
    dispatchMain()
}

if CommandLine.arguments.contains("--model-check") {
    // Runs every on-device model feature on fixed inputs, for spotting
    // requests the model refuses or answers badly.
    Task {
        print("fits:", await WritingModel.bestFits(for: "quiet", in: "The room fell quiet after the verdict.",
                                                   candidates: ["silent", "hushed", "calm", "discreet", "reserved"]))
        print("sense:", await WritingModel.senseIndex(of: "runs", in: "She runs a small bakery.",
                                                      definitions: ["move fast on foot", "be in charge of; manage", "flow"]) as Any)
        print("tone:", await WritingModel.toneChoices(for: "walked", in: "He walked into the room.", tone: "more vivid",
                                                      candidates: ["strode", "marched", "ambled", "proceeded"]))
        print("rhymes:", await WritingModel.rhymes(for: "I walked alone beneath the fading light", endingIn: "light",
                                                   candidates: ["night", "bright", "kite", "white", "polite"]))
        print("collocations:", await WritingModel.collocations(for: "evidence", partOfSpeech: "noun"))
        print("compare:", await WritingModel.difference(between: "famous", "known about by many people",
                                                        and: "notorious", "famous for some bad quality or deed") ?? "-")
        print("describe:", await WritingModel.words(describedBy: "a long angry speech"))
        print("examples:", await WritingModel.examples(of: "meticulous", partOfSpeech: "adjective",
                                                       definition: "showing great attention to detail; very careful and precise"))
        print("explain:", await WritingModel.explain(phrase: "touch base", in: "Let's touch base next week.") ?? "-")
        print("rewrite:", await WritingModel.rewrite("The report was written by the committee.", .active) ?? "-")
        print("sensitive:", await WritingModel.senseIndex(of: "killed", in: "The frost killed the plants.",
                                                          definitions: ["cause the death of", "put an end to", "pass time"]) as Any)
        exit(0)
    }
    dispatchMain()
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
