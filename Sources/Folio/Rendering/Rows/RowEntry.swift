// Copyright © 2026 Daniel Inoa.

import UIKit

/// A type-erased row paired with metadata for cell registration and identity validation.
/// It lets `FolioView` store heterogeneous rows together, then reopen each one for
/// typed configuration and measurement.
@MainActor
struct RowEntry<RowID> where RowID: Hashable & Sendable {
  let row: any Row<RowID>
  let renderingIdentity: RowRenderingIdentity
  let cellType: UITableViewCell.Type
}
