// Copyright © 2026 Daniel Inoa.

import Testing
import UIKit

@testable import Folio

extension FolioViewTests {
  @Test
  @MainActor
  func selectiveApplyUpdatesOnlyRequestedRowInPlace() async throws {
    let recorder = SizingRecorder()
    let host = FolioViewHost(
      style: .plain,
      size: CGSize(width: 320, height: 480)
    )
    let folioView = host.folioView
    defer { host.tearDown() }

    await apply(
      makeContent([
        (
          .primary,
          [
            RecordingRow(
              id: .first,
              scale: 0.1,
              value: "Initial first",
              recorder: recorder
            ),
            RecordingRow(
              id: .second,
              scale: 0.2,
              value: "Initial second",
              recorder: recorder
            ),
          ]
        )
      ]),
      to: folioView,
      animated: false
    )
    folioView.layoutIfNeeded()

    let firstCell = try #require(
      folioView.cellForRow(at: IndexPath(row: 0, section: 0)) as? RecordingCell
    )
    let secondCell = try #require(
      folioView.cellForRow(at: IndexPath(row: 1, section: 0)) as? RecordingCell
    )
    #expect(folioView.rectForRow(at: IndexPath(row: 0, section: 0)).height == 32)
    secondCell.value = "Transient second"

    await apply(
      makeContent([
        (
          .primary,
          [
            RecordingRow(
              id: .first,
              scale: 0.4,
              value: "Updated first",
              recorder: recorder
            ),
            RecordingRow(
              id: .second,
              scale: 0.2,
              value: "Initial second",
              recorder: recorder
            ),
          ]
        )
      ]),
      to: folioView,
      rowReconfiguration: .only([.first]),
      animated: false
    )
    folioView.layoutIfNeeded()

    let retainedFirstCell = try #require(
      folioView.cellForRow(at: IndexPath(row: 0, section: 0)) as? RecordingCell
    )
    let retainedSecondCell = try #require(
      folioView.cellForRow(at: IndexPath(row: 1, section: 0)) as? RecordingCell
    )

    #expect(retainedFirstCell === firstCell)
    #expect(retainedFirstCell.value == "Updated first")
    #expect(folioView.rectForRow(at: IndexPath(row: 0, section: 0)).height == 128)
    #expect(retainedSecondCell === secondCell)
    #expect(retainedSecondCell.value == "Transient second")
  }

  @Test
  @MainActor
  func nonePolicyPreservesEditingStateAndConfiguresInsertedRows() async throws {
    let host = FolioViewHost(
      style: .plain,
      size: CGSize(width: 320, height: 480)
    )
    let folioView = host.folioView
    defer { host.tearDown() }

    await apply(
      makeContent([
        (
          .primary,
          [
            EditingRow(id: .first, configuredText: "Persisted value")
          ]
        )
      ]),
      to: folioView,
      animated: false
    )
    folioView.layoutIfNeeded()

    let editingCell = try #require(
      folioView.cellForRow(at: IndexPath(row: 0, section: 0)) as? EditingCell
    )
    let textField = editingCell.textField
    textField.text = "Transient draft"
    #expect(textField.becomeFirstResponder())
    let selection = try #require(textRange(2..<11, in: textField))
    textField.selectedTextRange = selection

    await apply(
      makeContent([
        (
          .primary,
          [
            EditingRow(id: .first, configuredText: "Persisted value"),
            EditingRow(id: .second, configuredText: "Inserted value"),
          ]
        )
      ]),
      to: folioView,
      rowReconfiguration: .none,
      animated: true
    )
    folioView.layoutIfNeeded()

    let retainedEditingCell = try #require(
      folioView.cellForRow(at: IndexPath(row: 0, section: 0)) as? EditingCell
    )
    let insertedCell = try #require(
      folioView.cellForRow(at: IndexPath(row: 1, section: 0)) as? EditingCell
    )

    #expect(retainedEditingCell === editingCell)
    #expect(retainedEditingCell.textField.text == "Transient draft")
    #expect(retainedEditingCell.textField.isFirstResponder)
    #expect(selectedOffsets(in: retainedEditingCell.textField) == 2..<11)
    #expect(insertedCell.textField.text == "Inserted value")
  }

  @Test
  @MainActor
  func selectionUsesLatestDescriptorWhenRetainedCellIsNotReconfigured() async {
    let recorder = SizingRecorder()
    let selectionRecorder = SelectionRecorder()
    let folioView = FolioView<TestSectionID, TestRowID>(style: .plain)

    await apply(
      makeContent([
        (
          .primary,
          [
            RecordingRow(
              id: .first,
              scale: 0.2,
              value: "Initial",
              recorder: recorder,
              onSelect: { selectionRecorder.values.append("initial") }
            )
          ]
        )
      ]),
      to: folioView,
      animated: false
    )

    await apply(
      makeContent([
        (
          .primary,
          [
            RecordingRow(
              id: .first,
              scale: 0.2,
              value: "Updated",
              recorder: recorder,
              onSelect: { selectionRecorder.values.append("updated") }
            )
          ]
        )
      ]),
      to: folioView,
      rowReconfiguration: .none,
      animated: false
    )

    folioView.tableView(
      folioView,
      didSelectRowAt: IndexPath(row: 0, section: 0)
    )

    #expect(selectionRecorder.values == ["updated"])
  }
}

@MainActor
private struct EditingRow: Row {
  let id: TestRowID
  let configuredText: String
  let cellReuseID = "SelectiveEditingCell"

  func configure(_ cell: EditingCell) {
    cell.textField.text = configuredText
  }
}

@MainActor
private final class EditingCell: UITableViewCell, SizingCell {
  let textField = UITextField()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)

    selectionStyle = .none
    contentView.addSubview(textField)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    textField.frame = contentView.bounds.insetBy(dx: 16, dy: 8)
  }

  func heightThatFits(width: CGFloat) -> CGFloat {
    52
  }
}

@MainActor
private func apply(
  _ content: Content<TestSectionID, TestRowID>,
  to folioView: FolioView<TestSectionID, TestRowID>,
  rowReconfiguration: RowReconfiguration<TestRowID>,
  animated: Bool
) async {
  await withCheckedContinuation { continuation in
    folioView.apply(
      content,
      rowReconfiguration: rowReconfiguration,
      animatingDifferences: animated,
      completion: { continuation.resume() }
    )
  }
}

@MainActor
private func textRange(
  _ offsets: Range<Int>,
  in textField: UITextField
) -> UITextRange? {
  guard
    let start = textField.position(
      from: textField.beginningOfDocument,
      offset: offsets.lowerBound
    ),
    let end = textField.position(
      from: textField.beginningOfDocument,
      offset: offsets.upperBound
    )
  else {
    return nil
  }
  return textField.textRange(from: start, to: end)
}

@MainActor
private func selectedOffsets(in textField: UITextField) -> Range<Int>? {
  guard let range = textField.selectedTextRange else { return nil }

  let start = textField.offset(
    from: textField.beginningOfDocument,
    to: range.start
  )
  let end = textField.offset(
    from: textField.beginningOfDocument,
    to: range.end
  )
  return start..<end
}
