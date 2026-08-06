import Testing
import UIKit

@testable import Folio

enum TestSectionID: Hashable, Sendable {
  case primary
  case secondary
  case tertiary
}

enum TestRowID: Hashable, Sendable {
  case first
  case second
}

@MainActor
func makeFolio(
  _ sections: [(TestSectionID, [any Row<TestRowID>])]
) -> Folio<TestSectionID, TestRowID> {
  Folio(
    sections: sections.map { sectionID, rows in
      Section(id: sectionID, rows: rows)
    }
  )
}

@MainActor
func makeSingleSectionFolio(
  sectionID: TestSectionID,
  header: (any SectionHeader)? = nil,
  footer: (any SectionFooter)? = nil,
  rows: [any Row<TestRowID>]
) -> Folio<TestSectionID, TestRowID> {
  Folio(
    sections: [
      Section(
        id: sectionID,
        header: header,
        footer: footer,
        rows: rows
      )
    ]
  )
}

@MainActor
func apply(
  _ content: Folio<TestSectionID, TestRowID>,
  to folioView: FolioView<TestSectionID, TestRowID>,
  animated: Bool
) async {
  await withCheckedContinuation { continuation in
    folioView.apply(
      content,
      animatingDifferences: animated,
      completion: { continuation.resume() }
    )
  }
}

@Suite(.serialized)
@MainActor
struct FolioViewTests {}

@MainActor
final class FolioViewHost {
  let folioView: FolioView<TestSectionID, TestRowID>

  private let viewController: UIViewController
  private let window: UIWindow

  init(
    style: UITableView.Style = .plain,
    size: CGSize = CGSize(width: 320, height: 480)
  ) {
    folioView = FolioView(style: style)
    viewController = UIViewController()
    window = UIWindow(frame: CGRect(origin: .zero, size: size))

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
