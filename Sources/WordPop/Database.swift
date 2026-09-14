import Foundation
import SQLite3

/// Read-only access to the bundled wordpop.sqlite (built by
/// scripts/build_db.py). Querying on demand keeps launch instant and
/// resident memory small compared to decoding the source JSON.
enum Database {
    private static let separator = "\t"

    /// In the app bundle the file sits in Contents/Resources; when run from
    /// `swift build` output it is inside SwiftPM's resource bundle next to
    /// the binary.
    private static var url: URL? {
        if let url = Bundle.main.url(forResource: "wordpop", withExtension: "sqlite") { return url }
        let packaged = Bundle.main.bundleURL.appendingPathComponent("WordPop_WordPop.bundle/wordpop.sqlite")
        return FileManager.default.fileExists(atPath: packaged.path) ? packaged : nil
    }

    private static let connection: OpaquePointer? = {
        guard let url else { return nil }
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &db, flags, nil) == SQLITE_OK else { return nil }
        return db
    }()

    static func list(_ table: String, word: String, partOfSpeech: String? = nil) -> [String] {
        let sql = partOfSpeech == nil
            ? "SELECT words FROM \(table) WHERE word = ?1"
            : "SELECT words FROM \(table) WHERE word = ?1 AND pos = ?2"
        return query(sql, [word.lowercased(), partOfSpeech].compactMap { $0 }).first?
            .components(separatedBy: separator) ?? []
    }

    /// Every part-of-speech group for a word, as the stores' callers expect.
    static func groups(_ table: String, word: String) -> [String: [String]] {
        var groups: [String: [String]] = [:]
        for row in rows("SELECT pos, words FROM \(table) WHERE word = ?1", [word.lowercased()]) {
            groups[row[0]] = row[1].components(separatedBy: separator)
        }
        return groups
    }

    static func wordsWithPrefix(_ prefix: String, limit: Int) -> [String] {
        // Range scan on the primary key: [prefix, prefix + U+FFFF).
        query("SELECT word FROM words WHERE word >= ?1 AND word < ?2 ORDER BY rank LIMIT ?3",
              [prefix, prefix + "\u{FFFF}", limit])
    }

    static func warmUp() {
        _ = connection
    }

    private static func query(_ sql: String, _ parameters: [Any]) -> [String] {
        rows(sql, parameters).map { $0[0] }
    }

    private static func rows(_ sql: String, _ parameters: [Any]) -> [[String]] {
        guard let connection else { return [] }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK, let statement else { return [] }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (index, parameter) in parameters.enumerated() {
            switch parameter {
            case let text as String: sqlite3_bind_text(statement, Int32(index + 1), text, -1, transient)
            case let number as Int: sqlite3_bind_int64(statement, Int32(index + 1), Int64(number))
            default: break
            }
        }
        var result: [[String]] = []
        let columns = sqlite3_column_count(statement)
        while sqlite3_step(statement) == SQLITE_ROW {
            result.append((0..<columns).map { sqlite3_column_text(statement, $0).map { String(cString: $0) } ?? "" })
        }
        return result
    }
}
