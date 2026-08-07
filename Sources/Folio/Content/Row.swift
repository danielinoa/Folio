// Copyright © 2026 Daniel Inoa.

import UIKit

/// A descriptor for one logical row and the concrete cell type that renders it.
///
/// `FolioView` stores heterogeneous rows as `any Row<ID>` and implicitly opens
/// each existential when configuring or measuring its cell, preserving typed
/// access to `CellType`. Its stable `id` drives reconciliation and must retain
/// the same `CellType` and `cellReuseID` across snapshots.
@MainActor
public protocol Row<ID> {
  associatedtype ID: Hashable & Sendable
  associatedtype CellType: UITableViewCell & SizingCell

  /// The logical row identity used to reconcile snapshots.
  var id: ID { get }

  /// The reuse pool for the row's declared cell type.
  var cellReuseID: String { get }

  /// Applies the current presentation and actions to `cell`.
  ///
  /// `FolioView` calls this method before returning a display cell and before
  /// measuring an offscreen sizing cell. A retained row is reconfigured after each
  /// apply, so this method may run repeatedly on the same visible cell. This lets
  /// Folio remeasure changed content without deleting and recreating the row.
  ///
  /// Implementations must completely replace prior presentation state and remain
  /// idempotent. They should not mutate application state or perform lifecycle
  /// side effects such as analytics, navigation, or animations. When configuration
  /// changes manually measured content, invalidate layout from the changed view so
  /// retained nested layouts do not reuse stale frames.
  func configure(_ cell: CellType)

  /// Responds after the row is selected.
  func didSelect()
}

extension Row {
  public func didSelect() {}
}
