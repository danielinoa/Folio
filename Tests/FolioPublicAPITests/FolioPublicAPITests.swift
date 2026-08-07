import Folio
import Testing
import UIKit

// This target intentionally uses `import Folio` instead of `@testable import Folio`
// so it exercises only API available to an external client.
@Suite(.serialized)
@MainActor
struct FolioPublicAPITests {
  @Test
  func sectionBuilderControlFlowIsAvailableToClients() {
    let makeSection = { (id: ClientSectionID) in
      Section<ClientSectionID, ClientRowID>(id: id, rows: [])
    }
    let helperSections = [
      makeSection(.helper(1)),
      makeSection(.helper(2)),
    ]
    let includeConditional = true
    let chooseFirst = false
    let content = Folio<ClientSectionID, ClientRowID> {
      makeSection(.settings)

      if includeConditional {
        makeSection(.conditional)
      }

      if chooseFirst {
        makeSection(.firstChoice)
      } else {
        makeSection(.secondChoice)
      }

      helperSections

      for value in [1, 2] {
        makeSection(.generated(value))
      }

      if #available(iOS 26, *) {
        futureClientSection()
      } else {
        makeSection(.available)
      }
    }

    #expect(
      content.sections.map { $0.id } == [
        .settings,
        .conditional,
        .secondChoice,
        .helper(1),
        .helper(2),
        .generated(1),
        .generated(2),
        .available,
      ])
  }

  @Test
  func rowBuilderControlFlowIsAvailableToClients() {
    let selectionRecorder = SelectionRecorder()
    let makeRow = { (id: ClientRowID) in
      ClientRow(
        id: id,
        title: String(describing: id),
        height: 44,
        selectionRecorder: selectionRecorder
      )
    }
    let concreteRows = [makeRow(.helper(1)), makeRow(.helper(2))]
    let erasedRows: [any Row<ClientRowID>] = [makeRow(.erased)]
    let includeConditional = true
    let chooseFirst = false
    let section = Section<ClientSectionID, ClientRowID>(id: .settings) {
      makeRow(.notifications)

      if includeConditional {
        makeRow(.conditional)
      }

      if chooseFirst {
        makeRow(.firstChoice)
      } else {
        makeRow(.secondChoice)
      }

      concreteRows
      erasedRows

      for value in [1, 2] {
        makeRow(.generated(value))
      }

      if #available(iOS 26, *) {
        FutureClientRow(id: .available)
      } else {
        makeRow(.available)
      }
    }

    #expect(
      section.rows.map { $0.id } == [
        .notifications,
        .conditional,
        .secondChoice,
        .helper(1),
        .helper(2),
        .erased,
        .generated(1),
        .generated(2),
        .available,
      ])
  }

  @Test
  func completeFolioRendersThroughThePublicAPI() async throws {
    let selectionRecorder = SelectionRecorder()
    let headerRecorder = BoundaryRecorder()
    let footerRecorder = BoundaryRecorder()
    let row = ClientRow(
      id: .notifications,
      title: "Notifications",
      height: 64,
      selectionRecorder: selectionRecorder
    )
    let content: Folio<ClientSectionID, ClientRowID> = Folio(
      sections: [
        Section(
          id: .settings,
          header: ClientHeader(
            title: "Settings",
            height: 32,
            recorder: headerRecorder
          ),
          footer: ClientFooter(
            title: "Changes apply immediately",
            height: 24,
            recorder: footerRecorder
          ),
          rows: [row]
        )
      ]
    )
    let host = ClientFolioViewHost()
    let folioView = host.folioView
    defer { host.tearDown() }

    await apply(content, to: folioView)

    let indexPath = IndexPath(row: 0, section: 0)
    #expect(folioView.numberOfSections == 1)
    #expect(folioView.numberOfRows(inSection: 0) == 1)

    let cell = try #require(
      folioView.dataSource?.tableView(folioView, cellForRowAt: indexPath)
        as? ClientCell
    )
    #expect(cell.title == "Notifications")
    #expect(folioView.tableView(folioView, heightForRowAt: indexPath) == 64)

    let header = folioView.tableView(folioView, viewForHeaderInSection: 0)
    let footer = folioView.tableView(folioView, viewForFooterInSection: 0)
    #expect(header != nil)
    #expect(footer != nil)
    #expect(folioView.tableView(folioView, heightForHeaderInSection: 0) == 32)
    #expect(folioView.tableView(folioView, heightForFooterInSection: 0) == 24)
    #expect(headerRecorder.configuredTitles.contains("Settings"))
    #expect(footerRecorder.configuredTitles.contains("Changes apply immediately"))

    UIView.performWithoutAnimation {
      folioView.tableView(folioView, didSelectRowAt: indexPath)
    }
    #expect(selectionRecorder.count == 1)
  }
}

