// Copyright © 2026 Daniel Inoa.

import Testing

@testable import Folio

@Suite
@MainActor
struct SectionBuilderTests {
  @Test
  func emptyBuilderAndDefaultInitializerProduceEmptySnapshots() {
    let built = Content<BuilderSectionID, TestRowID> {}
    let defaulted = Content<BuilderSectionID, TestRowID>()

    #expect(built.sections.isEmpty)
    #expect(defaulted.sections.isEmpty)
  }

  @Test
  func builderPreservesSectionOrderContentAndBoundaries() {
    let recorder = BoundaryRecorder()
    let primary = Section(
      id: BuilderSectionID.always,
      header: RecordingBoundary(
        value: "Header",
        height: 20,
        recorder: recorder,
        viewReuseID: "BuilderHeader"
      ),
      footer: RecordingBoundary(
        value: "Footer",
        height: 16,
        recorder: recorder,
        viewReuseID: "BuilderFooter"
      )
    ) {
      AlternateRow(id: .first)
    }
    let content = Content {
      primary
      Section(id: .optional) {
        AlternateRow(id: .second)
      }
    }

    #expect(content.sections.map { $0.id } == [.always, .optional])
    #expect(content.sections[0].rows.map { $0.id } == [.first])
    #expect(content.sections[1].rows.map { $0.id } == [.second])
    #expect((content.sections[0].header as? RecordingBoundary)?.value == "Header")
    #expect((content.sections[0].footer as? RecordingBoundary)?.value == "Footer")
  }

  @Test
  func builderSupportsConditionalBranchesAndSwitches() {
    let included = makeConditionalContent(
      includeOptional: true,
      useFirstChoice: true,
      branch: .second
    )
    let omitted = makeConditionalContent(
      includeOptional: false,
      useFirstChoice: false,
      branch: .first
    )

    #expect(
      included.sections.map { $0.id } == [
        .always,
        .optional,
        .firstChoice,
        .secondBranch,
      ])
    #expect(
      omitted.sections.map { $0.id } == [
        .always,
        .secondChoice,
        .firstBranch,
      ])
  }

  @Test
  func builderFlattensLoopsAndHelperArraysInOrder() {
    let helperSections: [Section<BuilderSectionID, TestRowID>] = [
      Section(id: .helper(1), rows: []),
      Section(id: .helper(2), rows: []),
    ]
    let content = Content<BuilderSectionID, TestRowID> {
      for value in [1, 2] {
        Section(id: .generated(value), rows: [])
      }

      helperSections
    }

    #expect(
      content.sections.map { $0.id } == [
        .generated(1),
        .generated(2),
        .helper(1),
        .helper(2),
      ])
  }

  @Test
  func builderSupportsAvailabilityChecks() {
    let content = Content<BuilderSectionID, TestRowID> {
      if #available(iOS 26, *) {
        futureSection()
      } else {
        Section(id: .available, rows: [])
      }
    }

    #expect(content.sections.map { $0.id } == [.available])
  }
}

private enum BuilderSectionID: Hashable, Sendable {
  case always
  case optional
  case firstChoice
  case secondChoice
  case firstBranch
  case secondBranch
  case generated(Int)
  case helper(Int)
  case available
}

private enum SectionBuilderBranch {
  case first
  case second
}

@MainActor
private func makeConditionalContent(
  includeOptional: Bool,
  useFirstChoice: Bool,
  branch: SectionBuilderBranch
) -> Content<BuilderSectionID, TestRowID> {
  Content {
    Section(id: .always, rows: [])

    if includeOptional {
      Section(id: .optional, rows: [])
    }

    if useFirstChoice {
      Section(id: .firstChoice, rows: [])
    } else {
      Section(id: .secondChoice, rows: [])
    }

    switch branch {
    case .first:
      Section(id: .firstBranch, rows: [])
    case .second:
      Section(id: .secondBranch, rows: [])
    }
  }
}

@available(iOS 26, *)
@MainActor
private func futureSection() -> Section<BuilderSectionID, TestRowID> {
  Section(id: .available, rows: [])
}
