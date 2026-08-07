// Copyright © 2026 Daniel Inoa.

/// The cell type and reuse identifier assigned to a row identity, retained across
/// snapshots so validation can prevent the row's rendering meaning from changing.
struct RowRenderingIdentity: Equatable, Sendable {
  let cellTypeID: ObjectIdentifier
  let cellTypeName: String
  let cellReuseID: String
}
