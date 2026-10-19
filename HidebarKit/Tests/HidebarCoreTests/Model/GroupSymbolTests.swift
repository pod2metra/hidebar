import Foundation
import Testing

@testable import HidebarCore

@Suite struct GroupSymbolTests {
    private static let catalogDoc: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // Model
        .deletingLastPathComponent()  // HidebarCoreTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // HidebarKit
        .deletingLastPathComponent()  // repository root
        .appendingPathComponent("docs/SYMBOL_CATALOG.md")

    /// `(category, symbol)` pairs from the markdown table rows of `docs/SYMBOL_CATALOG.md`.
    private func documentedSymbols() throws -> [[String]] {
        let text = try String(contentsOf: Self.catalogDoc, encoding: .utf8)
        return text.split(separator: "\n").compactMap { line in
            let cells = line.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard cells.count >= 4, cells[2].hasPrefix("`"), cells[2].hasSuffix("`") else {
                return nil
            }
            return [cells[1], String(cells[2].dropFirst().dropLast())]
        }
    }

    @Test func catalogMatchesTableInDocs() throws {
        let documented = try documentedSymbols()
        let inCode = SymbolCatalog.categories.flatMap { category in
            category.symbols.map { [category.name, $0] }
        }
        #expect(documented.count == 40)
        #expect(inCode.count == documented.count)
        #expect(inCode == documented)
    }

    @Test func everyCatalogSymbolIsAccepted() throws {
        for category in SymbolCatalog.categories {
            for name in category.symbols {
                #expect(try GroupSymbol(name: name).name == name)
            }
        }
    }

    @Test func unknownSymbolIsRejectedWithTypedError() {
        #expect(throws: GroupSymbolError.unknownSymbol("not.a.symbol")) {
            try GroupSymbol(name: "not.a.symbol")
        }
    }

    @Test func emptyNameIsRejected() {
        #expect(throws: GroupSymbolError.unknownSymbol("")) {
            try GroupSymbol(name: "")
        }
    }

    @Test func catalogContainsOnlyListedNames() {
        #expect(SymbolCatalog.contains("briefcase"))
        #expect(!SymbolCatalog.contains("Briefcase"))
        #expect(!SymbolCatalog.contains("tag "))
    }

    @Test func symbolEncodesAsPlainString() throws {
        let symbol = try GroupSymbol(name: "star")
        #expect(String(decoding: try JSONEncoder().encode(["s": symbol]), as: UTF8.self) == #"{"s":"star"}"#)
    }

    @Test func symbolDecodesFromCatalogName() throws {
        let decoded = try JSONDecoder().decode([String: GroupSymbol].self, from: Data(#"{"s":"star"}"#.utf8))
        #expect(decoded["s"] == (try GroupSymbol(name: "star")))
    }

    @Test func decodingUnknownSymbolFails() {
        #expect(throws: GroupSymbolError.unknownSymbol("bogus")) {
            try JSONDecoder().decode([String: GroupSymbol].self, from: Data(#"{"s":"bogus"}"#.utf8))
        }
    }
}
