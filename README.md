# Folio

Folio is a lightweight way to build state-driven UIKit table views. Describe what
the table should contain, then update that description as application state changes.

It supports static, conditional, and dynamic content while leaving view design and
layout in UIKit.

Requires iOS 18 or newer, Swift 6.3 or newer, and programmatic UIKit views.

## Installation

Add `https://github.com/danielinoa/Folio.git` through Swift Package Manager. Use
the **Up to Next Minor Version** rule starting at `0.1.0`, then link the `Folio`
product to your target.

## Usage

```swift
import Folio
import UIKit

enum SectionID: Hashable, Sendable { case main }
enum RowID: Hashable, Sendable {
  case notifications
  case details
  case channel(UUID)
}

struct Channel {
  let id: UUID
  let name: String
}

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
func makeContent(
  notificationsEnabled: Bool,
  channels: [Channel]
) -> Content<SectionID, RowID> {
  Content {
    Section(id: .main) {
      MessageRow(
        id: .notifications,
        title: "Notifications: \(notificationsEnabled ? "On" : "Off")"
      )

      if notificationsEnabled {
        MessageRow(id: .details, title: "Choose which channels can notify you")

        for channel in channels {
          MessageRow(id: .channel(channel.id), title: channel.name)
        }
      }
    }
  }
}

let tableView = FolioView<SectionID, RowID>(style: .plain)
var notificationsEnabled = false
let channels = [Channel(id: UUID(), name: "Product updates")]

tableView.apply(
  makeContent(notificationsEnabled: notificationsEnabled, channels: channels),
  animatingDifferences: false
)

notificationsEnabled = true
tableView.apply(
  makeContent(notificationsEnabled: notificationsEnabled, channels: channels),
  rowReconfiguration: .only([.notifications])
)
```

State changes render by rebuilding and applying the complete `Content`. Use a
nonanimated first apply; later applies animate by default.

By default, every retained row is reconfigured. To preserve transient state when
UIKit retains an unchanged visible cell, pass only the retained row IDs whose
configuration changed; newly displayed rows still configure normally. Use `.none`
when only structural differences need to be applied.

Use the direct array initializer when imperative construction is a better fit:

```swift
let content = Content<SectionID, RowID>(
  sections: [
    Section(
      id: .main,
      rows: [MessageRow(id: .notifications, title: "Notifications")]
    )
  ]
)
```

## Rules

- Section IDs must be unique, and row IDs must be globally unique.
- A stable row ID must keep the same cell type and reuse identifier for the
  `FolioView`'s lifetime.
- When using `.only(...)`, include every retained row whose presentation, measured
  height, or cell-installed actions changed.
- `configure(_:)` may run repeatedly for display and sizing. It must completely and
  idempotently update the view without application-state side effects.
- `heightThatFits(width:)` must return the complete, finite, nonnegative height.
- `FolioView` owns its `dataSource` and `delegate`; replacing either is unsupported.

## Contributing

Feel free to open an issue if you have questions about using Folio, find a bug, or
want to improve its implementation or API.

## Credits

Folio is primarily the work of [Daniel Inoa](https://github.com/danielinoa).

## License

Folio is available under the [MIT License](LICENSE).
