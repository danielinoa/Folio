// Copyright © 2026 Daniel Inoa.

import UIKit

/// A validated snapshot with role-specific lookups and cumulative rendering state.
/// It packages rows, headers, and footers before `FolioView` mutates presentation.
/// This keeps each applied content description coherent during reconciliation.
@MainActor
struct PreparedContent<SectionID, RowID>
where
  SectionID: Hashable & Sendable,
  RowID: Hashable & Sendable
{
  typealias Snapshot = NSDiffableDataSourceSnapshot<SectionID, RowID>

  let snapshot: Snapshot
  let sectionIDs: Set<SectionID>
  let rowsByID: [RowID: RowEntry<RowID>]
  let headersBySectionID: [SectionID: SectionBoundaryEntry]
  let footersBySectionID: [SectionID: SectionBoundaryEntry]
  let cellRegistrations: [String: UITableViewCell.Type]
  let rowRenderingIdentities: [RowID: RowRenderingIdentity]
  let boundaryViewTypesByReuseID: [String: UIView.Type]
  let headerRenderingIdentities: [SectionID: SectionBoundaryRenderingIdentity]
  let footerRenderingIdentities: [SectionID: SectionBoundaryRenderingIdentity]
}
