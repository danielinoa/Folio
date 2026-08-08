// Copyright © 2026 Daniel Inoa.

/// A complete description of the table's desired sections and rows at one moment.
/// Rebuild it after state changes so `FolioView` can reconcile successive values
/// by stable identities; section IDs must be unique and row IDs globally unique.
@MainActor
public struct Content<SectionID, RowID>
where
  SectionID: Hashable & Sendable,
  RowID: Hashable & Sendable
{
  public let sections: [Section<SectionID, RowID>]

  public init(sections: [Section<SectionID, RowID>] = []) {
    self.sections = sections
  }

  /// Creates a snapshot from sections declared in source order.
  /// `SectionBuilder` flattens conditional and collection-generated sections.
  /// This keeps dynamic table structure concise while preserving reconciliation.
  public init(
    @SectionBuilder<SectionID, RowID> sections: @MainActor () -> [Section<SectionID, RowID>]
  ) {
    self.init(sections: sections())
  }
}
