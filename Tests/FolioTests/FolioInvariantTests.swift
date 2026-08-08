// Copyright © 2026 Daniel Inoa.

import Testing
import UIKit

@testable import Folio

@Test
@MainActor
func validatorRejectsDuplicateSectionIDs() {
  let content = Content<TestSectionID, TestRowID>(
    sections: [
      Section(id: .primary, rows: []),
      Section(id: .primary, rows: []),
    ]
  )

  let result = SnapshotValidator<TestSectionID, TestRowID>().prepare(content)

  guard case .failure(.duplicateSectionID(let sectionID)) = result else {
    Issue.record("Expected duplicate section identity validation to fail")
    return
  }
  #expect(sectionID == .primary)
}

@Test
@MainActor
func validatorRejectsDuplicateRowIDsWithinASection() {
  let recorder = SizingRecorder()
  let row = RecordingRow(id: .first, scale: 0.2, value: "First", recorder: recorder)
  let content = makeContent([(.primary, [row, row])])

  let result = SnapshotValidator<TestSectionID, TestRowID>().prepare(content)

  guard case .failure(.duplicateRowID(let rowID)) = result else {
    Issue.record("Expected duplicate row identity validation to fail")
    return
  }
  #expect(rowID == .first)
}

@Test
@MainActor
func validatorRejectsDuplicateRowIDsAcrossSections() {
  let recorder = SizingRecorder()
  let first = RecordingRow(id: .first, scale: 0.2, value: "First", recorder: recorder)
  let duplicate = RecordingRow(
    id: .first,
    scale: 0.3,
    value: "Duplicate",
    recorder: recorder
  )
  let content = makeContent([
    (.primary, [first]),
    (.secondary, [duplicate]),
  ])

  let result = SnapshotValidator<TestSectionID, TestRowID>().prepare(content)

  guard case .failure(.duplicateRowID(let rowID)) = result else {
    Issue.record("Expected globally duplicate row identity validation to fail")
    return
  }
  #expect(rowID == .first)
}

@Test
@MainActor
func validatorRejectsOneReuseIDForDifferentCellClasses() {
  let recorder = SizingRecorder()
  let content = makeContent([
    (
      .primary,
      [
        RecordingRow(
          id: .first,
          scale: 0.2,
          value: "First",
          recorder: recorder,
          cellReuseID: "SharedReuseID"
        ),
        AlternateRow(id: .second, cellReuseID: "SharedReuseID"),
      ]
    )
  ])

  let result = SnapshotValidator<TestSectionID, TestRowID>().prepare(content)

  guard
    case .failure(
      .conflictingCellRegistration(
        let reuseID,
        let registeredCellTypeName,
        let proposedCellTypeName
      )
    ) = result
  else {
    Issue.record("Expected conflicting cell registration validation to fail")
    return
  }
  #expect(reuseID == "SharedReuseID")
  #expect(registeredCellTypeName == String(reflecting: RecordingCell.self))
  #expect(proposedCellTypeName == String(reflecting: AlternateCell.self))
}

@Test
@MainActor
func validatorRejectsARegisteredReuseIDForADifferentCellClass() throws {
  let recorder = SizingRecorder()
  let initialContent = makeContent([
    (
      .primary,
      [
        RecordingRow(
          id: .first,
          scale: 0.2,
          value: "First",
          recorder: recorder,
          cellReuseID: "PersistentReuseID"
        )
      ]
    )
  ])
  let initial = try SnapshotValidator<TestSectionID, TestRowID>()
    .prepare(initialContent)
    .get()
  let validator = SnapshotValidator<TestSectionID, TestRowID>(
    existingCellRegistrations: initial.cellRegistrations,
    existingRowRenderingIdentities: initial.rowRenderingIdentities
  )
  let laterContent = makeContent([
    (
      .secondary,
      [
        AlternateRow(id: .second, cellReuseID: "PersistentReuseID")
      ]
    )
  ])

  let result = validator.prepare(laterContent)

  guard
    case .failure(
      .conflictingCellRegistration(let reuseID, _, let proposedCellTypeName)
    ) = result
  else {
    Issue.record("Expected a historical cell registration conflict to fail")
    return
  }
  #expect(reuseID == "PersistentReuseID")
  #expect(proposedCellTypeName == String(reflecting: AlternateCell.self))
}

