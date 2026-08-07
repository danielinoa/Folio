// Copyright © 2026 Daniel Inoa.

import UIKit

/// Measures configured header and footer prototypes independently of display views.
/// It retains one typed sizing view per reuse identifier until a render-boundary reset.
/// This isolates manual boundary measurement state while preserving exact view types.
@MainActor
struct SectionBoundaryMeasurer {
  private var prototypesByReuseID: [String: UIView] = [:]

  mutating func reset() {
    prototypesByReuseID.removeAll()
  }

  mutating func height<S: SectionBoundary>(for boundary: S, width: CGFloat) -> CGFloat {
    let view: S.ViewType

    if let cachedView = prototypesByReuseID[boundary.viewReuseID] {
      guard let typedView = cachedView as? S.ViewType else {
        preconditionFailure(
          "Sizing section-boundary view for reuse identifier "
            + "'\(boundary.viewReuseID)' is "
            + "\(String(reflecting: type(of: cachedView))), but the descriptor "
            + "requires \(String(reflecting: S.ViewType.self))."
        )
      }
      view = typedView
    } else {
      view = S.ViewType(frame: .zero)
      prototypesByReuseID[boundary.viewReuseID] = view
    }

    precondition(
      width.isFinite && width >= .zero,
      "Cannot measure a section header or footer using invalid table width \(width)."
    )

    boundary.configure(view)
    let height = view.heightThatFits(width: width)
    precondition(
      height.isFinite && height >= .zero,
      "\(String(reflecting: S.ViewType.self)) returned invalid header/footer "
        + "height \(height) for width \(width)."
    )

    return height == .zero ? .leastNormalMagnitude : ceil(height)
  }
}
