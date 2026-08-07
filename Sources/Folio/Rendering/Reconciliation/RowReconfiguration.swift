// Copyright © 2026 Daniel Inoa.

/// Controls which retained rows Folio explicitly reconfigures during an apply.
/// Folio evaluates the policy after identifying rows shared by both snapshots.
/// This can preserve transient state when UIKit retains an unchanged visible cell.
public enum RowReconfiguration<RowID>: Sendable
where RowID: Hashable & Sendable {
  /// Reconfigures every retained row, preserving Folio's safe default behavior.
  case all

  /// Reconfigures only retained rows whose IDs are in the provided set.
  /// Include every row whose configuration, measured height, or cell-installed
  /// actions changed.
  case only(Set<RowID>)

  /// Applies structural differences without explicitly reconfiguring retained rows.
  /// Use this only when no retained row's configuration changed.
  case none

  /// Returns whether Folio should reconfigure the retained row with `rowID`.
  func reconfigures(_ rowID: RowID) -> Bool {
    switch self {
    case .all:
      true
    case .only(let rowIDs):
      rowIDs.contains(rowID)
    case .none:
      false
    }
  }
}
