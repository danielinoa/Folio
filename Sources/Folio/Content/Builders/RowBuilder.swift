/// Collects row descriptors from a declarative `Section` closure.
/// It flattens ordinary Swift control flow into one ordered heterogeneous row array.
/// This keeps snapshot construction concise without changing identity or rendering.
@resultBuilder
public enum RowBuilder<RowID>
where RowID: Hashable & Sendable {
  public static func buildExpression<R: Row>(
    _ row: R
  ) -> [any Row<RowID>] where R.ID == RowID {
    [row]
  }

  public static func buildExpression<R: Row>(
    _ rows: [R]
  ) -> [any Row<RowID>] where R.ID == RowID {
    rows
  }

  public static func buildExpression(
    _ rows: [any Row<RowID>]
  ) -> [any Row<RowID>] {
    rows
  }

  public static func buildBlock(
    _ components: [any Row<RowID>]...
  ) -> [any Row<RowID>] {
    components.flatMap { $0 }
  }

  public static func buildOptional(
    _ component: [any Row<RowID>]?
  ) -> [any Row<RowID>] {
    component ?? []
  }

  public static func buildEither(
    first component: [any Row<RowID>]
  ) -> [any Row<RowID>] {
    component
  }

  public static func buildEither(
    second component: [any Row<RowID>]
  ) -> [any Row<RowID>] {
    component
  }

  public static func buildArray(
    _ components: [[any Row<RowID>]]
  ) -> [any Row<RowID>] {
    components.flatMap { $0 }
  }

  public static func buildLimitedAvailability(
    _ component: [any Row<RowID>]
  ) -> [any Row<RowID>] {
    component
  }
}
