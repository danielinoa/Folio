# Folio

Folio is a lightweight way to build state-driven UIKit table views. Describe what
the table should contain, then update that description as application state changes.

It supports static, conditional, and dynamic content while leaving view design and
layout in UIKit.

Requires iOS 18 or newer, Swift 6.3 or newer, and programmatic UIKit views.

## Installation

Add `https://github.com/danielinoa/Folio.git` through Swift Package Manager, then
link the `Folio` product to your target.

## Usage

```swift
import Folio
import UIKit

enum SectionID: Hashable, Sendable { case main }
enum RowID: Hashable, Sendable { case welcome }

@MainActor
final class MessageCell: UITableViewCell, SizingCell {
  func heightThatFits(width: CGFloat) -> CGFloat { 44 }
}

@MainActor
struct MessageRow: Row {
  let id: RowID
  let title: String
  let cellReuseID = "MessageCell"

  func configure(_ cell: MessageCell) {
    cell.textLabel?.text = title
  }
}

@MainActor
func makeTableView() -> FolioView<SectionID, RowID> {
  let tableView = FolioView<SectionID, RowID>(style: .plain)
  let folio = Folio<SectionID, RowID>(
    sections: [
      Section(
        id: .main,
        rows: [MessageRow(id: .welcome, title: "Welcome to Folio")]
      )
    ]
  )

  tableView.apply(folio, animatingDifferences: false)
  return tableView
}
```

When state changes, build and apply a new `Folio`. Use a nonanimated first apply;
later applies animate by default.

## Rules

- Section IDs must be unique, and row IDs must be globally unique.
- A stable row ID must keep the same cell type and reuse identifier for the
  `FolioView`'s lifetime.
- `configure(_:)` may run repeatedly for display and sizing. It must completely and
  idempotently update the view without application-state side effects.
- `heightThatFits(width:)` must return the complete, finite, nonnegative height.
- `FolioView` owns its `dataSource` and `delegate`; replacing either is unsupported.

## Contributing

Feel free to open an issue if you have questions about using Folio, find a bug, or
want to improve its implementation or API.

## Credits

Folio is primarily the work of [Daniel Inoa](https://github.com/danielinoa).
