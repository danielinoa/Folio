// Copyright © 2026 Daniel Inoa.

import UIKit

@testable import Folio

@MainActor
final class SizingRecorder {
  enum Event {
    case configure(ObjectIdentifier, scale: CGFloat, value: String)
    case measure(cellID: ObjectIdentifier, proposedWidth: CGFloat)

    var isConfiguration: Bool {
      if case .configure = self { true } else { false }
    }

    var measurement: Measurement? {
      guard case .measure(let cellID, let proposedWidth) = self else {
        return nil
      }
      return Measurement(cellID: cellID, proposedWidth: proposedWidth)
    }
  }

  struct Measurement {
    let cellID: ObjectIdentifier
    let proposedWidth: CGFloat
  }

  var events: [Event] = []
}

@MainActor
final class SelectionRecorder {
  var values: [String] = []
}

@MainActor
struct RecordingRow: Row {
  let id: TestRowID
  let scale: CGFloat
  let value: String
  let recorder: SizingRecorder
  let onSelect: () -> Void
  let cellReuseID: String

  init(
    id: TestRowID,
    scale: CGFloat,
    value: String,
    recorder: SizingRecorder,
    cellReuseID: String = "RecordingCell",
    onSelect: @escaping () -> Void = {}
  ) {
    self.id = id
    self.scale = scale
    self.value = value
    self.recorder = recorder
    self.cellReuseID = cellReuseID
    self.onSelect = onSelect
  }

  func configure(_ cell: RecordingCell) {
    cell.scale = scale
    cell.value = value
    cell.recorder = recorder
    recorder.events.append(
      .configure(ObjectIdentifier(cell), scale: scale, value: value)
    )
  }

  func didSelect() {
    onSelect()
  }
}

@MainActor
final class RecordingCell: UITableViewCell, SizingCell {
  var scale: CGFloat = 0
  var value = ""
  var recorder: SizingRecorder?

  func heightThatFits(width: CGFloat) -> CGFloat {
    recorder?.events.append(
      .measure(
        cellID: ObjectIdentifier(self),
        proposedWidth: width
      )
    )
    return width * scale
  }
}

@MainActor
struct AlternateRow: Row {
  let id: TestRowID
  let value: String
  let cellReuseID: String

  init(
    id: TestRowID,
    value: String = "Alternate",
    cellReuseID: String = "AlternateCell"
  ) {
    self.id = id
    self.value = value
    self.cellReuseID = cellReuseID
  }

  func configure(_ cell: AlternateCell) {
    cell.value = value
  }
}

@MainActor
final class AlternateCell: UITableViewCell, SizingCell {
  var value = ""

  func heightThatFits(width: CGFloat) -> CGFloat {
    44
  }
}
