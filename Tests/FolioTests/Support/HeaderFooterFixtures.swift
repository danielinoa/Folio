// Copyright © 2026 Daniel Inoa.

import UIKit

@testable import Folio

@MainActor
func makeBoundarySection(
  id: TestSectionID,
  value: String,
  rows: [any Row<TestRowID>] = [],
  recorder: BoundaryRecorder
) -> Section<TestSectionID, TestRowID> {
  Section(
    id: id,
    header: RecordingBoundary(
      value: "\(value) header",
      height: 30,
      recorder: recorder,
      viewReuseID: "RecordingHeader"
    ),
    footer: RecordingBoundary(
      value: "\(value) footer",
      height: 20,
      recorder: recorder,
      viewReuseID: "RecordingFooter"
    ),
    rows: rows
  )
}

@MainActor
func recordingHeader(
  in tableView: UITableView,
  section: Int
) -> RecordingBoundaryView? {
  let container =
    tableView.headerView(forSection: section)
    as? HeaderFooterContainerView
  return container?.hostedView as? RecordingBoundaryView
}

@MainActor
func recordingFooter(
  in tableView: UITableView,
  section: Int
) -> RecordingBoundaryView? {
  let container =
    tableView.footerView(forSection: section)
    as? HeaderFooterContainerView
  return container?.hostedView as? RecordingBoundaryView
}

@MainActor
final class BoundaryRecorder {
  enum Event {
    case configure(viewID: ObjectIdentifier, value: String, height: CGFloat)
    case measure(viewID: ObjectIdentifier, proposedWidth: CGFloat)

    var measurement: Measurement? {
      guard case .measure(let viewID, let proposedWidth) = self else {
        return nil
      }
      return Measurement(viewID: viewID, proposedWidth: proposedWidth)
    }
  }

  struct Measurement {
    let viewID: ObjectIdentifier
    let proposedWidth: CGFloat
  }

  var events: [Event] = []
}

@MainActor
struct RecordingBoundary: SectionHeader, SectionFooter {
  let value: String
  let height: CGFloat
  let recorder: BoundaryRecorder
  let viewReuseID: String

  func configure(_ view: RecordingBoundaryView) {
    view.value = value
    view.measuredHeight = height
    view.recorder = recorder
    recorder.events.append(
      .configure(
        viewID: ObjectIdentifier(view),
        value: value,
        height: height
      )
    )
  }
}

@MainActor
final class RecordingBoundaryView: UIView, SizingSectionView {
  var value = ""
  var measuredHeight: CGFloat = 0
  var recorder: BoundaryRecorder?

  override init(frame: CGRect) {
    super.init(frame: frame)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func heightThatFits(width: CGFloat) -> CGFloat {
    recorder?.events.append(
      .measure(
        viewID: ObjectIdentifier(self),
        proposedWidth: width
      )
    )
    return measuredHeight
  }
}

@MainActor
struct AlternateHeader: SectionHeader {
  let viewReuseID: String

  func configure(_ view: AlternateBoundaryView) {}
}

@MainActor
struct AlternateFooter: SectionFooter {
  let viewReuseID: String

  func configure(_ view: AlternateBoundaryView) {}
}

@MainActor
final class AlternateBoundaryView: UIView, SizingSectionView {
  override init(frame: CGRect) {
    super.init(frame: frame)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func heightThatFits(width: CGFloat) -> CGFloat {
    44
  }
}

@MainActor
struct WidthScaledBoundary: SectionHeader, SectionFooter {
  let value: String
  let scale: CGFloat
  let recorder: BoundaryRecorder
  let viewReuseID: String

  func configure(_ view: WidthScaledBoundaryView) {
    view.value = value
    view.scale = scale
    view.recorder = recorder
    recorder.events.append(
      .configure(
        viewID: ObjectIdentifier(view),
        value: value,
        height: scale
      )
    )
  }
}

@MainActor
final class WidthScaledBoundaryView: UIView, SizingSectionView {
  var value = ""
  var scale: CGFloat = 0
  var recorder: BoundaryRecorder?

  override init(frame: CGRect) {
    super.init(frame: frame)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func heightThatFits(width: CGFloat) -> CGFloat {
    recorder?.events.append(
      .measure(
        viewID: ObjectIdentifier(self),
        proposedWidth: width
      )
    )
    return width * scale
  }
}
