// Copyright © 2026 Daniel Inoa.

import Testing
import UIKit

@testable import Folio

@Suite
@MainActor
struct RowBuilderTests {
  @Test
  func emptyBuilderProducesAnEmptySection() {
    let section = Section<BuilderSectionID, BuilderRowID>(id: .main) {}

    #expect(section.rows.isEmpty)
  }

  @Test
  func builderPreservesHeterogeneousRowsAndSectionBoundaries() {
    let recorder = BoundaryRecorder()
    let header = RecordingBoundary(
      value: "Header",
      height: 20,
      recorder: recorder,
      viewReuseID: "BuilderHeader"
    )
    let footer = RecordingBoundary(
      value: "Footer",
      height: 16,
      recorder: recorder,
      viewReuseID: "BuilderFooter"
    )
    let section = Section<BuilderSectionID, BuilderRowID>(
      id: .main,
      header: header,
      footer: footer
    ) {
      BuilderRow(id: .always)
      AlternateBuilderRow(id: .alternate)
    }

    #expect(section.id == .main)
    #expect(section.rows.map { $0.id } == [.always, .alternate])
    #expect(section.rows[0] is BuilderRow)
    #expect(section.rows[1] is AlternateBuilderRow)
    #expect((section.header as? RecordingBoundary)?.value == "Header")
    #expect((section.footer as? RecordingBoundary)?.value == "Footer")
  }

  @Test
  func builderSupportsConditionalBranchesAndSwitches() {
    let included = makeConditionalSection(
      includeOptional: true,
      useFirstChoice: true,
      branch: .second
    )
    let omitted = makeConditionalSection(
      includeOptional: false,
      useFirstChoice: false,
      branch: .first
    )

    #expect(
      included.rows.map { $0.id } == [
        .always,
        .optional,
        .firstChoice,
        .secondBranch,
      ])
    #expect(
      omitted.rows.map { $0.id } == [
        .always,
        .secondChoice,
        .firstBranch,
      ])
  }

  @Test
  func builderFlattensLoopsAndHelperArraysInOrder() {
    let concreteRows = [
      BuilderRow(id: .helper(1)),
      BuilderRow(id: .helper(2)),
    ]
    let erasedRows: [any Row<BuilderRowID>] = [
      AlternateBuilderRow(id: .erased(1)),
      BuilderRow(id: .erased(2)),
    ]
    let erasedRow: any Row<BuilderRowID> = BuilderRow(id: .erased(0))
    let section = Section<BuilderSectionID, BuilderRowID>(id: .main) {
      for value in [1, 2] {
        BuilderRow(id: .generated(value))
      }

      concreteRows
      erasedRow
      erasedRows
    }

    #expect(
      section.rows.map { $0.id } == [
        .generated(1),
        .generated(2),
        .helper(1),
        .helper(2),
        .erased(0),
        .erased(1),
        .erased(2),
      ])
  }

  @Test
  func builderSupportsAvailabilityChecks() {
    let section = Section<BuilderSectionID, BuilderRowID>(id: .main) {
      if #available(iOS 26, *) {
        FutureBuilderRow(id: .available)
      } else {
        BuilderRow(id: .available)
      }
    }

    #expect(section.rows.map { $0.id } == [.available])
  }
}

private enum BuilderSectionID: Hashable, Sendable {
  case main
}

private enum BuilderRowID: Hashable, Sendable {
  case always
  case optional
  case firstChoice
  case secondChoice
  case firstBranch
  case secondBranch
  case generated(Int)
  case helper(Int)
  case erased(Int)
  case alternate
  case available
}

private enum BuilderBranch {
  case first
  case second
}

@MainActor
private func makeConditionalSection(
  includeOptional: Bool,
  useFirstChoice: Bool,
  branch: BuilderBranch
) -> Section<BuilderSectionID, BuilderRowID> {
  Section(id: .main) {
    BuilderRow(id: .always)

    if includeOptional {
      BuilderRow(id: .optional)
    }

    if useFirstChoice {
      BuilderRow(id: .firstChoice)
    } else {
      BuilderRow(id: .secondChoice)
    }

    switch branch {
    case .first:
      BuilderRow(id: .firstBranch)
    case .second:
      BuilderRow(id: .secondBranch)
    }
  }
}

@MainActor
private struct BuilderRow: Row {
  let id: BuilderRowID
  let cellReuseID = "BuilderCell"

  func configure(_ cell: BuilderCell) {
    cell.rowID = id
  }
}

@MainActor
private final class BuilderCell: UITableViewCell, SizingCell {
  var rowID: BuilderRowID?

  func heightThatFits(width: CGFloat) -> CGFloat {
    44
  }
}

@MainActor
private struct AlternateBuilderRow: Row {
  let id: BuilderRowID
  let cellReuseID = "AlternateBuilderCell"

  func configure(_ cell: AlternateBuilderCell) {
    cell.rowID = id
  }
}

@MainActor
private final class AlternateBuilderCell: UITableViewCell, SizingCell {
  var rowID: BuilderRowID?

  func heightThatFits(width: CGFloat) -> CGFloat {
    44
  }
}

@available(iOS 26, *)
@MainActor
private struct FutureBuilderRow: Row {
  let id: BuilderRowID
  let cellReuseID = "FutureBuilderCell"

  func configure(_ cell: BuilderCell) {
    cell.rowID = id
  }
}
