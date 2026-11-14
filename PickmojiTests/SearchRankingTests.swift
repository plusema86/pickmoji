import XCTest
@testable import Pickmoji

final class SearchRankingTests: XCTestCase {
    private func emoji(_ symbol: String, _ label: String, tags: [String] = [], order: Int) -> Emoji {
        Emoji(emoji: symbol, label: label, tags: tags, group: 0, order: order, skins: [])
    }

    private let catFace = "🐱"
    private let grinningCat = "😺"
    private let vacation = "🏖️"
    private let scatterDog = "🐶"
    private let unrelated = "🚀"

    private var index: EmojiSearchIndex {
        EmojiSearchIndex(emoji: [
            emoji(grinningCat, "grinning cat", order: 1),
            emoji(vacation, "vacation", order: 2),
            emoji(scatterDog, "dog", tags: ["scatter"], order: 3),
            emoji(catFace, "cat", order: 4),
            emoji(unrelated, "rocket", order: 5),
        ])
    }

    func testLabelPrefixRanksAboveWordPrefixAboveSubstring() {
        let results = index.search("cat").map(\.emoji)
        XCTAssertEqual(results, [catFace, grinningCat, vacation, scatterDog])
    }

    func testSearchIsCaseInsensitive() {
        XCTAssertEqual(index.search("CAT").map(\.emoji), index.search("cat").map(\.emoji))
        XCTAssertEqual(index.search("  Cat ").map(\.emoji), index.search("cat").map(\.emoji))
    }

    func testSearchToleratesAccentsApostrophesAndWhitespace() {
        let index = EmojiSearchIndex(emoji: [
            emoji("🗑️", "cestino dell’immondizia", tags: ["rifiùti"], order: 1),
        ])
        XCTAssertEqual(index.search("  CESTINO\tDELL'IMMONDIZIA  ").map(\.emoji), ["🗑️"])
        XCTAssertEqual(index.search("rifiuti").map(\.emoji), ["🗑️"])
    }

    func testItalianMatchesRankBeforeEnglishFallback() {
        let index = EmojiSearchIndex(emoji: [
            Emoji(emoji: "🎸", label: "chitarra", tags: [], group: 7, order: 1, skins: [],
                  englishLabel: "music", englishTags: ["guitar"]),
            emoji("🎵", "nota musicale", order: 2),
        ])
        XCTAssertEqual(index.search("music").map(\.emoji), ["🎵", "🎸"])
        XCTAssertEqual(index.search("guitar").map(\.emoji), ["🎸"])
    }

    func testBundledDataIncludesItalianNamesKeywordsAndSynonyms() throws {
        let data = try Data(contentsOf: EmojiStore.bundledDataURL())
        let emoji = try EmojiStore.decode(data)
        XCTAssertTrue(emoji.allSatisfy { !$0.label.isEmpty && !$0.tags.isEmpty && $0.englishLabel != nil })

        let index = EmojiSearchIndex(emoji: emoji)
        XCTAssertEqual(index.search("cuore rosso").first?.emoji, "❤️")
        XCTAssertTrue(index.search("felicita").contains { $0.emoji == "😂" })
        XCTAssertTrue(index.search("gattino").contains { $0.emoji == "🐱" })
        XCTAssertTrue(index.search("spunta verde").contains { $0.emoji == "✅\u{FE0F}" })
        XCTAssertTrue(index.search("red heart").contains { $0.emoji == "❤️" })
    }

    func testTagPrefixMatchesRankWithWordPrefixes() {
        let index = EmojiSearchIndex(emoji: [
            emoji("😀", "smile", tags: ["grin"], order: 1),
            emoji("😁", "beaming face", tags: ["grinning"], order: 2),
            emoji("😺", "grinning cat", order: 3),
        ])
        XCTAssertEqual(index.search("gri").map(\.emoji), ["😺", "😀", "😁"])
    }

    func testTiesBreakByOrder() {
        let index = EmojiSearchIndex(emoji: [
            emoji("🐈", "cat", order: 9),
            emoji("🐱", "cat face", order: 2),
        ])
        XCTAssertEqual(index.search("cat").map(\.emoji), ["🐱", "🐈"])
    }

    func testEmptyQueryReturnsEverythingInOrder() {
        XCTAssertEqual(index.search("").count, 5)
        XCTAssertEqual(index.search("   ").map(\.emoji), [grinningCat, vacation, scatterDog, catFace, unrelated])
    }

    func testMultiWordQueryRequiresEveryToken() {
        let index = EmojiSearchIndex(emoji: [
            emoji("❤️", "red heart", order: 1),
            emoji("💙", "blue heart", order: 2),
            emoji("🔴", "red circle", order: 3),
        ])
        XCTAssertEqual(index.search("red heart").map(\.emoji), ["❤️"])
        XCTAssertEqual(index.search("heart red").map(\.emoji), ["❤️"])
        XCTAssertEqual(index.search("heart").map(\.emoji), ["❤️", "💙"])
    }

    func testNoMatchesReturnsEmpty() {
        XCTAssertTrue(index.search("zzzz").isEmpty)
    }
}
