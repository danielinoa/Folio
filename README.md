# Folio

Folio is a lightweight way to build state-driven UIKit table views. Describe what
the table should contain, then update that description as application state changes.

It supports static, conditional, and dynamic content. Folio handles identity-based
diffing, reuse, typed configuration, selection, and width-aware measurement while
the application retains ownership of state and UIKit view design.

Requires iOS 18 or newer, Swift 6.3 or newer, and programmatic UIKit views.

## Contents

- [Installation](#installation)
- [Why Folio](#why-folio)
  - [Conventional UITableView](#conventional-uitableview)
  - [With Folio](#with-folio)
- [Sample Usage](#sample-usage)
- [Building Content](#building-content)
- [Applying State Changes](#applying-state-changes)
  - [Retained Row Reconfiguration](#retained-row-reconfiguration)
- [Rows and Cells](#rows-and-cells)
  - [Manual Sizing](#manual-sizing)
- [Headers and Footers](#headers-and-footers)
- [Identity and Lifecycle Rules](#identity-and-lifecycle-rules)
- [Contributing](#contributing)
- [Credits](#credits)
- [License](#license)

## Installation

Add `https://github.com/danielinoa/Folio.git` through Swift Package Manager. Use
the **Up to Next Minor Version** rule starting at `0.1.0`, then link the `Folio`
product to your target.

From another Swift package, add the dependency and product in `Package.swift`:

```swift
let package = Package(
  name: "YourPackage",
  platforms: [
    .iOS(.v18)
  ],
  dependencies: [
    .package(
      url: "https://github.com/danielinoa/Folio.git",
      .upToNextMinor(from: "0.1.0")
    )
  ],
  targets: [
    .target(
      name: "YourTarget",
      dependencies: [
        .product(name: "Folio", package: "Folio")
      ]
    )
  ]
)
```

## Why Folio

A conventional `UITableView` data source often spreads one screen's definition
across section and row counts, index-path conditions, cell creation, selection,
height calculation, and update calls. Heterogeneous tables can require repeating
the same `switch` or `if` structure in several delegate methods and casting dequeued
cells back to their expected types.

### Conventional UITableView

One way to keep a conventional implementation organized is to assemble an enum of
visible rows. Every data-source or delegate callback that needs row meaning must
then translate its `IndexPath` through that model. This example uses the
`NotificationsCell` and `MessageCell` classes defined in
[Sample Usage](#sample-usage):

```swift
private enum TableRow {
  case notifications
  case details
  case channel(Channel)
}

private var rows: [TableRow] {
  var rows: [TableRow] = [.notifications]

  if notificationsEnabled {
    rows.append(.details)
    rows.append(contentsOf: channels.map(TableRow.channel))
  }

  return rows
}

override func viewDidLoad() {
  super.viewDidLoad()

  tableView.register(
    NotificationsCell.self,
    forCellReuseIdentifier: "NotificationsCell"
  )
  tableView.register(
    MessageCell.self,
    forCellReuseIdentifier: "MessageCell"
  )
}

private let messageSizingCell = MessageCell(style: .default, reuseIdentifier: nil)

private func messageHeight(for text: String, width: CGFloat) -> CGFloat {
  messageSizingCell.apply(text: text)
  return messageSizingCell.heightThatFits(width: width)
}

func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
  rows.count
}

func tableView(
  _ tableView: UITableView,
  cellForRowAt indexPath: IndexPath
) -> UITableViewCell {
  // ⚠️ Translate IndexPath into row meaning for configuration.
  switch rows[indexPath.row] {
  case .notifications:
    let cell =
      tableView.dequeueReusableCell(
        withIdentifier: "NotificationsCell",
        for: indexPath
      ) as! NotificationsCell
    cell.apply(isOn: notificationsEnabled)
    return cell

  case .details:
    let cell =
      tableView.dequeueReusableCell(
        withIdentifier: "MessageCell",
        for: indexPath
      ) as! MessageCell
    cell.apply(text: "Choose which channels can notify you")
    return cell

  case .channel(let channel):
    let cell =
      tableView.dequeueReusableCell(
        withIdentifier: "MessageCell",
        for: indexPath
      ) as! MessageCell
    cell.apply(text: channel.name)
    return cell
  }
}

func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
  // ⚠️ Repeat the same IndexPath-to-row lookup for selection.
  switch rows[indexPath.row] {
  case .notifications:
    notificationsEnabled.toggle()
    tableView.reloadData()

  case .details:
    break

  case .channel:
    break
  }
}

func tableView(
  _ tableView: UITableView,
  heightForRowAt indexPath: IndexPath
) -> CGFloat {
  // ⚠️ Repeat the same IndexPath-to-row lookup again for sizing.
  switch rows[indexPath.row] {
  case .notifications:
    return 52
  case .details:
    return messageHeight(
      for: "Choose which channels can notify you",
      width: tableView.bounds.width
    )
  case .channel(let channel):
    return messageHeight(for: channel.name, width: tableView.bounds.width)
  }
}
```

A conventional implementation can also use `UITableViewDiffableDataSource` to
derive structural changes from a snapshot. Application code remains responsible
for mapping identifiers to typed configuration, selection, and sizing, and for
choosing which retained items to reconfigure.

### With Folio

Folio represents the same visible rows with the typed `NotificationsRow` and
`MessageRow` descriptors defined in [Sample Usage](#sample-usage). They are
assembled directly from the same state:

```swift
Content {
  Section(id: .main) {
    NotificationsRow(
      id: .notifications,
      isOn: notificationsEnabled,
      onSelect: { [weak self] isOn in
        guard let self else { return }

        self.notificationsEnabled = isOn
        self.render(rowReconfiguration: .only([.notifications]))
      }
    )

    if notificationsEnabled {
      MessageRow(
        id: .details,
        text: "Choose which channels can notify you"
      )

      for channel in channels {
        MessageRow(
          id: .channel(channel.id),
          text: channel.name
        )
      }
    }
  }
}
```

`FolioView` resolves index paths to stable row IDs internally. Configuration and
selection stay with each `Row`, while its declared cell owns sizing. Application
code no longer repeats a central switch or casts across callbacks. Folio applies
each `Content` as a diffable snapshot, deriving counts, insertions, removals, and
moves instead of requiring matching structural update calls. It separately
reconfigures retained rows using `.all` by default or the caller's `.only` or
`.none` policy.

`FolioView` remains a `UITableView`, and rows still configure ordinary UIKit cells.
Folio organizes the coordination layer without replacing UIKit view design.

This is a natural fit for settings, forms, dashboards, and other heterogeneous
tables whose visible sections and rows are derived from state. It is especially
useful when static controls, conditional rows, and generated collections appear
together. A conventional data source may remain simpler for a small homogeneous
table or when another object must own the table's `dataSource` or `delegate`.

## Sample Usage

```swift
import Folio
import UIKit

enum SectionID: Hashable, Sendable {
  case main
}

enum RowID: Hashable, Sendable {
  case notifications
  case details
  case channel(UUID)
}

struct Channel: Sendable {
  let id: UUID
  let name: String
}

@MainActor
final class NotificationsCell: UITableViewCell, SizingCell {
  func apply(isOn: Bool) {
    var configuration = defaultContentConfiguration()
    configuration.text = "Notifications"
    configuration.secondaryText = isOn ? "On" : "Off"
    contentConfiguration = configuration
    accessoryType = isOn ? .checkmark : .none
  }

  func heightThatFits(width: CGFloat) -> CGFloat {
    52
  }
}

@MainActor
final class MessageCell: UITableViewCell, SizingCell {
  private let messageLabel = UILabel()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    messageLabel.numberOfLines = 0
    contentView.addSubview(messageLabel)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("MessageCell does not support Interface Builder")
  }

  func apply(text: String) {
    messageLabel.text = text
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    messageLabel.frame = contentView.bounds.insetBy(dx: 16, dy: 12)
  }

  func heightThatFits(width: CGFloat) -> CGFloat {
    let contentWidth = max(0, width - 32)
    let textHeight = messageLabel.sizeThatFits(
      CGSize(width: contentWidth, height: .greatestFiniteMagnitude)
    ).height
    return max(44, textHeight + 24)
  }
}

@MainActor
struct NotificationsRow: Row {
  let id: RowID
  let isOn: Bool
  let onSelect: @MainActor (Bool) -> Void
  let cellReuseID = "NotificationsCell"

  func configure(_ cell: NotificationsCell) {
    cell.apply(isOn: isOn)
  }

  func didSelect() {
    onSelect(!isOn)
  }
}

@MainActor
struct MessageRow: Row {
  let id: RowID
  let text: String
  let cellReuseID = "MessageCell"

  func configure(_ cell: MessageCell) {
    cell.apply(text: text)
  }
}

@MainActor
final class NotificationSettingsViewController: UIViewController {
  private let folioView = FolioView<SectionID, RowID>(style: .plain)
  private var notificationsEnabled = false

  // These IDs remain stable across renders.
  private let channels = [
    Channel(id: UUID(), name: "Product updates"),
    Channel(id: UUID(), name: "Weekly summary"),
  ]

  override func viewDidLoad() {
    super.viewDidLoad()

    folioView.frame = view.bounds
    folioView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(folioView)

    render(animatingDifferences: false)
  }

  private func makeContent() -> Content<SectionID, RowID> {
    Content {
      Section(id: .main) {
        NotificationsRow(
          id: .notifications,
          isOn: notificationsEnabled,
          onSelect: { [weak self] isOn in
            guard let self else { return }

            self.notificationsEnabled = isOn
            self.render(rowReconfiguration: .only([.notifications]))
          }
        )

        if notificationsEnabled {
          MessageRow(
            id: .details,
            text: "Choose which channels can notify you"
          )

          for channel in channels {
            MessageRow(
              id: .channel(channel.id),
              text: channel.name
            )
          }
        }
      }
    }
  }

  private func render(
    rowReconfiguration: RowReconfiguration<RowID> = .all,
    animatingDifferences: Bool = true
  ) {
    folioView.apply(
      makeContent(),
      rowReconfiguration: rowReconfiguration,
      animatingDifferences: animatingDifferences
    )
  }
}
```

Selecting the notifications row updates controller-owned state and calls `render()`.
The retained notifications row is reconfigured while Folio independently inserts or
removes the conditional message rows.

## Building Content

`Content` is a complete description of the table's desired sections and rows at
one moment. Rebuild it from application state instead of mutating displayed rows
directly.

The `Content` and `Section` builders accept ordinary Swift control flow, including
`if`, `switch`, and `for`. Direct rows, conditional elements, generated collections,
helper arrays, and availability checks can all be mixed in the same hierarchy.

When filtering, sorting, or grouping reads more clearly as imperative code, use
the direct array initializers instead:

```swift
@MainActor
func makeArrayContent() -> Content<SectionID, RowID> {
  let rows: [any Row<RowID>] = [
    MessageRow(id: .details, text: "Choose which channels can notify you")
  ]

  return Content(
    sections: [
      Section(id: .main, rows: rows)
    ]
  )
}
```

Builder and array construction produce the same content model and can be combined.

## Applying State Changes

`FolioView` is a `UITableView` that renders complete `Content` values. Use a
nonanimated first apply, then rebuild and apply after state mutations; later applies
animate by default.

Stable section and row IDs drive insertions, removals, reordering, and moves between
sections. Retained rows can update in place, including their measured height, without
being treated as new rows. Rapid successive applies are supported, and each apply can
provide a completion closure.

### Retained Row Reconfiguration

Every apply reconciles structural differences. A row is retained when its ID appears
in both the previously applied and next `Content`. `RowReconfiguration` separately
controls which retained rows explicitly refresh their visible cells:

| Policy | Behavior |
| --- | --- |
| `.all` | Reconfigures and remeasures every retained row. This is the default. |
| `.only(ids)` | Reconfigures only the supplied retained row IDs. |
| `.none` | Applies structural differences without explicitly reconfiguring retained rows. |

Use `.only(...)` when particular row values, heights, or cell-installed actions
changed while unrelated cells should preserve UIKit-managed state such as first
responder or text selection. Use `.none` only when no retained row's configuration
changed.

Inserted rows always configure normally. Regardless of policy, Folio stores the
newest row descriptor, so future display and selection use the latest value even
when a retained visible cell was not reconfigured.

## Rows and Cells

A `Row` is a lightweight descriptor for one logical row. It declares a stable ID,
a reuse identifier, and the concrete `UITableViewCell` type accepted by
`configure(_:)`. Sections can store heterogeneous rows while each descriptor still
receives its exact cell type without a cast in application code. Folio handles cell
registration, dequeuing, and reuse.

Implement `didSelect()` when a row is interactive. Selection is routed through the
latest descriptor and does not expose the cell; update application state, rebuild
`Content`, and apply it to render the result.

### Manual Sizing

Every row's cell conforms to `SizingCell` and reports its complete height through
`heightThatFits(width:)`. Folio configures an offscreen typed cell before measuring
it at the table's current width, allowing content changes and width changes to
produce new heights without requiring Auto Layout.

Folio currently proposes the table's full bounds width to rows, headers, and
footers. Use `.plain` or `.grouped` when a measured height depends on that
width; inset-grouped content displays at a narrower width and needs a future
width-resolution API for accurate manual measurement.

The returned height must include all cell-owned margins, padding, and accessories.
Because `configure(_:)` runs for both display and sizing, it may be called repeatedly
and must completely and idempotently replace the cell's presentation without
application-state side effects. Manually laid-out views that cache measurements
should invalidate that layout when configuration changes.

## Headers and Footers

Sections accept optional typed `SectionHeader` and `SectionFooter` descriptors.
Their view types conform to `SizingSectionView` and follow the same
configure-then-measure model as rows:

```swift
@MainActor
final class MessageHeaderView: UIView, SizingSectionView {
  private let label = UILabel()

  override init(frame: CGRect) {
    super.init(frame: frame)
    label.numberOfLines = 0
    addSubview(label)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("MessageHeaderView does not support Interface Builder")
  }

  func apply(title: String) {
    label.text = title
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    label.frame = bounds.insetBy(dx: 16, dy: 8)
  }

  func heightThatFits(width: CGFloat) -> CGFloat {
    let contentWidth = max(0, width - 32)
    return label.sizeThatFits(
      CGSize(width: contentWidth, height: .greatestFiniteMagnitude)
    ).height + 16
  }
}

@MainActor
struct MessageHeader: SectionHeader {
  let viewReuseID = "MessageHeaderView"
  let title: String

  func configure(_ view: MessageHeaderView) {
    view.apply(title: title)
  }
}

@MainActor
func makeMessageSection() -> Section<SectionID, RowID> {
  Section(
    id: .main,
    header: MessageHeader(title: "Messages"),
    rows: []
  )
}
```

`SectionFooter` uses the same pattern. Headers and footers can update, resize,
appear, or disappear on retained sections without recreating their row cells. They
reconcile independently of the retained-row reconfiguration policy.

## Identity and Lifecycle Rules

- Within each applied `Content`, section IDs must be unique and row IDs must be
  unique across all sections.
- A stable row ID must keep the same cell type and reuse identifier for the
  `FolioView`'s lifetime.
- A cell reuse identifier must always map to the same cell type across every row
  ID for the `FolioView`'s lifetime.
- A section's header and footer must each keep the same view type and reuse
  identifier whenever that role is present for the `FolioView`'s lifetime.
- Header and footer reuse identifiers share one namespace and must always map to
  the same view type.
- When using `.only(...)`, include every retained row whose presentation, measured
  height, or cell-installed actions changed.
- Row, header, and footer `configure(_:)` methods may run repeatedly for display
  and sizing. They must completely and idempotently update the view without
  application-state side effects.
- Every `heightThatFits(width:)` implementation must return the complete, finite,
  nonnegative height.
- `FolioView` owns its `dataSource` and `delegate`; replacing either is unsupported.
- `FolioView` supports programmatic `init(style:)`, not Interface Builder.

## Contributing

Feel free to open an issue if you have questions about using Folio, find a bug, or
want to improve its implementation or API.

## Credits

Folio is primarily the work of [Daniel Inoa](https://github.com/danielinoa).

## License

Folio is available under the [MIT License](LICENSE).
