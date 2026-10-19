public enum GroupSymbolError: Error, Equatable, Sendable {
    case unknownSymbol(String)
}

/// SF Symbol name labelling a group in the menu bar; always a member of `SymbolCatalog`.
public struct GroupSymbol: Hashable, Codable, Sendable {
    public let name: String

    public init(name: String) throws {
        guard SymbolCatalog.contains(name) else {
            throw GroupSymbolError.unknownSymbol(name)
        }
        self.name = name
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(name: container.decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(name)
    }
}
