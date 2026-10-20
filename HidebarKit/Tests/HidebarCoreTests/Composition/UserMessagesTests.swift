import Testing

@testable import HidebarCore

@Suite struct UserMessagesTests {
    private let item = MenuBarItemID(ownerBundleID: "com.example.app", title: "Status")
    private let names = ItemNames(apps: StubAppNames(names: ["com.example.app": "Example"]))

    @Test func refusedApplyExplainsThatNothingWasMovedOrSaved() {
        let text = UserMessages.text(for: ApplyRefusal.displacedIconPending)
        #expect(text.contains("nothing was moved or saved"))
    }

    @Test func separatorUnavailableAsksForAccessibility() {
        let text = UserMessages.text(for: ApplyFailure.separatorUnavailable, names: names)
        #expect(text.contains("separator"))
        #expect(text.contains("Accessibility"))
    }

    @Test func stoppedMoveNamesTheStepTheIconAndWhatHappened() {
        let text = UserMessages.text(
            for: .moveStopped(stepIndex: 1, item: item, outcome: .failed), names: names)
        #expect(text.contains("Step 2"))
        #expect(text.contains("Example — Status"))
        #expect(!text.contains("com.example.app"))
        #expect(text.contains("did not end up in place"))
        #expect(text.contains("Nothing was saved"))
    }

    @Test func eachMoveOutcomeHasItsOwnWording() {
        let words = [MoveOutcome.moved, .unmovable, .failed].map { UserMessages.text(for: $0) }
        #expect(words == ["moved", "cannot be moved", "did not end up in place"])
    }

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

    @Test func refusedStoreSaysNothingWillBeSavedAndNamesTheVersion() {
        for error in [
            LayoutStoreError.unsupportedVersion(7), .refusingToOverwriteNewerVersion(7),
        ] {
            let text = UserMessages.text(for: ApplyFailure.storeRefused(error), names: names)
            #expect(text == UserMessages.text(for: error))
            #expect(text.contains("version 7"))
            #expect(text.contains("nothing will be saved"))
        }
    }

    @Test func failedStoreCarriesItsReason() {
        #expect(UserMessages.text(for: .storeFailed("disk full"), names: names).contains("disk full"))
    }

    @Test func rejectedEditsExplainThemselves() {
        func text(_ error: any Error) -> String { UserMessages.text(forEditError: error, names: names) }
        #expect(text(LayoutEditError.notHidable(item)).contains("Example — Status must stay"))
        #expect(text(LayoutEditError.unknownItem(item)).contains("icon"))
        #expect(text(LayoutEditError.unknownGroup(.init())).contains("group"))
        #expect(text(LayoutEditError.indexOutOfRange(9)).contains("dropped"))
    }

    @Test func anyOtherEditErrorIsShownAsRejected() {
        let text = UserMessages.text(forEditError: GroupSymbolError.unknownSymbol("nope"), names: names)
        #expect(text.contains("rejected"))
        #expect(text.contains("nope"))
    }

    @Test func onlyUnreadableDataIsWorthANotice() {
        #expect(UserMessages.notice(for: .missing) == nil)
        #expect(UserMessages.notice(for: .loaded) == nil)
        #expect(
            UserMessages.notice(for: .recoveredFromCorruption(reason: "x"))?.contains("could not be read")
                == true)
    }
}
