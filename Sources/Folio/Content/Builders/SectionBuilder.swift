// Copyright © 2026 Daniel Inoa.

/// Collects sections from a declarative `Folio` closure.
/// It flattens ordinary Swift control flow into one ordered section array.
/// This keeps snapshot construction concise without changing identity or rendering.
@resultBuilder
public enum SectionBuilder<SectionID, RowID>
where
  SectionID: Hashable & Sendable,
  RowID: Hashable & Sendable
{
  public static func buildExpression(
    _ section: Section<SectionID, RowID>
  ) -> [Section<SectionID, RowID>] {
    [section]
  }

  public static func buildExpression(
    _ sections: [Section<SectionID, RowID>]
  ) -> [Section<SectionID, RowID>] {
    sections
  }

  public static func buildBlock(
    _ components: [Section<SectionID, RowID>]...
  ) -> [Section<SectionID, RowID>] {
    components.flatMap { $0 }
  }

  public static func buildOptional(
    _ component: [Section<SectionID, RowID>]?
  ) -> [Section<SectionID, RowID>] {
    component ?? []
  }

  public static func buildEither(
    first component: [Section<SectionID, RowID>]
  ) -> [Section<SectionID, RowID>] {
    component
  }

  public static func buildEither(
    second component: [Section<SectionID, RowID>]
  ) -> [Section<SectionID, RowID>] {
    component
  }

  public static func buildArray(
    _ components: [[Section<SectionID, RowID>]]
  ) -> [Section<SectionID, RowID>] {
    components.flatMap { $0 }
  }

  public static func buildLimitedAvailability(
    _ component: [Section<SectionID, RowID>]
  ) -> [Section<SectionID, RowID>] {
    component
  }
}
