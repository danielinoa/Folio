import Testing
import UIKit

@testable import Folio

extension FolioViewTests {
  @Test
  @MainActor
  func builderSnapshotsReconcileStateDrivenRowsSectionsAndBoundaries() async throws {
    let rowRecorder = SizingRecorder()
    let boundaryRecorder = BoundaryRecorder()
    let host = FolioViewHost(
      style: .plain,
      size: CGSize(width: 320, height: 800)
    )
    let folioView = host.folioView
    defer { host.tearDown() }
    var initialSelectionCount = 0
    var updatedSelectionCount = 0

    let initialContent = makeBuilderContent(
      state: BuilderRenderState(
        revision: "Off",
        masterScale: 0.1,
        showsDetail: false,
        generatedValues: [1, 2],
        showsSecondarySection: false
      ),
      rowRecorder: rowRecorder,
      boundaryRecorder: boundaryRecorder,
      onMasterSelection: { initialSelectionCount += 1 }
    )
    await apply(initialContent, to: folioView, animated: false)
    folioView.layoutIfNeeded()

    #expect(folioView.numberOfSections == 1)
    #expect(folioView.numberOfRows(inSection: 0) == 3)
    let initialMasterCell = try #require(
      folioView.cellForRow(at: IndexPath(row: 0, section: 0)) as? RecordingCell
    )
    #expect(initialMasterCell.value == "Off master")
    #expect(folioView.rectForRow(at: IndexPath(row: 0, section: 0)).height == 32)
    #expect(
      (folioView.cellForRow(at: IndexPath(row: 1, section: 0)) as? RecordingCell)?.value
        == "Off generated 1"
    )
    #expect(
      (folioView.cellForRow(at: IndexPath(row: 2, section: 0)) as? RecordingCell)?.value
        == "Off generated 2"
    )
    #expect(recordingHeader(in: folioView, section: 0)?.value == "Off header")
    #expect(recordingFooter(in: folioView, section: 0)?.value == "Off footer")

    let updatedContent = makeBuilderContent(
      state: BuilderRenderState(
        revision: "On",
        masterScale: 0.4,
        showsDetail: true,
        generatedValues: [2, 3],
        showsSecondarySection: true
      ),
      rowRecorder: rowRecorder,
      boundaryRecorder: boundaryRecorder,
      onMasterSelection: { updatedSelectionCount += 1 }
    )
    let prepared = try SnapshotValidator<TestSectionID, TestRowID>()
      .prepare(updatedContent)
      .get()
    #expect(prepared.snapshot.sectionIdentifiers == [.primary, .secondary])
    #expect(
      prepared.snapshot.itemIdentifiers(inSection: .primary) == [
        .first,
        .second,
        .generated(2),
        .generated(3),
      ])

    await apply(updatedContent, to: folioView, animated: true)
    folioView.layoutIfNeeded()

    #expect(folioView.numberOfSections == 2)
    #expect(folioView.numberOfRows(inSection: 0) == 4)
    #expect(folioView.numberOfRows(inSection: 1) == 0)
    let updatedMasterCell = try #require(
      folioView.cellForRow(at: IndexPath(row: 0, section: 0)) as? RecordingCell
    )
    #expect(updatedMasterCell === initialMasterCell)
    #expect(updatedMasterCell.value == "On master")
    #expect(folioView.rectForRow(at: IndexPath(row: 0, section: 0)).height == 128)
    let detailCell = try #require(
      folioView.cellForRow(at: IndexPath(row: 1, section: 0)) as? AlternateCell
    )
    let updatedGeneratedTwoCell = try #require(
      folioView.cellForRow(at: IndexPath(row: 2, section: 0)) as? RecordingCell
    )
    let updatedGeneratedThreeCell = try #require(
      folioView.cellForRow(at: IndexPath(row: 3, section: 0)) as? RecordingCell
    )
    #expect(detailCell.value == "On detail")
    #expect(updatedGeneratedTwoCell.value == "On generated 2")
    #expect(updatedGeneratedThreeCell.value == "On generated 3")
    #expect(recordingHeader(in: folioView, section: 0)?.value == "On header")
    #expect(recordingFooter(in: folioView, section: 0)?.value == "On footer")
    #expect(recordingHeader(in: folioView, section: 1)?.value == "On secondary header")
    #expect(recordingFooter(in: folioView, section: 1)?.value == "On secondary footer")

    folioView.tableView(
      folioView,
      didSelectRowAt: IndexPath(row: 0, section: 0)
    )
    #expect(initialSelectionCount == 0)
    #expect(updatedSelectionCount == 1)

    let finalContent = makeBuilderContent(
      state: BuilderRenderState(
        revision: "Final",
        masterScale: 0.2,
        showsDetail: false,
        generatedValues: [3, 2],
        showsSecondarySection: false
      ),
      rowRecorder: rowRecorder,
      boundaryRecorder: boundaryRecorder
    )
    await apply(finalContent, to: folioView, animated: true)
    folioView.layoutIfNeeded()

    #expect(folioView.numberOfSections == 1)
    #expect(folioView.numberOfRows(inSection: 0) == 3)
    let finalMasterCell = try #require(
      folioView.cellForRow(at: IndexPath(row: 0, section: 0)) as? RecordingCell
    )
    #expect(finalMasterCell === initialMasterCell)
    #expect(finalMasterCell.value == "Final master")
    #expect(folioView.rectForRow(at: IndexPath(row: 0, section: 0)).height == 64)
    let finalGeneratedThreeCell = try #require(
      folioView.cellForRow(at: IndexPath(row: 1, section: 0)) as? RecordingCell
    )
    let finalGeneratedTwoCell = try #require(
      folioView.cellForRow(at: IndexPath(row: 2, section: 0)) as? RecordingCell
    )
    #expect(finalGeneratedThreeCell === updatedGeneratedThreeCell)
    #expect(finalGeneratedThreeCell.value == "Final generated 3")
    #expect(finalGeneratedTwoCell.value == "Final generated 2")
    #expect(recordingHeader(in: folioView, section: 0)?.value == "Final header")
    #expect(recordingFooter(in: folioView, section: 0)?.value == "Final footer")
  }

  @Test
  @MainActor
  func builderSnapshotsPreserveDuplicateIdentityValidation() {
    let recorder = SizingRecorder()
    let duplicateSections = Folio<TestSectionID, TestRowID> {
      Section(id: .primary, rows: [])
      Section(id: .primary, rows: [])
    }

    let sectionResult = SnapshotValidator<TestSectionID, TestRowID>()
      .prepare(duplicateSections)
    guard case .failure(.duplicateSectionID(let sectionID)) = sectionResult else {
      Issue.record("Expected duplicate builder section identity validation to fail")
      return
    }
    #expect(sectionID == .primary)

    let duplicateRows = Folio<TestSectionID, TestRowID> {
      Section(id: .primary) {
        RecordingRow(id: .first, scale: 0.1, value: "First", recorder: recorder)
      }
      Section(id: .secondary) {
        AlternateRow(id: .first)
      }
    }

    let rowResult = SnapshotValidator<TestSectionID, TestRowID>()
      .prepare(duplicateRows)
    guard case .failure(.duplicateRowID(let rowID)) = rowResult else {
      Issue.record("Expected duplicate builder row identity validation to fail")
      return
    }
    #expect(rowID == .first)
  }

  @Test
  @MainActor
  func builderSnapshotsPreserveRenderingIdentityValidation() throws {
    let recorder = SizingRecorder()
    let initialContent = Folio<TestSectionID, TestRowID> {
      Section(id: .primary) {
        RecordingRow(
          id: .first,
          scale: 0.1,
          value: "Initial",
          recorder: recorder,
          cellReuseID: "BuilderRecordingCell"
        )
      }
    }
    let initial = try SnapshotValidator<TestSectionID, TestRowID>()
      .prepare(initialContent)
      .get()
    let changedContent = Folio<TestSectionID, TestRowID> {
      Section(id: .primary) {
        AlternateRow(
          id: .first,
          cellReuseID: "BuilderAlternateCell"
        )
      }
    }
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
      Issue.record("Expected builder row rendering identity validation to fail")
      return
    }
    #expect(rowID == .first)
    #expect(original.cellReuseID == "BuilderRecordingCell")
    #expect(proposed.cellReuseID == "BuilderAlternateCell")
    #expect(original.cellTypeID == ObjectIdentifier(RecordingCell.self))
    #expect(proposed.cellTypeID == ObjectIdentifier(AlternateCell.self))
  }
}

