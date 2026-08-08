// Copyright © 2026 Daniel Inoa.

import Testing
import UIKit

@testable import Folio

extension FolioViewTests {
  @Test
  @MainActor
  func headersAndFootersFollowSectionIdentityAcrossStructuralChanges() async throws {
    let rowRecorder = SizingRecorder()
    let headerFooterRecorder = BoundaryRecorder()
    let host = FolioViewHost(
      style: .plain,
      size: CGSize(width: 320, height: 800)
    )
    let folioView = host.folioView
    defer { host.tearDown() }
    let primaryRow = RecordingRow(
      id: .first,
      scale: 0.1,
      value: "Primary",
      recorder: rowRecorder
    )
    let secondaryRow = RecordingRow(
      id: .second,
      scale: 0.1,
      value: "Secondary",
      recorder: rowRecorder
    )

    await apply(
      Content(
        sections: [
          makeBoundarySection(
            id: .primary,
            value: "Primary 1",
            rows: [primaryRow],
            recorder: headerFooterRecorder
          ),
          makeBoundarySection(
            id: .secondary,
            value: "Secondary 1",
            rows: [secondaryRow],
            recorder: headerFooterRecorder
          ),
        ]
      ),
      to: folioView,
      animated: false
    )
    folioView.layoutIfNeeded()

    let initialPrimaryCell = try #require(
      folioView.cellForRow(at: IndexPath(row: 0, section: 0))
    )
    let initialSecondaryCell = try #require(
      folioView.cellForRow(at: IndexPath(row: 0, section: 1))
    )
    #expect(recordingHeader(in: folioView, section: 0)?.value == "Primary 1 header")
    #expect(recordingFooter(in: folioView, section: 0)?.value == "Primary 1 footer")
    #expect(recordingHeader(in: folioView, section: 1)?.value == "Secondary 1 header")
    #expect(recordingFooter(in: folioView, section: 1)?.value == "Secondary 1 footer")

    await apply(
      Content(
        sections: [
          makeBoundarySection(
            id: .tertiary,
            value: "Tertiary 1",
            recorder: headerFooterRecorder
          ),
          makeBoundarySection(
            id: .secondary,
            value: "Secondary 2",
            rows: [secondaryRow],
            recorder: headerFooterRecorder
          ),
          makeBoundarySection(
            id: .primary,
            value: "Primary 2",
            rows: [primaryRow],
            recorder: headerFooterRecorder
          ),
        ]
      ),
      to: folioView,
      animated: true
    )
    folioView.layoutIfNeeded()

    #expect(recordingHeader(in: folioView, section: 0)?.value == "Tertiary 1 header")
    #expect(recordingFooter(in: folioView, section: 0)?.value == "Tertiary 1 footer")
    #expect(recordingHeader(in: folioView, section: 1)?.value == "Secondary 2 header")
    #expect(recordingFooter(in: folioView, section: 1)?.value == "Secondary 2 footer")
    #expect(recordingHeader(in: folioView, section: 2)?.value == "Primary 2 header")
    #expect(recordingFooter(in: folioView, section: 2)?.value == "Primary 2 footer")
    #expect(
      folioView.cellForRow(at: IndexPath(row: 0, section: 1)) === initialSecondaryCell
    )
    #expect(
      folioView.cellForRow(at: IndexPath(row: 0, section: 2)) === initialPrimaryCell
    )

    await apply(
      Content(
        sections: [
          makeBoundarySection(
            id: .primary,
            value: "Primary 3",
            rows: [primaryRow],
            recorder: headerFooterRecorder
          ),
          makeBoundarySection(
            id: .tertiary,
            value: "Tertiary 2",
            recorder: headerFooterRecorder
          ),
        ]
      ),
      to: folioView,
      animated: true
    )
    folioView.layoutIfNeeded()

    #expect(recordingHeader(in: folioView, section: 0)?.value == "Primary 3 header")
    #expect(recordingFooter(in: folioView, section: 0)?.value == "Primary 3 footer")
    #expect(recordingHeader(in: folioView, section: 1)?.value == "Tertiary 2 header")
    #expect(recordingFooter(in: folioView, section: 1)?.value == "Tertiary 2 footer")
    #expect(
      folioView.cellForRow(at: IndexPath(row: 0, section: 0)) === initialPrimaryCell
    )
  }

  @Test
  @MainActor
  func retainedSectionReconfiguresAndRemeasuresHeadersAndFootersWithoutReloadingRows()
    async throws
  {
    let rowRecorder = SizingRecorder()
    let headerFooterRecorder = BoundaryRecorder()
    let host = FolioViewHost(
      style: .plain,
      size: CGSize(width: 320, height: 640)
    )
    let folioView = host.folioView
    defer { host.tearDown() }
    let row = RecordingRow(
      id: .first,
      scale: 0.2,
      value: "Retained",
      recorder: rowRecorder
    )

    await apply(
      makeSingleSectionContent(
        sectionID: .primary,
        header: RecordingBoundary(
          value: "Initial header",
          height: 32,
          recorder: headerFooterRecorder,
          viewReuseID: "RecordingHeader"
        ),
        footer: RecordingBoundary(
          value: "Initial footer",
          height: 24,
          recorder: headerFooterRecorder,
          viewReuseID: "RecordingFooter"
        ),
        rows: [row]
      ),
      to: folioView,
      animated: false
    )
    folioView.layoutIfNeeded()

    let indexPath = IndexPath(row: 0, section: 0)
    let initialCell = try #require(folioView.cellForRow(at: indexPath))
    let initialHeaderContainer = try #require(
      folioView.headerView(forSection: 0) as? HeaderFooterContainerView
    )
    let initialFooterContainer = try #require(
      folioView.footerView(forSection: 0) as? HeaderFooterContainerView
    )
    let initialHeader = try #require(
      initialHeaderContainer.hostedView as? RecordingBoundaryView
    )
    let initialFooter = try #require(
      initialFooterContainer.hostedView as? RecordingBoundaryView
    )
    #expect(initialHeader.value == "Initial header")
    #expect(initialFooter.value == "Initial footer")
    #expect(folioView.rectForHeader(inSection: 0).height == 32)
    #expect(folioView.rectForFooter(inSection: 0).height == 24)

    await apply(
      makeSingleSectionContent(
        sectionID: .primary,
        header: RecordingBoundary(
          value: "Updated header",
          height: 72,
          recorder: headerFooterRecorder,
          viewReuseID: "RecordingHeader"
        ),
        footer: RecordingBoundary(
          value: "Updated footer",
          height: 48,
          recorder: headerFooterRecorder,
          viewReuseID: "RecordingFooter"
        ),
        rows: [row]
      ),
      to: folioView,
      animated: true
    )
    folioView.layoutIfNeeded()

    let updatedCell = try #require(folioView.cellForRow(at: indexPath))
    let updatedHeaderContainer = try #require(
      folioView.headerView(forSection: 0) as? HeaderFooterContainerView
    )
    let updatedFooterContainer = try #require(
      folioView.footerView(forSection: 0) as? HeaderFooterContainerView
    )
    let updatedHeader = try #require(
      updatedHeaderContainer.hostedView as? RecordingBoundaryView
    )
    let updatedFooter = try #require(
      updatedFooterContainer.hostedView as? RecordingBoundaryView
    )
    #expect(updatedCell === initialCell)
    #expect(updatedHeaderContainer === initialHeaderContainer)
    #expect(updatedFooterContainer === initialFooterContainer)
    #expect(updatedHeader === initialHeader)
    #expect(updatedFooter === initialFooter)
    #expect(updatedHeader.value == "Updated header")
    #expect(updatedFooter.value == "Updated footer")
    #expect(folioView.rectForHeader(inSection: 0).height == 72)
    #expect(folioView.rectForFooter(inSection: 0).height == 48)
    #expect(
      headerFooterRecorder.events.compactMap(\.measurement).contains { measurement in
        measurement.proposedWidth == 320
      }
    )
  }

  @Test
  @MainActor
  func retainedSectionReconcilesHeaderAndFooterIndependently() async throws {
    let rowRecorder = SizingRecorder()
    let headerFooterRecorder = BoundaryRecorder()
    let host = FolioViewHost(
      style: .plain,
      size: CGSize(width: 320, height: 640)
    )
    let folioView = host.folioView
    defer { host.tearDown() }
    let row = RecordingRow(
      id: .first,
      scale: 0.2,
      value: "Retained",
      recorder: rowRecorder
    )

    await apply(
      makeSingleSectionContent(
        sectionID: .primary,
        header: RecordingBoundary(
          value: "Initial header",
          height: 32,
          recorder: headerFooterRecorder,
          viewReuseID: "IndependentHeader"
        ),
        footer: RecordingBoundary(
          value: "Initial footer",
          height: 24,
          recorder: headerFooterRecorder,
          viewReuseID: "IndependentFooter"
        ),
        rows: [row]
      ),
      to: folioView,
      animated: false
    )
    folioView.layoutIfNeeded()

    let indexPath = IndexPath(row: 0, section: 0)
    let initialCell = try #require(folioView.cellForRow(at: indexPath))
    let initialHeaderContainer = try #require(
      folioView.headerView(forSection: 0) as? HeaderFooterContainerView
    )
    let initialFooterContainer = try #require(
      folioView.footerView(forSection: 0) as? HeaderFooterContainerView
    )
    let initialFooter = try #require(
      initialFooterContainer.hostedView as? RecordingBoundaryView
    )

    await apply(
      makeSingleSectionContent(
        sectionID: .primary,
        footer: RecordingBoundary(
          value: "Updated footer",
          height: 44,
          recorder: headerFooterRecorder,
          viewReuseID: "IndependentFooter"
        ),
        rows: [row]
      ),
      to: folioView,
      animated: true
    )
    folioView.layoutIfNeeded()

    let updatedHeaderContainer = try #require(
      folioView.headerView(forSection: 0) as? HeaderFooterContainerView
    )
    let updatedFooterContainer = try #require(
      folioView.footerView(forSection: 0) as? HeaderFooterContainerView
    )
    let updatedFooter = try #require(
      updatedFooterContainer.hostedView as? RecordingBoundaryView
    )

    #expect(folioView.cellForRow(at: indexPath) === initialCell)
    #expect(updatedHeaderContainer === initialHeaderContainer)
    #expect(updatedFooterContainer === initialFooterContainer)
    #expect(updatedHeaderContainer.isHidden)
    #expect(updatedHeaderContainer.hostedView == nil)
    #expect(updatedFooter === initialFooter)
    #expect(updatedFooter.value == "Updated footer")
    #expect(folioView.rectForHeader(inSection: 0).height < 1)
    #expect(folioView.rectForFooter(inSection: 0).height == 44)
  }

  @Test
  @MainActor
  func retainedSectionCanShowAndHideHeadersAndFootersWithoutReloadingRows() async throws {
    let rowRecorder = SizingRecorder()
    let headerFooterRecorder = BoundaryRecorder()
    let host = FolioViewHost(
      style: .plain,
      size: CGSize(width: 320, height: 640)
    )
    let folioView = host.folioView
    defer { host.tearDown() }
    let row = RecordingRow(
      id: .first,
      scale: 0.2,
      value: "Retained",
      recorder: rowRecorder
    )

    await apply(
      makeSingleSectionContent(sectionID: .primary, rows: [row]),
      to: folioView,
      animated: false
    )
    folioView.layoutIfNeeded()

    let indexPath = IndexPath(row: 0, section: 0)
    let initialCell = try #require(folioView.cellForRow(at: indexPath))
    let initialHeaderContainer = try #require(
      folioView.headerView(forSection: 0) as? HeaderFooterContainerView
    )
    let initialFooterContainer = try #require(
      folioView.footerView(forSection: 0) as? HeaderFooterContainerView
    )
    #expect(folioView.rectForHeader(inSection: 0).height < 1)
    #expect(folioView.rectForFooter(inSection: 0).height < 1)
    #expect(initialHeaderContainer.isHidden)
    #expect(initialFooterContainer.isHidden)
    #expect(initialHeaderContainer.hostedView == nil)
    #expect(initialFooterContainer.hostedView == nil)

    await apply(
      makeSingleSectionContent(
        sectionID: .primary,
        header: RecordingBoundary(
          value: "Shown header",
          height: 36,
          recorder: headerFooterRecorder,
          viewReuseID: "ConditionalHeader"
        ),
        footer: RecordingBoundary(
          value: "Shown footer",
          height: 28,
          recorder: headerFooterRecorder,
          viewReuseID: "ConditionalFooter"
        ),
        rows: [row]
      ),
      to: folioView,
      animated: true
    )
    folioView.layoutIfNeeded()

    let shownCell = try #require(folioView.cellForRow(at: indexPath))
    let shownHeaderContainer = try #require(
      folioView.headerView(forSection: 0) as? HeaderFooterContainerView
    )
    let shownFooterContainer = try #require(
      folioView.footerView(forSection: 0) as? HeaderFooterContainerView
    )
    let shownHeader = try #require(
      shownHeaderContainer.hostedView as? RecordingBoundaryView
    )
    let shownFooter = try #require(
      shownFooterContainer.hostedView as? RecordingBoundaryView
    )
    #expect(shownCell === initialCell)
    #expect(shownHeaderContainer === initialHeaderContainer)
    #expect(shownFooterContainer === initialFooterContainer)
    #expect(!shownHeaderContainer.isHidden)
    #expect(!shownFooterContainer.isHidden)
    #expect(shownHeader.value == "Shown header")
    #expect(shownFooter.value == "Shown footer")
    #expect(folioView.rectForHeader(inSection: 0).height == 36)
    #expect(folioView.rectForFooter(inSection: 0).height == 28)

    await apply(
      makeSingleSectionContent(sectionID: .primary, rows: [row]),
      to: folioView,
      animated: true
    )
    folioView.layoutIfNeeded()

    let hiddenCell = try #require(folioView.cellForRow(at: indexPath))
    let hiddenHeaderContainer = try #require(
      folioView.headerView(forSection: 0) as? HeaderFooterContainerView
    )
    let hiddenFooterContainer = try #require(
      folioView.footerView(forSection: 0) as? HeaderFooterContainerView
    )
    #expect(hiddenCell === initialCell)
    #expect(hiddenHeaderContainer === initialHeaderContainer)
    #expect(hiddenFooterContainer === initialFooterContainer)
    #expect(folioView.rectForHeader(inSection: 0).height < 1)
    #expect(folioView.rectForFooter(inSection: 0).height < 1)
    #expect(hiddenHeaderContainer.isHidden)
    #expect(hiddenFooterContainer.isHidden)
    #expect(hiddenHeaderContainer.hostedView == nil)
    #expect(hiddenFooterContainer.hostedView == nil)
  }

  @Test
  @MainActor
  func insetGroupedSectionCanShowAndHideHeadersAndFootersWithoutReloadingRows()
    async throws
  {
    let rowRecorder = SizingRecorder()
    let headerFooterRecorder = BoundaryRecorder()
    let host = FolioViewHost(
      style: .insetGrouped,
      size: CGSize(width: 390, height: 844)
    )
    let folioView = host.folioView
    defer { host.tearDown() }
    let row = RecordingRow(
      id: .first,
      scale: 0.2,
      value: "Retained",
      recorder: rowRecorder
    )

    await apply(
      makeSingleSectionContent(sectionID: .primary, rows: [row]),
      to: folioView,
      animated: false
    )
    folioView.layoutIfNeeded()

    let indexPath = IndexPath(row: 0, section: 0)
    let initialCell = try #require(folioView.cellForRow(at: indexPath))
    #expect(folioView.rectForHeader(inSection: 0).height < 1)
    #expect(folioView.rectForFooter(inSection: 0).height < 1)

    await apply(
      makeSingleSectionContent(
        sectionID: .primary,
        header: RecordingBoundary(
          value: "Grouped header",
          height: 42,
          recorder: headerFooterRecorder,
          viewReuseID: "GroupedHeader"
        ),
        footer: RecordingBoundary(
          value: "Grouped footer",
          height: 34,
          recorder: headerFooterRecorder,
          viewReuseID: "GroupedFooter"
        ),
        rows: [row]
      ),
      to: folioView,
      animated: true
    )
    folioView.layoutIfNeeded()

    #expect(folioView.cellForRow(at: indexPath) === initialCell)
    #expect(recordingHeader(in: folioView, section: 0)?.value == "Grouped header")
    #expect(recordingFooter(in: folioView, section: 0)?.value == "Grouped footer")
    #expect(folioView.rectForHeader(inSection: 0).height == 42)
    #expect(folioView.rectForFooter(inSection: 0).height == 34)

    await apply(
      makeSingleSectionContent(sectionID: .primary, rows: [row]),
      to: folioView,
      animated: true
    )
    folioView.layoutIfNeeded()

    #expect(folioView.cellForRow(at: indexPath) === initialCell)
    #expect(folioView.rectForHeader(inSection: 0).height < 1)
    #expect(folioView.rectForFooter(inSection: 0).height < 1)
  }

  @Test
  @MainActor
  func tableRemeasuresHeadersAndFootersAfterItsWidthChanges() async {
    let rowRecorder = SizingRecorder()
    let headerFooterRecorder = BoundaryRecorder()
    let host = FolioViewHost(
      style: .plain,
      size: CGSize(width: 320, height: 640)
    )
    let folioView = host.folioView
    defer { host.tearDown() }
    let row = RecordingRow(
      id: .first,
      scale: 0.1,
      value: "Width",
      recorder: rowRecorder
    )

    await apply(
      makeSingleSectionContent(
        sectionID: .primary,
        header: WidthScaledBoundary(
          value: "Header",
          scale: 0.25,
          recorder: headerFooterRecorder,
          viewReuseID: "WidthHeader"
        ),
        footer: WidthScaledBoundary(
          value: "Footer",
          scale: 0.1,
          recorder: headerFooterRecorder,
          viewReuseID: "WidthFooter"
        ),
        rows: [row]
      ),
      to: folioView,
      animated: false
    )
    folioView.layoutIfNeeded()

    #expect(folioView.rectForHeader(inSection: 0).height == 80)
    #expect(folioView.rectForFooter(inSection: 0).height == 32)

    headerFooterRecorder.events.removeAll()
    folioView.frame.size.width = 200
    folioView.setNeedsLayout()
    folioView.layoutIfNeeded()

    #expect(folioView.rectForHeader(inSection: 0).height == 50)
    #expect(folioView.rectForFooter(inSection: 0).height == 20)
    #expect(
      headerFooterRecorder.events.compactMap(\.measurement).contains { measurement in
        measurement.proposedWidth == 200
      }
    )
  }
}
