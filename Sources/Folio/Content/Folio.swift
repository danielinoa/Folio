/// A complete description of the table's desired sections and rows at one moment.
/// Rebuild it after state changes so `FolioView` can reconcile successive values
/// by stable identities; section IDs must be unique and row IDs globally unique.
@MainActor
public struct Folio<SectionID, RowID>
where
  SectionID: Hashable & Sendable,
  RowID: Hashable & Sendable
{
  public let sections: [Section<SectionID, RowID>]

  public init(sections: [Section<SectionID, RowID>] = []) {
    self.sections = sections
  }
}