@Test
@MainActor
func validatorRejectsAChangedRowRenderingIdentityForAnExistingRowID() throws {
  let recorder = SizingRecorder()
  let initialContent = makeContent([
    (
      .primary,
      [
        RecordingRow(id: .first, scale: 0.2, value: "First", recorder: recorder)
      ]
    )
  ])
  let initial = try SnapshotValidator<TestSectionID, TestRowID>()
    .prepare(initialContent)
    .get()
  let changedContent = makeContent([
    (
      .primary,
      [
        RecordingRow(
          id: .first,
          scale: 0.2,
          value: "Changed",
          recorder: recorder,
          cellReuseID: "ChangedReuseID"
        )
      ]
    )
  ])
  let validator = SnapshotValidator<TestSectionID, TestRowID>(
    existingCellRegistrations: initial.cellRegistrations,
    existingRowRenderingIdentities: initial.rowRenderingIdentities
  )

  let result = validator.prepare(changedContent)

  guard
    case .failure(
      .changedRowRenderingIdentity(let rowID, let original, let proposed)
    ) = result
  else {
    Issue.record("Expected changed row rendering identity validation to fail")
    return
  }
  #expect(rowID == .first)
  #expect(original.cellReuseID == "RecordingCell")
  #expect(proposed.cellReuseID == "ChangedReuseID")
  #expect(original.cellTypeID == proposed.cellTypeID)
}

@Test
@MainActor
func validatorSupportsHeterogeneousRowsWithDistinctCellTypes() throws {
  let recorder = SizingRecorder()
  let content = makeContent([
    (
      .primary,
      [
        RecordingRow(id: .first, scale: 0.2, value: "First", recorder: recorder),
        AlternateRow(id: .second),
      ]
    )
  ])

  let prepared = try SnapshotValidator<TestSectionID, TestRowID>()
    .prepare(content)
    .get()

  #expect(prepared.snapshot.sectionIdentifiers == [.primary])
  #expect(prepared.snapshot.itemIdentifiers == [.first, .second])
  #expect(
    prepared.rowsByID[.first]?.renderingIdentity.cellTypeID
      == ObjectIdentifier(RecordingCell.self)
  )
  #expect(
    prepared.rowsByID[.second]?.renderingIdentity.cellTypeID
      == ObjectIdentifier(AlternateCell.self)
  )
}

@Test
@MainActor
func validatorStoresHeaderAndFooterStateSeparately() throws {
  let recorder = BoundaryRecorder()
  let content = makeSingleSectionContent(
    sectionID: .primary,
    header: RecordingBoundary(
      value: "Header",
      height: 32,
      recorder: recorder,
      viewReuseID: "HeaderReuseID"
    ),
    footer: RecordingBoundary(
      value: "Footer",
      height: 24,
      recorder: recorder,
      viewReuseID: "FooterReuseID"
    ),
    rows: []
  )

  let prepared = try SnapshotValidator<TestSectionID, TestRowID>()
    .prepare(content)
    .get()
  let header = try #require(prepared.headersBySectionID[.primary])
  let footer = try #require(prepared.footersBySectionID[.primary])

  #expect(header.renderingIdentity.viewReuseID == "HeaderReuseID")
  #expect(footer.renderingIdentity.viewReuseID == "FooterReuseID")
  #expect(
    prepared.headerRenderingIdentities[.primary]
      == header.renderingIdentity
  )
  #expect(
    prepared.footerRenderingIdentities[.primary]
      == footer.renderingIdentity
  )
  #expect(
    prepared.headerRenderingIdentities[.primary]
      != prepared.footerRenderingIdentities[.primary]
  )
}

