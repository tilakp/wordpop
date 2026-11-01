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

if let index = CommandLine.arguments.firstIndex(of: "--fits"), index + 2 < CommandLine.arguments.count {
    let (word, sentence) = (CommandLine.arguments[index + 1], CommandLine.arguments[index + 2])
    let entry = DictionaryLookup.lookup(word)
    let block = PopupController.contextBlockIndex(in: entry, word: word, sentence: sentence)
    Task {
        let match = await PopupController.contextMatch(of: entry, word: word, sentence: sentence, in: block)
        let definition = match.senseNumber.flatMap { number in entry.blocks[block ?? 0].items.first { $0.number == number }?.text }
        print("sense:", definition ?? "-")
        print("fits:", match.synonyms.prefix(8).joined(separator: ", "))
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

if let index = CommandLine.arguments.firstIndex(of: "--describing"), index + 1 < CommandLine.arguments.count {
    let word = CommandLine.arguments[index + 1]
    let partOfSpeech = index + 2 < CommandLine.arguments.count ? CommandLine.arguments[index + 2] : "noun"
    Task {
        print(await WritingModel.describingWords(for: word, partOfSpeech: partOfSpeech).joined(separator: ", "))
        exit(0)
    }
    dispatchMain()
}

if let index = CommandLine.arguments.firstIndex(of: "--rewrite"), index + 2 < CommandLine.arguments.count,
   let rewrite = WritingModel.Rewrite.all.first(where: { "\($0)" == CommandLine.arguments[index + 1] }) {
    let sentence = CommandLine.arguments[(index + 2)...].joined(separator: " ")
    Task {
        print(await WritingModel.rewrite(sentence, rewrite) ?? "-")
        exit(0)
    }
    dispatchMain()
}

if let index = CommandLine.arguments.firstIndex(of: "--translate"), index + 2 < CommandLine.arguments.count {
    let text = CommandLine.arguments[(index + 2)...].joined(separator: " ")
    Task {
        print(await Translator.translate(text, to: CommandLine.arguments[index + 1]))
        exit(0)
    }
    dispatchMain()
}

if let index = CommandLine.arguments.firstIndex(of: "--tone"), index + 1 < CommandLine.arguments.count {
    let text = CommandLine.arguments[(index + 1)...].joined(separator: " ")
    Task {
        let reading = await WritingModel.tone(of: text)
        print(reading.map { "\($0.tone): \($0.reason)" } ?? "-")
        exit(0)
    }
    dispatchMain()
}

if let index = CommandLine.arguments.firstIndex(of: "--main-point"), index + 1 < CommandLine.arguments.count {
    let text = CommandLine.arguments[(index + 1)...].joined(separator: " ")
    Task {
        let answer = await WritingModel.mainPoint(of: TextStats.analyze(text).sentenceTexts)
        print(answer.map { "sentence \($0.sentence.map(String.init) ?? "none"): \($0.point)" } ?? "-")
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
        print("tone:", await WritingModel.tone(of: "Send me the file by noon. I asked twice already.").map { "\($0.tone): \($0.reason)" } ?? "-")
        print("expand:", await WritingModel.rewrite("Short sentences are easier to read.", .example) ?? "-")
        print("describing:", await WritingModel.describingWords(for: "rain", partOfSpeech: "noun"),
              await WritingModel.describingWords(for: "eerie", partOfSpeech: "adjective"))
        print("main point:", await WritingModel.mainPoint(of: [
            "Thanks for the update on the launch.", "The team has worked hard this month.",
            "We need to move the launch to June 3 because the security review is not done.", "Let me know if you have questions.",
        ]).map { "\($0.sentence.map(String.init) ?? "none"): \($0.point)" } ?? "-")
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
