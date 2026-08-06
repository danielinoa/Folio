import UIKit

/// The reusable UIKit shell that owns one typed header or footer content view.
/// Keeping this shell present when its role is empty lets Folio later show, hide, or
/// resize section presentation without asking UIKit to reload the section.
@MainActor
final class HeaderFooterContainerView: UITableViewHeaderFooterView {
  static let headerReuseID = "Folio.SectionHeaderContainer"
  static let footerReuseID = "Folio.SectionFooterContainer"

  private(set) var hostedView: UIView?
  private(set) var hostedReuseID: String?

  override init(reuseIdentifier: String?) {
    super.init(reuseIdentifier: reuseIdentifier)
    backgroundConfiguration = UIBackgroundConfiguration.clear()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func host(_ view: UIView, reuseID: String) {
    guard hostedView !== view else { return }

    hostedView?.removeFromSuperview()
    hostedView = view
    hostedReuseID = reuseID
    contentView.addSubview(view)
    setNeedsLayout()
  }

  func removeHostedView() {
    hostedView?.removeFromSuperview()
    hostedView = nil
    hostedReuseID = nil
    setNeedsLayout()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    hostedView?.frame = contentView.bounds
  }
}
