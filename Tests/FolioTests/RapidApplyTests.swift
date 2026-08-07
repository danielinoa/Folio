// Copyright © 2026 Daniel Inoa.

import Testing
import UIKit

@testable import Folio

extension FolioViewTests {
  @Test
  @MainActor
  func rapidAppliesSettleOnTheNewestSnapshotAndDescriptor() async throws {
    let recorder = SizingRecorder()
    let headerFooterRecorder = BoundaryRecorder()
    let selectionRecorder = SelectionRecorder()
    let host = FolioViewHost(
      style: .plain,
      size: CGSize(width: 320, height: 480)
    )
    let folioView = host.folioView
    defer { host.tearDown() }

    await apply(
      Folio(
        sections: [
          makeBoundarySection(
            id: .primary,
            value: "A",
            rows: [
              RecordingRow(id: .first, scale: 0.2, value: "A", recorder: recorder)
            ],
            recorder: headerFooterRecorder
          )
        ]
      ),
      to: folioView,
      animated: false
    )

    folioView.apply(
      Folio(
        sections: [
          makeBoundarySection(
            id: .primary,
            value: "B",
            rows: [
              RecordingRow(id: .first, scale: 0.2, value: "B", recorder: recorder),
              RecordingRow(
                id: .second,
                scale: 0.2,
                value: "Temporary",
                recorder: recorder
              ),
            ],
            recorder: headerFooterRecorder
          )
        ]
      ),
      animatingDifferences: true
    )

    let newestRow = RecordingRow(
      id: .first,
      scale: 0.2,
      value: "C",
      recorder: recorder,
      onSelect: { selectionRecorder.values.append("C") }
    )
    await apply(
      Folio(
        sections: [
          makeBoundarySection(
            id: .secondary,
            value: "C",
            rows: [newestRow],
            recorder: headerFooterRecorder
          )
        ]
      ),
      to: folioView,
      animated: true
    )
    folioView.layoutIfNeeded()

    #expect(folioView.numberOfSections == 1)
    #expect(folioView.numberOfRows(inSection: 0) == 1)
    let cell = try #require(
      folioView.cellForRow(at: IndexPath(row: 0, section: 0)) as? RecordingCell
    )
    #expect(cell.value == "C")
    #expect(recordingHeader(in: folioView, section: 0)?.value == "C header")
    #expect(recordingFooter(in: folioView, section: 0)?.value == "C footer")

    folioView.tableView(
      folioView,
      didSelectRowAt: IndexPath(row: 0, section: 0)
    )
    #expect(selectionRecorder.values == ["C"])
  }

  @Test
  @MainActor
  func rapidAppliesRemoveStaleHeadersAndFootersUsingNewestSnapshot() async throws {
    let rowRecorder = SizingRecorder()
    let headerFooterRecorder = BoundaryRecorder()
    let host = FolioViewHost(
      style: .plain,
      size: CGSize(width: 320, height: 640)
    )
    let folioView = host.folioView
    defer { host.tearDown() }

    await apply(
      makeSingleSectionFolio(
        sectionID: .primary,
        header: RecordingBoundary(
          value: "A header",
          height: 32,
          recorder: headerFooterRecorder,
          viewReuseID: "RapidHeader"
        ),
        footer: RecordingBoundary(
          value: "A footer",
          height: 24,
          recorder: headerFooterRecorder,
          viewReuseID: "RapidFooter"
        ),
        rows: [
          RecordingRow(
            id: .first,
            scale: 0.2,
            value: "A",
            recorder: rowRecorder
          )
        ]
      ),
      to: folioView,
      animated: false
    )
    folioView.layoutIfNeeded()

    let initialHeaderContainer = try #require(
      folioView.headerView(forSection: 0) as? HeaderFooterContainerView
    )
    let initialFooterContainer = try #require(
      folioView.footerView(forSection: 0) as? HeaderFooterContainerView
    )
    #expect(initialHeaderContainer.hostedView != nil)
    #expect(initialFooterContainer.hostedView != nil)

    folioView.apply(
      makeSingleSectionFolio(
        sectionID: .primary,
        rows: [
          RecordingRow(
            id: .first,
            scale: 0.2,
            value: "B",
            recorder: rowRecorder
          ),
          RecordingRow(
            id: .second,
            scale: 0.2,
            value: "Temporary",
            recorder: rowRecorder
          ),
        ]
      ),
      animatingDifferences: true
    )

    var newestCompletionCount = 0
    await withCheckedContinuation { continuation in
      folioView.apply(
        makeSingleSectionFolio(
          sectionID: .primary,
          rows: [
            RecordingRow(
              id: .first,
              scale: 0.2,
              value: "C",
              recorder: rowRecorder
            )
          ]
        ),
        animatingDifferences: true
      ) {
        newestCompletionCount += 1
        continuation.resume()
      }
    }
    folioView.layoutIfNeeded()

    let finalCell = try #require(
      folioView.cellForRow(at: IndexPath(row: 0, section: 0)) as? RecordingCell
    )
    let finalHeaderContainer = try #require(
      folioView.headerView(forSection: 0) as? HeaderFooterContainerView
    )
    let finalFooterContainer = try #require(
      folioView.footerView(forSection: 0) as? HeaderFooterContainerView
    )

    #expect(newestCompletionCount == 1)
    #expect(folioView.numberOfRows(inSection: 0) == 1)
    #expect(finalCell.value == "C")
    #expect(finalHeaderContainer === initialHeaderContainer)
    #expect(finalFooterContainer === initialFooterContainer)
    #expect(finalHeaderContainer.isHidden)
    #expect(finalFooterContainer.isHidden)
    #expect(finalHeaderContainer.hostedView == nil)
    #expect(finalFooterContainer.hostedView == nil)
    #expect(folioView.rectForHeader(inSection: 0).height < 1)
    #expect(folioView.rectForFooter(inSection: 0).height < 1)
  }
}
