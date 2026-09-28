import Foundation
import Testing
@testable import LinkRouter
@testable import LinkRouterCore

@MainActor
@Suite("Picker view model")
struct PickerViewModelTests {
    let targets = [
        BrowserTarget(bundleID: "c", appPath: "/", appName: "Google Chrome", profileDirectory: "Default", profileName: "Personal"),
        BrowserTarget(bundleID: "c", appPath: "/", appName: "Google Chrome", profileDirectory: "Profile 1", profileName: "Work"),
        BrowserTarget(bundleID: "s", appPath: "/", appName: "Safari"),
    ]
    let ctx = LinkContext(url: URL(string: "https://github.com/a")!, sourceBundleID: "com.jetbrains.intellij",
                          sourceAppName: "IntelliJ IDEA", windowTitle: "link-router – Rule.swift")

    func make() -> PickerViewModel {
        PickerViewModel(urls: [ctx.url], context: ctx, targets: targets)
    }

    @Test func tabOpensActionsForHighlightedBrowser() {
        let vm = make()
        vm.query = "wo"
        vm.toggleActions()
        #expect(vm.mode == .actions)
        #expect(vm.query.isEmpty)
        #expect(vm.filteredActions.map(\.action) == [.recordRule, .alwaysUse, .copyLink, .openSettings])
        #expect(vm.filteredActions[1].title == "Always open in Work")
        #expect(vm.filteredActions[1].subtitle == "Saves a rule for links from IntelliJ IDEA · link-router")
    }

    @Test func withoutALinkItOnlySwitches() {
        let vm = PickerViewModel(urls: [], context: nil, targets: targets)
        #expect(vm.isSwitching)
        vm.toggleActions()
        #expect(vm.mode == .browsers)  // no action menu while switching
        var chosen: BrowserTarget?
        vm.onChoose = { t, _ in chosen = t }
        vm.query = "work"
        vm.confirm()
        #expect(chosen?.profileDirectory == "Profile 1")
        #expect(vm.sourceDescription == nil)
    }

    @Test func leavingActionsRestoresBrowserFilterAndSelection() {
        let vm = make()
        vm.moveDown(); vm.moveDown()
        vm.toggleActions()
        vm.toggleActions()
        #expect(vm.mode == .browsers)
        #expect(vm.selected?.title == "Safari")
    }

    @Test func typingFiltersActions() {
        let vm = make()
        vm.toggleActions()
        vm.query = "copy"
        #expect(vm.filteredActions.map(\.action) == [.copyLink])
    }

    @Test func returnRunsActionWithTheBrowserFromBeforeTab() {
        let vm = make()
        var ran: (PickerAction, BrowserTarget?)?
        vm.onAction = { ran = ($0, $1) }
        vm.moveDown()
        vm.toggleActions()
        vm.moveDown()
        vm.confirm()
        #expect(ran?.0 == .alwaysUse)
        #expect(ran?.1?.title == "Work")
    }

    @Test func escBacksOutStepByStep() {
        let vm = make()
        var closed = false
        vm.onCancel = { closed = true }
        vm.toggleActions()
        vm.query = "x"
        vm.cancel()           // clears the filter
        #expect(vm.mode == .actions && !closed)
        vm.cancel()           // back to browsers
        #expect(vm.mode == .browsers && !closed)
        vm.cancel()           // closes
        #expect(closed)
    }

    @Test func returnInBrowsersOpensSelected() {
        let vm = make()
        var chosen: BrowserTarget?
        vm.onChoose = { t, remember in chosen = t; #expect(!remember) }
        vm.query = "saf"
        vm.confirm()
        #expect(chosen?.title == "Safari")
    }
}
