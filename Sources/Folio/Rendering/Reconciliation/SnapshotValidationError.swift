/// An identity or reuse invariant violation found while preparing render state.
/// It captures the conflicting values so invalid content can be rejected before
/// `FolioView` is mutated.
enum SnapshotValidationError<SectionID, RowID>: Error
where
  SectionID: Hashable & Sendable,
  RowID: Hashable & Sendable
{
  case duplicateSectionID(SectionID)
  case duplicateRowID(RowID)
  case changedRowRenderingIdentity(
    rowID: RowID,
    original: RowRenderingIdentity,
    proposed: RowRenderingIdentity
  )
  case changedHeaderRenderingIdentity(
    sectionID: SectionID,
    original: SectionBoundaryRenderingIdentity,
    proposed: SectionBoundaryRenderingIdentity
  )
  case changedFooterRenderingIdentity(
    sectionID: SectionID,
    original: SectionBoundaryRenderingIdentity,
    proposed: SectionBoundaryRenderingIdentity
  )
  case conflictingCellRegistration(
    reuseID: String,
    registeredCellTypeName: String,
    proposedCellTypeName: String
  )
  case conflictingBoundaryViewType(
    reuseID: String,
    existingViewTypeName: String,
    proposedViewTypeName: String
  )

  var preconditionMessage: String {
    switch self {
    case .duplicateSectionID(let sectionID):
      "Duplicate section identity \(String(reflecting: sectionID))."

    case .duplicateRowID(let rowID):
      "Duplicate row identity \(String(reflecting: rowID)). "
        + "Row identities must be globally unique in an applied snapshot."

    case .changedRowRenderingIdentity(let rowID, let original, let proposed):
      "Row identity \(String(reflecting: rowID)) changed its rendering identity from "
        + "\(original.cellTypeName) / '\(original.cellReuseID)' to "
        + "\(proposed.cellTypeName) / '\(proposed.cellReuseID)'."

    case .changedHeaderRenderingIdentity(
      let sectionID,
      let original,
      let proposed
    ):
      "Section identity \(String(reflecting: sectionID)) changed its header "
        + "rendering identity from "
        + "\(original.viewTypeName) / '\(original.viewReuseID)' to "
        + "\(proposed.viewTypeName) / '\(proposed.viewReuseID)'."

    case .changedFooterRenderingIdentity(
      let sectionID,
      let original,
      let proposed
    ):
      "Section identity \(String(reflecting: sectionID)) changed its footer "
        + "rendering identity from "
        + "\(original.viewTypeName) / '\(original.viewReuseID)' to "
        + "\(proposed.viewTypeName) / '\(proposed.viewReuseID)'."

    case .conflictingCellRegistration(
      let reuseID,
      let registeredCellTypeName,
      let proposedCellTypeName
    ):
      "Reuse identifier '\(reuseID)' is already registered to "
        + "\(registeredCellTypeName), not \(proposedCellTypeName)."

    case .conflictingBoundaryViewType(
      let reuseID,
      let existingViewTypeName,
      let proposedViewTypeName
    ):
      "Header/footer reuse identifier '\(reuseID)' already maps to "
        + "\(existingViewTypeName), not \(proposedViewTypeName)."
    }
  }
}
