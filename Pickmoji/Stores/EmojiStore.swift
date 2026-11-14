import Foundation

struct EmojiSearchIndex {
    private static let italianLocale = Locale(identifier: "it")

    private struct SearchTerms {
        let label: String
        let words: [String]
        let tags: [String]

        init(label: String, tags: [String]) {
            self.label = EmojiSearchIndex.normalized(label)
            words = self.label.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
            self.tags = tags.map(EmojiSearchIndex.normalized)
        }
    }

    private struct Entry {
        let emoji: Emoji
        let primary: SearchTerms
        let english: SearchTerms?
    }

    private let entries: [Entry]

    init(emoji: [Emoji]) {
        entries = emoji.map { item in
            Entry(
                emoji: item,
                primary: SearchTerms(label: item.label, tags: item.tags),
                english: item.englishLabel.map { SearchTerms(label: $0, tags: item.englishTags ?? []) }
            )
        }
    }

    var all: [Emoji] { entries.map(\.emoji) }

    func search(_ rawQuery: String) -> [Emoji] {
        let query = Self.normalized(rawQuery)
        guard !query.isEmpty else { return all }
        let tokens = query.split(separator: " ").map(String.init)

        return entries
            .compactMap { entry -> (language: Int, tier: Int, order: Int, emoji: Emoji)? in
                if let tier = tier(for: entry.primary, query: query, tokens: tokens) {
                    return (0, tier, entry.emoji.order, entry.emoji)
                }
                guard let english = entry.english,
                      let tier = tier(for: english, query: query, tokens: tokens) else { return nil }
                return (1, tier, entry.emoji.order, entry.emoji)
            }
            .sorted { lhs, rhs in
                (lhs.language, lhs.tier, lhs.order) < (rhs.language, rhs.tier, rhs.order)
            }
            .map(\.emoji)
    }

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: italianLocale)
            .replacingOccurrences(of: "’", with: "'")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private func tier(for terms: SearchTerms, query: String, tokens: [String]) -> Int? {
        if terms.label.hasPrefix(query) { return 0 }
        if terms.words.contains(where: { $0.hasPrefix(query) }) { return 1 }
        if terms.tags.contains(where: { $0.hasPrefix(query) }) { return 1 }
        for token in tokens {
            let inLabel = terms.label.contains(token)
            let inTags = terms.tags.contains { $0.contains(token) }
            if !inLabel && !inTags { return nil }
        }
        return terms.label.contains(query) ? 2 : 3
    }
}

final class EmojiStore: ObservableObject {
    @Published private(set) var isLoaded = false
    @Published private(set) var sectionsByGroup: [(group: EmojiGroup, emoji: [Emoji])] = []

    private var index = EmojiSearchIndex(emoji: [])
    private var byString: [String: Emoji] = [:]

    static func bundledDataURL() -> URL {
        guard let url = Bundle.main.url(forResource: "emoji", withExtension: "json") else {
            fatalError("emoji.json is missing from the app bundle")
        }
        return url
    }

    static func decode(_ data: Data) throws -> [Emoji] {
        try JSONDecoder().decode([Emoji].self, from: data)
    }

    func loadInBackground(from url: URL = bundledDataURL()) {
        DispatchQueue.global(qos: .userInitiated).async {
            let data = try! Data(contentsOf: url)
            let emoji = EmojiRenderability.filter(try! Self.decode(data)).sorted { $0.order < $1.order }
            let index = EmojiSearchIndex(emoji: emoji)
            let byString = Dictionary(uniqueKeysWithValues: emoji.map { ($0.emoji, $0) })
            let groups = EmojiGroup.allCases.compactMap { group -> (group: EmojiGroup, emoji: [Emoji])? in
                let members = emoji.filter { $0.group == group.rawValue }
                return members.isEmpty ? nil : (group, members)
            }
            DispatchQueue.main.async {
                self.index = index
                self.byString = byString
                self.sectionsByGroup = groups
                self.isLoaded = true
            }
        }
    }

    func search(_ query: String) -> [Emoji] {
        index.search(query)
    }

    func emoji(for string: String) -> Emoji? {
        byString[string]
    }
}