@Test
@MainActor
func validatorRejectsChangedHeaderRenderingIdentity() throws {
  let recorder = BoundaryRecorder()
  let initialContent = makeSingleSectionContent(
    sectionID: .primary,
    header: RecordingBoundary(
      value: "Initial",
      height: 32,
      recorder: recorder,
      viewReuseID: "StableHeader"
    ),
    rows: []
  )
  let initial = try SnapshotValidator<TestSectionID, TestRowID>()
    .prepare(initialContent)
    .get()
  let changedContent = makeSingleSectionContent(
    sectionID: .primary,
    header: AlternateHeader(viewReuseID: "ChangedHeader"),
    rows: []
  )
  let validator = SnapshotValidator<TestSectionID, TestRowID>(
    existingBoundaryViewTypesByReuseID: initial.boundaryViewTypesByReuseID,
    existingHeaderRenderingIdentities: initial.headerRenderingIdentities,
    existingFooterRenderingIdentities: initial.footerRenderingIdentities
  )

  let result = validator.prepare(changedContent)

  guard
    case .failure(
      .changedHeaderRenderingIdentity(
        let sectionID,
        let original,
        let proposed
      )
    ) = result
  else {
    Issue.record("Expected changed header rendering identity to fail")
    return
  }
  #expect(sectionID == .primary)
  #expect(original.viewReuseID == "StableHeader")
  #expect(proposed.viewReuseID == "ChangedHeader")
}

@Test
@MainActor
func validatorRejectsChangedFooterRenderingIdentity() throws {
  let recorder = BoundaryRecorder()
  let initialContent = makeSingleSectionContent(
    sectionID: .primary,
    footer: RecordingBoundary(
      value: "Initial",
      height: 24,
      recorder: recorder,
      viewReuseID: "StableFooter"
    ),
    rows: []
  )
  let initial = try SnapshotValidator<TestSectionID, TestRowID>()
    .prepare(initialContent)
    .get()
  let changedContent = makeSingleSectionContent(
    sectionID: .primary,
    footer: AlternateFooter(viewReuseID: "ChangedFooter"),
    rows: []
  )
  let validator = SnapshotValidator<TestSectionID, TestRowID>(
    existingBoundaryViewTypesByReuseID: initial.boundaryViewTypesByReuseID,
    existingHeaderRenderingIdentities: initial.headerRenderingIdentities,
    existingFooterRenderingIdentities: initial.footerRenderingIdentities
  )

  let result = validator.prepare(changedContent)

  guard
    case .failure(
      .changedFooterRenderingIdentity(
        let sectionID,
        let original,
        let proposed
      )
    ) = result
  else {
    Issue.record("Expected changed footer rendering identity to fail")
    return
  }
  #expect(sectionID == .primary)
  #expect(original.viewReuseID == "StableFooter")
  #expect(proposed.viewReuseID == "ChangedFooter")
}

@Test
@MainActor
func validatorRejectsHeaderAndFooterReuseIDForDifferentViewClasses() {
  let recorder = BoundaryRecorder()
  let content = Content<TestSectionID, TestRowID>(
    sections: [
      Section(
        id: .primary,
        header: RecordingBoundary(
          value: "Header",
          height: 32,
          recorder: recorder,
          viewReuseID: "SharedBoundary"
        ),
        rows: []
      ),
      Section(
        id: .secondary,
        footer: AlternateFooter(viewReuseID: "SharedBoundary"),
        rows: []
      ),
    ]
  )

  let result = SnapshotValidator<TestSectionID, TestRowID>().prepare(content)

  guard
    case .failure(
      .conflictingBoundaryViewType(
        let reuseID,
        let existingViewTypeName,
        let proposedViewTypeName
      )
    ) = result
  else {
    Issue.record("Expected a conflicting header/footer view type to fail")
    return
  }
  #expect(reuseID == "SharedBoundary")
  #expect(
    existingViewTypeName == String(reflecting: RecordingBoundaryView.self)
  )
  #expect(
    proposedViewTypeName == String(reflecting: AlternateBoundaryView.self)
  )
}
