// Copyright © 2026 Daniel Inoa.

import Testing
import UIKit

@testable import Folio

extension FolioViewTests {
  @Test
  @MainActor
  func animatedApplyDiffsStructureAndReconfiguresRetainedRowHeightAndAction() async throws {
    let recorder = SizingRecorder()
    let host = FolioViewHost(
      style: .plain,
      size: CGSize(width: 320, height: 480)
    )
    let folioView = host.folioView
    defer { host.tearDown() }
    var oldSelectionCount = 0
    var newSelectionCount = 0

    let initialRow = RecordingRow(
      id: .first,
      scale: 0.1,
      value: "Old",
      recorder: recorder,
      onSelect: { oldSelectionCount += 1 }
    )
    await apply(
      makeFolio([(.primary, [initialRow])]),
      to: folioView,
      animated: false
    )
    folioView.layoutIfNeeded()
    let initialHeight = folioView.rectForRow(at: IndexPath(row: 0, section: 0)).height

    let updatedRow = RecordingRow(
      id: .first,
      scale: 0.4,
      value: "New",
      recorder: recorder,
      onSelect: { newSelectionCount += 1 }
    )
    let insertedRow = RecordingRow(
      id: .second,
      scale: 0.2,
      value: "Inserted",
      recorder: recorder
    )
    await apply(
      makeFolio([
        (.primary, [updatedRow, insertedRow]),
        (.secondary, []),
      ]),
      to: folioView,
      animated: true
    )
    folioView.layoutIfNeeded()

    #expect(folioView.numberOfSections == 2)
    #expect(folioView.numberOfRows(inSection: 0) == 2)
    #expect(initialHeight == 32)
    #expect(
      folioView.rectForRow(at: IndexPath(row: 0, section: 0)).height == 128
    )

    let updatedCell = try #require(
      folioView.cellForRow(at: IndexPath(row: 0, section: 0)) as? RecordingCell
    )
    #expect(updatedCell.value == "New")

    folioView.tableView(
      folioView,
      didSelectRowAt: IndexPath(row: 0, section: 0)
    )
    #expect(oldSelectionCount == 0)
    #expect(newSelectionCount == 1)
  }

  @Test
  @MainActor
  func selectionUsesIdentityAfterRowsAndSectionsMove() async {
    let recorder = SizingRecorder()
    let selectionRecorder = SelectionRecorder()
    let folioView = FolioView<TestSectionID, TestRowID>(style: .plain)
    let initialRow = RecordingRow(
      id: .first,
      scale: 0.2,
      value: "Initial",
      recorder: recorder,
      onSelect: { selectionRecorder.values.append("initial") }
    )

    await apply(
      makeFolio([(.primary, [initialRow]), (.secondary, [])]),
      to: folioView,
      animated: false
    )

    let movedRow = RecordingRow(
      id: .first,
      scale: 0.2,
      value: "Moved",
      recorder: recorder,
      onSelect: { selectionRecorder.values.append("moved") }
    )
    await apply(
      makeFolio([(.secondary, [movedRow]), (.primary, [])]),
      to: folioView,
      animated: true
    )

    folioView.tableView(
      folioView,
      didSelectRowAt: IndexPath(row: 0, section: 0)
    )
    #expect(selectionRecorder.values == ["moved"])
  }

  @Test
  @MainActor
  func applyingEmptyFolioRemovesAllContent() async {
    let recorder = SizingRecorder()
    let host = FolioViewHost(
      style: .plain,
      size: CGSize(width: 320, height: 480)
    )
    let folioView = host.folioView
    defer { host.tearDown() }

    await apply(
      makeFolio([
        (
          .primary,
          [
            RecordingRow(id: .first, scale: 0.2, value: "First", recorder: recorder)
          ]
        ),
        (
          .secondary,
          [
            RecordingRow(id: .second, scale: 0.2, value: "Second", recorder: recorder)
          ]
        ),
      ]),
      to: folioView,
      animated: false
    )
    #expect(folioView.numberOfSections == 2)

    await apply(Folio(), to: folioView, animated: true)
    folioView.layoutIfNeeded()

    #expect(folioView.numberOfSections == 0)
    #expect(folioView.indexPathsForVisibleRows?.isEmpty != false)
  }
}
