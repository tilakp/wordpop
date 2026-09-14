import Foundation

/// A minimal DOM over the XHTML that Dictionary Services returns for an
/// entry (`DCSRecordCopyData`). Apple's dictionaries mark every part of an
/// entry with CSS classes (`hw`, `pos`, `df`, `ex`, `syn`, ...), so queries
/// by class are all the parsers need.
final class MarkupNode {
    enum Content {
        case text(String)
        case node(MarkupNode)
    }

    let name: String
    let classes: Set<String>
    let attributes: [String: String]
    private(set) var contents: [Content] = []

    init(name: String, attributes: [String: String]) {
        self.name = name
        self.attributes = attributes
        classes = Set((attributes["class"] ?? "").split(separator: " ").map(String.init))
    }

    fileprivate func append(_ content: Content) { contents.append(content) }

    var children: [MarkupNode] {
        contents.compactMap { if case .node(let node) = $0 { node } else { nil } }
    }

    func has(_ cssClass: String) -> Bool { classes.contains(cssClass) }

    /// Depth-first descendants carrying `cssClass`, in document order.
    /// Matches are not searched inside, so nested elements of the same
    /// class are left to the caller.
    func descendants(_ cssClass: String) -> [MarkupNode] {
        var result: [MarkupNode] = []
        for child in children {
            if child.has(cssClass) {
                result.append(child)
            } else {
                result += child.descendants(cssClass)
            }
        }
        return result
    }

    func first(_ cssClass: String) -> MarkupNode? {
        for child in children {
            if child.has(cssClass) { return child }
            if let match = child.first(cssClass) { return match }
        }
        return nil
    }

    /// Text content with the dictionary's punctuation glyphs (`gp`: the
    /// pipes, colons and periods between fields) left out and whitespace
    /// collapsed.
    var text: String { collectedText(includingGlyphs: false) }

    /// Text including glyph spans, for the few fields (part of speech,
    /// sense numbers) whose value is itself marked as a glyph.
    var fullText: String { collectedText(includingGlyphs: true) }

    private func collectedText(includingGlyphs: Bool) -> String {
        var pieces: [String] = []
        collectText(into: &pieces, includingGlyphs: includingGlyphs)
        return pieces.joined().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private func collectText(into pieces: inout [String], includingGlyphs: Bool) {
        for content in contents {
            switch content {
            case .text(let text): pieces.append(text)
            case .node(let node) where includingGlyphs || !node.has("gp"): node.collectText(into: &pieces, includingGlyphs: includingGlyphs)
            case .node: break
            }
        }
    }
}

enum MarkupDocument {
    static func parse(_ markup: String) -> MarkupNode? {
        guard let data = markup.data(using: .utf8) else { return nil }
        let builder = Builder()
        let parser = XMLParser(data: data)
        parser.delegate = builder
        parser.shouldResolveExternalEntities = false
        return parser.parse() ? builder.root : nil
    }

    private final class Builder: NSObject, XMLParserDelegate {
        let root = MarkupNode(name: "#document", attributes: [:])
        private var stack: [MarkupNode] = []

        override init() {
            super.init()
            stack = [root]
        }

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName: String?, attributes: [String: String]) {
            let node = MarkupNode(name: elementName, attributes: attributes)
            stack.last?.append(.node(node))
            stack.append(node)
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
            if stack.count > 1 { stack.removeLast() }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            stack.last?.append(.text(string))
        }
    }
}
