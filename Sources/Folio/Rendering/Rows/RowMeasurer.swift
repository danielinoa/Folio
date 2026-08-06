import UIKit

/// Measures configured row prototypes without relying on visible cells.
/// It retains one typed sizing cell per reuse identifier until a render-boundary reset.
/// This isolates manual measurement state from `FolioView` while preserving row typing.
@MainActor
struct RowMeasurer {
  private var prototypesByReuseID: [String: UITableViewCell] = [:]

  mutating func reset() {
    prototypesByReuseID.removeAll()
  }

  mutating func height<R: Row>(for row: R, width: CGFloat) -> CGFloat {
    let cell: R.CellType

    if let cachedCell = prototypesByReuseID[row.cellReuseID] {
      guard let typedCell = cachedCell as? R.CellType else {
        preconditionFailure(
          "Sizing cell for reuse identifier '\(row.cellReuseID)' is "
            + "\(String(reflecting: type(of: cachedCell))), but the row requires "
            + "\(String(reflecting: R.CellType.self))."
        )
      }
      cell = typedCell
    } else {
      cell = R.CellType(style: .default, reuseIdentifier: row.cellReuseID)
      prototypesByReuseID[row.cellReuseID] = cell
    }

    precondition(
      width.isFinite && width >= .zero,
      "Cannot measure a row using invalid table width \(width)."
    )

    // Measurement must reflect this row's current content, not stale prototype state.
    row.configure(cell)
    let height = cell.heightThatFits(width: width)
    precondition(
      height.isFinite && height >= .zero,
      "\(String(reflecting: R.CellType.self)) returned invalid row height \(height) "
        + "for width \(width)."
    )

    // Whole-point rounding keeps Folio's policy simple while ensuring measured
    // content is never undersized on displays with finer pixel boundaries.
    return ceil(height)
  }
}
