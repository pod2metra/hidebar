import Testing

@testable import HidebarCore

@Suite struct UserMessagesTests {
    @Test func aSuccessfulClickNeedsNoMessage() {
        #expect(UserMessages.text(for: ClickOutcome.clicked) == nil)
    }

    @Test func everyOtherClickOutcomeHasItsOwnMessage() {
        let refusals: [ClickRefusal] = [
            .displacedItemPending, .notManaged, .unmovable, .noHomeAnchor, .notLocated,
        ]
        let outcomes: [ClickOutcome] = refusals.map { .refused($0) } + [.revealFailed, .clickFailed]
        let texts = outcomes.compactMap { UserMessages.text(for: $0) }
        #expect(texts.count == outcomes.count)
        #expect(Set(texts).count == outcomes.count)
        #expect(UserMessages.text(for: ClickOutcome.refused(.notLocated)) == UserMessages.text(for: ClickRefusal.notLocated))
    }

    @Test func everyCollapseRefusalHasItsOwnMessage() {
        let refusals: [CollapseRefusal] = [.separatorNotOnBar, .arrowWouldHide]
        let texts = refusals.map { UserMessages.text(for: $0) }
        #expect(Set(texts).count == refusals.count)
        #expect(texts.allSatisfy { !$0.isEmpty })
    }
}
