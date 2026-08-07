// Copyright © 2026 Daniel Inoa.

import UIKit

/// A manual sizing contract for reusable section header and footer views.
/// Folio configures an offscreen instance, then measures it at the table's width.
/// This supports changing boundary heights without Auto Layout or UIKit estimates.
@MainActor
public protocol SizingSectionView: AnyObject {
  /// Creates a reusable display or offscreen sizing instance.
  init(frame: CGRect)

  /// Returns the complete view height required at the proposed presentation width.
  ///
  /// The result includes all view-owned content, margins, and padding, and must
  /// be finite and nonnegative.
  func heightThatFits(width: CGFloat) -> CGFloat
}
