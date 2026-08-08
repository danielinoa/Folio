// Copyright © 2026 Daniel Inoa.

import UIKit

/// Converts `Content` into validated row, header, and footer render state.
/// It builds each role in temporary maps while checking identity and reuse invariants.
/// This rejects invalid content before any partial view mutation can occur.
@MainActor
struct SnapshotValidator<SectionID, RowID>
where
  SectionID: Hashable & Sendable,
  RowID: Hashable & Sendable
{
  typealias Snapshot = NSDiffableDataSourceSnapshot<SectionID, RowID>

  private let existingCellRegistrations: [String: UITableViewCell.Type]
  private let existingRowRenderingIdentities: [RowID: RowRenderingIdentity]
  private let existingBoundaryViewTypesByReuseID: [String: UIView.Type]
  private let existingHeaderRenderingIdentities: [SectionID: SectionBoundaryRenderingIdentity]
  private let existingFooterRenderingIdentities: [SectionID: SectionBoundaryRenderingIdentity]

  init(
    existingCellRegistrations: [String: UITableViewCell.Type] = [:],
    existingRowRenderingIdentities: [RowID: RowRenderingIdentity] = [:],
    existingBoundaryViewTypesByReuseID: [String: UIView.Type] = [:],
    existingHeaderRenderingIdentities: [SectionID: SectionBoundaryRenderingIdentity] = [:],
    existingFooterRenderingIdentities: [SectionID: SectionBoundaryRenderingIdentity] = [:]
  ) {
    self.existingCellRegistrations = existingCellRegistrations
    self.existingRowRenderingIdentities = existingRowRenderingIdentities
    self.existingBoundaryViewTypesByReuseID = existingBoundaryViewTypesByReuseID
    self.existingHeaderRenderingIdentities = existingHeaderRenderingIdentities
    self.existingFooterRenderingIdentities = existingFooterRenderingIdentities
  }

  func prepare(
    _ content: Content<SectionID, RowID>
  ) -> Result<
    PreparedContent<SectionID, RowID>,
    SnapshotValidationError<SectionID, RowID>
  > {
    var snapshot = Snapshot()
    var sectionIDs: Set<SectionID> = []
    var rowsByID: [RowID: RowEntry<RowID>] = [:]
    var headersBySectionID: [SectionID: SectionBoundaryEntry] = [:]
    var footersBySectionID: [SectionID: SectionBoundaryEntry] = [:]
    var proposedCellRegistrations = existingCellRegistrations
    var proposedRowRenderingIdentities = existingRowRenderingIdentities
    var proposedBoundaryViewTypesByReuseID = existingBoundaryViewTypesByReuseID
    var proposedHeaderRenderingIdentities = existingHeaderRenderingIdentities
    var proposedFooterRenderingIdentities = existingFooterRenderingIdentities

    for section in content.sections {
      guard sectionIDs.insert(section.id).inserted else {
        return .failure(.duplicateSectionID(section.id))
      }

      snapshot.appendSections([section.id])

      if let header = section.header {
        let entry = makeSectionBoundaryEntry(for: header)
        if let error = validateHeader(
          entry,
          for: section.id,
          viewTypesByReuseID: &proposedBoundaryViewTypesByReuseID,
          renderingIdentities: &proposedHeaderRenderingIdentities
        ) {
          return .failure(error)
        }
        headersBySectionID[section.id] = entry
      }

      if let footer = section.footer {
        let entry = makeSectionBoundaryEntry(for: footer)
        if let error = validateFooter(
          entry,
          for: section.id,
          viewTypesByReuseID: &proposedBoundaryViewTypesByReuseID,
          renderingIdentities: &proposedFooterRenderingIdentities
        ) {
          return .failure(error)
        }
        footersBySectionID[section.id] = entry
      }

      var sectionRowIDs: [RowID] = []
      for row in section.rows {
        let entry = makeRowEntry(for: row)

        guard rowsByID[row.id] == nil else {
          return .failure(.duplicateRowID(row.id))
        }

        if let original = proposedRowRenderingIdentities[row.id] {
          guard original == entry.renderingIdentity else {
            return .failure(
              .changedRowRenderingIdentity(
                rowID: row.id,
                original: original,
                proposed: entry.renderingIdentity
              )
            )
          }
        } else {
          proposedRowRenderingIdentities[row.id] = entry.renderingIdentity
        }

        let reuseID = entry.renderingIdentity.cellReuseID
        if let registeredType = proposedCellRegistrations[reuseID] {
          guard ObjectIdentifier(registeredType) == entry.renderingIdentity.cellTypeID else {
            return .failure(
              .conflictingCellRegistration(
                reuseID: reuseID,
                registeredCellTypeName: String(reflecting: registeredType),
                proposedCellTypeName: entry.renderingIdentity.cellTypeName
              )
            )
          }
        } else {
          proposedCellRegistrations[reuseID] = entry.cellType
        }

        rowsByID[row.id] = entry
        sectionRowIDs.append(row.id)
      }

      snapshot.appendItems(sectionRowIDs, toSection: section.id)
    }

    return .success(
      PreparedContent(
        snapshot: snapshot,
        sectionIDs: sectionIDs,
        rowsByID: rowsByID,
        headersBySectionID: headersBySectionID,
        footersBySectionID: footersBySectionID,
        cellRegistrations: proposedCellRegistrations,
        rowRenderingIdentities: proposedRowRenderingIdentities,
        boundaryViewTypesByReuseID: proposedBoundaryViewTypesByReuseID,
        headerRenderingIdentities: proposedHeaderRenderingIdentities,
        footerRenderingIdentities: proposedFooterRenderingIdentities
      )
    )
  }

  /// Opening the row existential makes its associated cell type available while
  /// Folio records and later enforces the row's rendering identity.
  private func makeRowEntry<R: Row>(for row: R) -> RowEntry<RowID>
  where R.ID == RowID {
    RowEntry(
      row: row,
      renderingIdentity: RowRenderingIdentity(
        cellTypeID: ObjectIdentifier(R.CellType.self),
        cellTypeName: String(reflecting: R.CellType.self),
        cellReuseID: row.cellReuseID
      ),
      cellType: R.CellType.self
    )
  }

  /// Opening a header or footer existential exposes its reusable view type for
  /// reuse mapping, typed configuration, and stable rendering validation.
  private func makeSectionBoundaryEntry<S: SectionBoundary>(
    for boundary: S
  ) -> SectionBoundaryEntry {
    SectionBoundaryEntry(
      boundary: boundary,
      renderingIdentity: SectionBoundaryRenderingIdentity(
        viewTypeID: ObjectIdentifier(S.ViewType.self),
        viewTypeName: String(reflecting: S.ViewType.self),
        viewReuseID: boundary.viewReuseID
      ),
      viewType: S.ViewType.self
    )
  }

  private func validateHeader(
    _ entry: SectionBoundaryEntry,
    for sectionID: SectionID,
    viewTypesByReuseID: inout [String: UIView.Type],
    renderingIdentities: inout [SectionID: SectionBoundaryRenderingIdentity]
  ) -> SnapshotValidationError<SectionID, RowID>? {
    if let original = renderingIdentities[sectionID] {
      guard original == entry.renderingIdentity else {
        return .changedHeaderRenderingIdentity(
          sectionID: sectionID,
          original: original,
          proposed: entry.renderingIdentity
        )
      }
    } else {
      renderingIdentities[sectionID] = entry.renderingIdentity
    }

    return validateBoundaryViewType(entry, viewTypesByReuseID: &viewTypesByReuseID)
  }

  private func validateFooter(
    _ entry: SectionBoundaryEntry,
    for sectionID: SectionID,
    viewTypesByReuseID: inout [String: UIView.Type],
    renderingIdentities: inout [SectionID: SectionBoundaryRenderingIdentity]
  ) -> SnapshotValidationError<SectionID, RowID>? {
    if let original = renderingIdentities[sectionID] {
      guard original == entry.renderingIdentity else {
        return .changedFooterRenderingIdentity(
          sectionID: sectionID,
          original: original,
          proposed: entry.renderingIdentity
        )
      }
    } else {
      renderingIdentities[sectionID] = entry.renderingIdentity
    }

    return validateBoundaryViewType(entry, viewTypesByReuseID: &viewTypesByReuseID)
  }

  private func validateBoundaryViewType(
    _ entry: SectionBoundaryEntry,
    viewTypesByReuseID: inout [String: UIView.Type]
  ) -> SnapshotValidationError<SectionID, RowID>? {
    let reuseID = entry.renderingIdentity.viewReuseID
    if let existingViewType = viewTypesByReuseID[reuseID] {
      guard ObjectIdentifier(existingViewType) == entry.renderingIdentity.viewTypeID else {
        return .conflictingBoundaryViewType(
          reuseID: reuseID,
          existingViewTypeName: String(reflecting: existingViewType),
          proposedViewTypeName: entry.renderingIdentity.viewTypeName
        )
      }
    } else {
      viewTypesByReuseID[reuseID] = entry.viewType
    }

    return nil
  }
}