@Suite
struct RowBuilderIsolationPublicAPITests {
  @Test
  func sectionCanBeBuiltFromANonisolatedContext() async {
    _ = await Section<ClientSectionID, ClientRowID>(id: .settings) {
      IsolatedClientRow(id: .notifications)
    }
  }
}

@Suite
struct SectionBuilderIsolationPublicAPITests {
  @Test
  func nestedBuildersCanBeUsedFromANonisolatedContext() async {
    _ = await Folio {
      Section(id: ClientSectionID.settings) {
        IsolatedClientRow(id: ClientRowID.notifications)
      }
    }
  }
}

private enum ClientSectionID: Hashable, Sendable {
  case settings
  case conditional
  case firstChoice
  case secondChoice
  case helper(Int)
  case generated(Int)
  case available
}

private enum ClientRowID: Hashable, Sendable {
  case notifications
  case conditional
  case firstChoice
  case secondChoice
  case helper(Int)
  case erased
  case generated(Int)
  case available
}

@MainActor
private struct IsolatedClientRow: Row {
  let id: ClientRowID
  let cellReuseID = "IsolatedClientCell"

  init(id: ClientRowID) {
    self.id = id
  }

  func configure(_ cell: ClientCell) {}
}

@available(iOS 26, *)
@MainActor
private struct FutureClientRow: Row {
  let id: ClientRowID
  let cellReuseID = "FutureClientCell"

  func configure(_ cell: ClientCell) {}
}

@available(iOS 26, *)
@MainActor
private func futureClientSection() -> Section<ClientSectionID, ClientRowID> {
  Section(id: .available, rows: [])
}

@MainActor
private final class ClientFolioViewHost {
  let folioView = FolioView<ClientSectionID, ClientRowID>(style: .plain)

  private let viewController = UIViewController()
  private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

  init() {
    window.rootViewController = viewController
    viewController.view.addSubview(folioView)
    folioView.frame = viewController.view.bounds
    window.makeKeyAndVisible()
  }

  func tearDown() {
    window.isHidden = true
    folioView.removeFromSuperview()
    window.rootViewController = nil
  }
}

@MainActor
private final class SelectionRecorder {
  var count = 0
}

@MainActor
private struct ClientRow: Row {
  let id: ClientRowID
  let title: String
  let height: CGFloat
  let selectionRecorder: SelectionRecorder
  let cellReuseID = "ClientCell"

  func configure(_ cell: ClientCell) {
    cell.title = title
    cell.measuredHeight = height
  }

  func didSelect() {
    selectionRecorder.count += 1
  }
}

@MainActor
private final class ClientCell: UITableViewCell, SizingCell {
  var title = ""
  var measuredHeight: CGFloat = 0

  func heightThatFits(width: CGFloat) -> CGFloat {
    measuredHeight
  }
}

@MainActor
private final class BoundaryRecorder {
  var configuredTitles: [String] = []
}

@MainActor
private struct ClientHeader: SectionHeader {
  let title: String
  let height: CGFloat
  let recorder: BoundaryRecorder
  let viewReuseID = "ClientHeader"

  func configure(_ view: ClientBoundaryView) {
    view.title = title
    view.measuredHeight = height
    recorder.configuredTitles.append(title)
  }
}

@MainActor
private struct ClientFooter: SectionFooter {
  let title: String
  let height: CGFloat
  let recorder: BoundaryRecorder
  let viewReuseID = "ClientFooter"

  func configure(_ view: ClientBoundaryView) {
    view.title = title
    view.measuredHeight = height
    recorder.configuredTitles.append(title)
  }
}

@MainActor
private final class ClientBoundaryView: UIView, SizingSectionView {
  var title = ""
  var measuredHeight: CGFloat = 0

  override init(frame: CGRect) {
    super.init(frame: frame)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func heightThatFits(width: CGFloat) -> CGFloat {
    measuredHeight
  }
}

@MainActor
private func apply(
  _ content: Folio<ClientSectionID, ClientRowID>,
  to folioView: FolioView<ClientSectionID, ClientRowID>
) async {
  await withCheckedContinuation { continuation in
    folioView.apply(
      content,
      animatingDifferences: false,
      completion: { continuation.resume() }
    )
  }
}
