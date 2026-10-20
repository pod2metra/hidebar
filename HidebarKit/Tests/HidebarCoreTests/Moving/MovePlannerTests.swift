import Testing

@testable import HidebarCore

@Suite struct MovePlannerTests {
    private func items(_ names: String, fixed: String = "") -> [MenuBarItem] {
        names.map { moveItem(String($0), movable: !fixed.contains($0)) }
    }

    private func ids(_ names: String) -> [MenuBarItemID] {
        names.map { moveID(String($0)) }
    }

    private func step(_ item: Character, _ side: DropSide, _ anchor: Character) -> MoveStep {
        MoveStep(item: moveItem(String(item)), anchor: moveID(String(anchor)), side: side)
    }

    /// What the bar looks like after the drags, if each lands exactly beside its anchor.
    private func apply(_ steps: [MoveStep], to order: [MenuBarItemID]) -> [MenuBarItemID] {
        var result = order
        for step in steps {
            result.removeAll { $0 == step.item.id }
            let anchor = result.firstIndex(of: step.anchor)!
            result.insert(step.item.id, at: step.side == .leftOf ? anchor : anchor + 1)
        }
        return result
    }

    @Test func barAlreadyInOrderNeedsNoSteps() {
        #expect(MovePlanner.plan(current: items("abc"), desired: ids("abc")) == [])
    }

    @Test func nothingToPlanForEmptyInputs() {
        #expect(MovePlanner.plan(current: [], desired: ids("ab")) == [])
        #expect(MovePlanner.plan(current: items("ab"), desired: []) == [])
    }

    @Test func swappingTwoItemsIsOneDrag() {
        let steps = MovePlanner.plan(current: items("ab"), desired: ids("ba"))
        #expect(steps == [step("b", .leftOf, "a")])
    }

    @Test func lastItemToTheFrontDropsLeftOfTheFirst() {
        let steps = MovePlanner.plan(current: items("abc"), desired: ids("cab"))
        #expect(steps == [step("c", .leftOf, "a")])
    }

    @Test func firstItemToTheEndDropsRightOfTheLast() {
        let steps = MovePlanner.plan(current: items("abc"), desired: ids("bca"))
        #expect(steps == [step("a", .rightOf, "c")])
    }

    @Test func reversingFourItemsTakesThreeDragsAndReachesTheOrder() {
        let steps = MovePlanner.plan(current: items("abcd"), desired: ids("dcba"))
        #expect(steps.count == 3)
        #expect(apply(steps, to: ids("abcd")) == ids("dcba"))
    }

    @Test func stepsBuildTheFinalOrderFromTheFrontAnchoringOnTheItemPlacedBefore() {
        let steps = MovePlanner.plan(current: items("abcd"), desired: ids("dcba"))
        #expect(steps == [step("d", .leftOf, "a"), step("c", .rightOf, "d"), step("b", .rightOf, "c")])
    }

    @Test func stepCarriesTheObservedItemIncludingItsFlags() {
        let current = [
            MenuBarItem(
                id: moveID("a"), frame: ItemFrame(x: 7, y: 1, width: 2, height: 3), isMovable: true,
                isHidable: false),
            moveItem("b"),
        ]
        let steps = MovePlanner.plan(current: current, desired: ids("ba"))
        #expect(steps.count == 1)
        #expect(steps[0].item == moveItem("b"))
        #expect(steps[0].anchor == moveID("a"))
    }

    @Test func unmovableAndUnmentionedItemsAreNeitherDraggedNorUsedAsAnchors() {
        // x is unmovable and named by the desired order; u is not named at all.
        let current = items("axbuc", fixed: "x")
        let steps = MovePlanner.plan(current: current, desired: ids("cxba"))
        let touched = steps.flatMap { [$0.item.id, $0.anchor] }
        #expect(!touched.contains(moveID("x")))
        #expect(!touched.contains(moveID("u")))
        let managed = apply(steps, to: current.map(\.id)).filter { ids("abc").contains($0) }
        #expect(managed == ids("cba"))
    }

    @Test func idsThatAreNotOnTheBarAreIgnored() {
        let steps = MovePlanner.plan(current: items("ab"), desired: ids("zba"))
        #expect(steps == [step("b", .leftOf, "a")])
    }

    @Test func repeatedDesiredIdKeepsItsFirstPlace() {
        let steps = MovePlanner.plan(current: items("ab"), desired: ids("bab"))
        #expect(steps == [step("b", .leftOf, "a")])
    }

