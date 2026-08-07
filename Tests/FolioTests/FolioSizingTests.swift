// Copyright © 2026 Daniel Inoa.

import Testing
import UIKit

@testable import Folio

extension FolioViewTests {
  @Test
  @MainActor
  func sizingUsesAConfiguredRetainedPrototypeAndCurrentWidth() async {
    let recorder = SizingRecorder()
    let row = RecordingRow(id: .first, scale: 0.5, value: "First", recorder: recorder)
    let folioView = FolioView<TestSectionID, TestRowID>(style: .plain)
    let indexPath = IndexPath(row: 0, section: 0)

    await apply(makeFolio([(.primary, [row])]), to: folioView, animated: false)
    folioView.frame = CGRect(x: 0, y: 0, width: 321, height: 480)

    let firstHeight = folioView.tableView(folioView, heightForRowAt: indexPath)
    let secondHeight = folioView.tableView(folioView, heightForRowAt: indexPath)

    folioView.frame.size.width = 201
    let thirdHeight = folioView.tableView(folioView, heightForRowAt: indexPath)

    #expect(firstHeight == 161)
    #expect(secondHeight == 161)
    #expect(thirdHeight == 101)

    let measurements = recorder.events.compactMap(\.measurement)
    #expect(measurements.count == 3)
    #expect(measurements.map(\.proposedWidth) == [321, 321, 201])
    #expect(Set(measurements.map(\.cellID)).count == 1)

    #expect(recorder.events.count == 6)
    for index in stride(from: 0, to: recorder.events.count, by: 2) {
      #expect(recorder.events[index].isConfiguration)
      #expect(recorder.events[index + 1].measurement != nil)
    }
  }

  @Test
  @MainActor
  func displayCellIsTypedConfiguredAndDistinctFromSizingPrototype() async throws {
    let recorder = SizingRecorder()
    let row = RecordingRow(id: .first, scale: 0.5, value: "Display", recorder: recorder)
    let folioView = FolioView<TestSectionID, TestRowID>(style: .plain)
    let indexPath = IndexPath(row: 0, section: 0)

    await apply(makeFolio([(.primary, [row])]), to: folioView, animated: false)
    folioView.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
    _ = folioView.tableView(folioView, heightForRowAt: indexPath)

    let displayCell = try #require(
      folioView.dataSource?.tableView(folioView, cellForRowAt: indexPath)
    )
    let typedDisplayCell = try #require(displayCell as? RecordingCell)
    let sizingCellID = try #require(
      recorder.events.compactMap(\.measurement).first?.cellID
    )

    #expect(typedDisplayCell.value == "Display")
    #expect(ObjectIdentifier(typedDisplayCell) != sizingCellID)

    guard case .configure(let configuredCellID, _, _) = recorder.events.last else {
      Issue.record("Expected display-cell configuration to be the last event")
      return
    }
    #expect(configuredCellID == ObjectIdentifier(displayCell))
  }

  @Test
  @MainActor
  func tableRemeasuresRowsAfterItsWidthChanges() async {
    let recorder = SizingRecorder()
    let row = RecordingRow(id: .first, scale: 0.5, value: "Width", recorder: recorder)
    let host = FolioViewHost()
    let folioView = host.folioView
    defer { host.tearDown() }
    let indexPath = IndexPath(row: 0, section: 0)
    await apply(makeFolio([(.primary, [row])]), to: folioView, animated: false)
    folioView.layoutIfNeeded()
    let firstHeight = folioView.rectForRow(at: indexPath).height

    recorder.events.removeAll()
    folioView.frame.size.width = 200
    folioView.setNeedsLayout()
    folioView.layoutIfNeeded()
    let secondHeight = folioView.rectForRow(at: indexPath).height

    #expect(firstHeight == 160)
    #expect(secondHeight == 100)
    #expect(
      recorder.events.compactMap(\.measurement).contains { measurement in
        measurement.proposedWidth == 200
      })
  }
}
