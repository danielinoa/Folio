/// The view type and reuse identifier assigned to a section header or footer.
/// Folio retains it in a role-specific history keyed by the logical section ID.
/// This prevents retained views from silently changing their reusable contract.
struct SectionBoundaryRenderingIdentity: Equatable, Sendable {
  let viewTypeID: ObjectIdentifier
  let viewTypeName: String
  let viewReuseID: String
}
