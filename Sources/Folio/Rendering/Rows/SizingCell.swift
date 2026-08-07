// Copyright © 2026 Daniel Inoa.

import UIKit

/// A sizing contract for manually laid-out table-view cells at a proposed width.
///
/// `FolioView` configures a conforming cell before asking it to measure, allowing
/// layouts such as ArrangeUI to determine row height without Auto Layout. The cell
/// accounts for any margins, padding, or accessories it owns.
@MainActor
public protocol SizingCell: AnyObject {
  /// Returns the complete height required for the proposed presentation width.
  ///
  /// The result includes all cell-owned content, margins, padding, and
  /// accessories, and must be finite and nonnegative.
  func heightThatFits(width: CGFloat) -> CGFloat
}