private struct BuilderRenderState {
  let revision: String
  let masterScale: CGFloat
  let showsDetail: Bool
  let generatedValues: [Int]
  let showsSecondarySection: Bool
}

@MainActor
private func makeBuilderContent(
  state: BuilderRenderState,
  rowRecorder: SizingRecorder,
  boundaryRecorder: BoundaryRecorder,
  onMasterSelection: @escaping () -> Void = {}
) -> Folio<TestSectionID, TestRowID> {
  Folio {
    Section(
      id: .primary,
      header: RecordingBoundary(
        value: "\(state.revision) header",
        height: 32,
        recorder: boundaryRecorder,
        viewReuseID: "BuilderPrimaryHeader"
      ),
      footer: RecordingBoundary(
        value: "\(state.revision) footer",
        height: 24,
        recorder: boundaryRecorder,
        viewReuseID: "BuilderPrimaryFooter"
      )
    ) {
      RecordingRow(
        id: .first,
        scale: state.masterScale,
        value: "\(state.revision) master",
        recorder: rowRecorder,
        onSelect: onMasterSelection
      )

      if state.showsDetail {
        AlternateRow(id: .second, value: "\(state.revision) detail")
      }

      for value in state.generatedValues {
        RecordingRow(
          id: .generated(value),
          scale: 0.1,
          value: "\(state.revision) generated \(value)",
          recorder: rowRecorder
        )
      }
    }

    if state.showsSecondarySection {
      Section<TestSectionID, TestRowID>(
        id: .secondary,
        header: RecordingBoundary(
          value: "\(state.revision) secondary header",
          height: 28,
          recorder: boundaryRecorder,
          viewReuseID: "BuilderSecondaryHeader"
        ),
        footer: RecordingBoundary(
          value: "\(state.revision) secondary footer",
          height: 18,
          recorder: boundaryRecorder,
          viewReuseID: "BuilderSecondaryFooter"
        )
      ) {}
    }
  }
}