    @Test func itemsOutsideTheDesiredOrderStayWhereTheyAre() {
        let steps = MovePlanner.plan(current: items("abc"), desired: ids("ca"))
        #expect(steps == [step("c", .leftOf, "a")])
    }

    // MARK: exhaustive check against a brute-force minimum

    private func permutations(_ count: Int) -> [[Int]] {
        guard count > 0 else { return [[]] }
        return permutations(count - 1).flatMap { shorter in
            (0...shorter.count).map { slot in
                var next = shorter
                next.insert(count - 1, at: slot)
                return next
            }
        }
    }

    /// Fewest "take one item out, put it anywhere" moves from the identity order to each permutation,
    /// never taking out `pinned`.
    private func minimumMoves(_ count: Int, pinned: Int? = nil) -> [[Int]: Int] {
        let start = Array(0..<count)
        var distance = [start: 0]
        var frontier = [start]
        while !frontier.isEmpty {
            var next: [[Int]] = []
            for state in frontier {
                for from in state.indices where state[from] != pinned {
                    for to in state.indices where to != from {
                        var moved = state
                        moved.insert(moved.remove(at: from), at: to)
                        if distance[moved] == nil {
                            distance[moved] = distance[state]! + 1
                            next.append(moved)
                        }
                    }
                }
            }
            frontier = next
        }
        return distance
    }

    // MARK: pinned item

    @Test func pinnedItemIsAnAnchorAndNeverDraggedWhenOthersHaveToCrossIt() {
        // x sep a b → hide a and b: the icons cross the separator, the separator does not move.
        let current = items("xsab")
        let steps = MovePlanner.plan(current: current, desired: ids("absx"), pinned: moveID("s"))
        #expect(steps.count == 3)
        #expect(!steps.map(\.item.id).contains(moveID("s")))
        #expect(apply(steps, to: current.map(\.id)) == ids("absx"))
    }

    @Test func pinnedItemThatIsNotAmongTheManagedItemsChangesNothing() {
        let plain = MovePlanner.plan(current: items("abc"), desired: ids("cab"))
        #expect(MovePlanner.plan(current: items("abc"), desired: ids("cab"), pinned: moveID("zz")) == plain)
        #expect(MovePlanner.plan(current: items("abc"), desired: ids("cab"), pinned: moveID("a")) == plain)
    }

    @Test func pinnedItemAtTheEndsOfTheBarStaysToo() {
        for pinned in ["a", "e"] {
            let current = items("abcde")
            let steps = MovePlanner.plan(current: current, desired: ids("edcba"), pinned: moveID(pinned))
            #expect(!steps.map(\.item.id).contains(moveID(pinned)))
            #expect(apply(steps, to: current.map(\.id)) == ids("edcba"))
        }
    }

    @Test func pinnedPlansAreMinimalAndNeverDragTheirPinnedItem() {
        let names = Array("abcde")
        for pinned in names.indices {
            let minimum = minimumMoves(5, pinned: pinned)
            for permutation in permutations(5) {
                let desired = permutation.map { moveID(String(names[$0])) }
                let current = items("abcde")
                let steps = MovePlanner.plan(
                    current: current, desired: desired, pinned: moveID(String(names[pinned])))
                #expect(steps.count == minimum[permutation])
                #expect(!steps.map(\.item.id).contains(moveID(String(names[pinned]))))
                #expect(apply(steps, to: current.map(\.id)) == desired)
            }
        }
    }

    @Test(arguments: [false, true])
    func everyOrderOfFiveIsReachedInTheMinimumNumberOfDrags(withBystanders: Bool) {
        let names = Array("abcde")
        let minimum = minimumMoves(5)
        for permutation in permutations(5) {
            let desired = permutation.map { moveID(String(names[$0])) }
            // Bystanders: unmovable x, u, v and an unmentioned y wedged between the managed items.
            let layout = withBystanders ? "axbycudve" : "abcde"
            let current = items(layout, fixed: "xuv")
            let steps = MovePlanner.plan(current: current, desired: desired)

            let managed = Set(ids("abcde"))
            #expect(steps.count == minimum[permutation])
            #expect(steps.allSatisfy { managed.contains($0.item.id) && managed.contains($0.anchor) })
            let reached = apply(steps, to: current.map(\.id)).filter(managed.contains)
            #expect(reached == desired)
        }
    }
}
