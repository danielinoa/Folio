// Copyright © 2026 Daniel Inoa.

/// An identified group of rows with optional typed header and footer descriptors.
/// `FolioView` resolves each role separately by section ID and updates it in place.
/// This lets section presentation change without reloading retained row cells.
@MainActor
public struct Section<SectionID, RowID>
where
  SectionID: Hashable & Sendable,
  RowID: Hashable & Sendable
{
  public let id: SectionID
  public let header: (any SectionHeader)?
  public let footer: (any SectionFooter)?
  public let rows: [any Row<RowID>]

  public init(
    id: SectionID,
    header: (any SectionHeader)? = nil,
    footer: (any SectionFooter)? = nil,
    rows: [any Row<RowID>]
  ) {
    self.id = id
    self.header = header
    self.footer = footer
    self.rows = rows
  }

  /// Creates a section from rows declared in source order.
  /// `RowBuilder` flattens conditional and collection-generated rows before storage.
  /// This makes mixed content concise while preserving row identity and rendering.
  public init(
    id: SectionID,
    header: (any SectionHeader)? = nil,
    footer: (any SectionFooter)? = nil,
    @RowBuilder<RowID> rows: @MainActor () -> [any Row<RowID>]
  ) {
    self.init(
      id: id,
      header: header,
      footer: footer,
      rows: rows()
    )
  }
}
