import Testing
@testable import ToonEdgeAppCore

@Test func successAndInfoFeedbackAutoDismissButProblemsWaitForTheReader() {
    #expect(TEFeedback(title: "Saved", tone: .success).autoDismissDelay == .seconds(5))
    #expect(TEFeedback(title: "No new chapters", tone: .info).autoDismissDelay == .seconds(5))
    #expect(TEFeedback(title: "Some updates unavailable", tone: .warning).autoDismissDelay == nil)
    #expect(TEFeedback(title: "Save failed", tone: .failure).autoDismissDelay == nil)
}

@Test func feedbackAnnouncementCombinesTitleAndDetail() {
    #expect(TEFeedback(title: "Saved to Library", tone: .success).announcement == "Saved to Library")
    #expect(
        TEFeedback(title: "Updates found", detail: "2 checked, 1 update", tone: .success).announcement
            == "Updates found. 2 checked, 1 update"
    )
}

@Test func feedbackBannerLayoutIsSlimBottomAlignedAndAccessible() {
    let layout = TEFeedbackBannerLayout()

    #expect(layout.placement == .bottom)
    #expect(layout.maximumWidth == 560)
    #expect(layout.dismissHitSize >= TEActionMetrics.minimumHitSize)
    #expect(layout.dismissAccessibilityLabel == "Dismiss")
    #expect(layout.maximumDynamicTypeSize == .accessibility1)
}

@Test func feedbackToneSetsIcon() {
    #expect(TEFeedback(title: "a", tone: .success).systemImage == "checkmark.circle.fill")
    #expect(TEFeedback(title: "a", tone: .info).systemImage == "info.circle.fill")
    #expect(TEFeedback(title: "a", tone: .warning).systemImage == "exclamationmark.triangle.fill")
    #expect(TEFeedback(title: "a", tone: .failure).systemImage == "exclamationmark.octagon.fill")
    #expect(TEFeedback(title: "a", tone: .success, systemImage: "bookmark.fill").systemImage == "bookmark.fill")
}

@Test func offlineActionFeedbackMapsToSharedBanner() {
    let success = TEFeedback(offlineAction: .success(.retained))
    let failure = TEFeedback(offlineAction: .failure("Couldn’t download this chapter."))

    #expect(success == TEFeedback(title: "Chapter downloaded for offline reading.", tone: .success, systemImage: "arrow.down.circle.fill"))
    #expect(failure == TEFeedback(title: "Couldn’t download this chapter.", tone: .failure))
}

@Test func libraryUpdateRefreshMapsToSharedBanner() {
    let found = TEFeedback(updateRefresh: .init(checkedCount: 2, updatedCount: 1, failedCount: 0))
    let none = TEFeedback(updateRefresh: .init(checkedCount: 3, updatedCount: 0, failedCount: 0))
    let partial = TEFeedback(updateRefresh: .init(checkedCount: 3, updatedCount: 1, failedCount: 1))
    let failed = TEFeedback(updateRefresh: .init(checkedCount: 2, updatedCount: 0, failedCount: 2))

    #expect(found == TEFeedback(title: "Updates found", detail: "2 checked, 1 update", tone: .success))
    #expect(none == TEFeedback(title: "No new chapters", detail: "3 checked, 0 updates", tone: .info))
    #expect(partial == TEFeedback(title: "Some updates unavailable", detail: "3 checked, 1 update, 1 failed", tone: .warning))
    #expect(failed == TEFeedback(title: "Update check failed", detail: "2 checked, 0 updates, 2 failed", tone: .failure))
}

@Test func librarySaveMapsToSharedBanner() {
    #expect(TEFeedback(librarySaveSucceeded: true) == TEFeedback(title: "Saved to Library", tone: .success, systemImage: "bookmark.fill"))
    #expect(TEFeedback(librarySaveSucceeded: false) == TEFeedback(title: "Couldn’t save this series", detail: "Try again.", tone: .failure))
}
