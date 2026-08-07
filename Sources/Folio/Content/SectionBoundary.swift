// Copyright © 2026 Daniel Inoa.

import UIKit

/// A typed configuration contract shared by section headers and footers.
/// `SectionHeader` and `SectionFooter` assign each descriptor to a rendering role.
/// This shares rendering mechanics without weakening role-specific type guarantees.
@MainActor
public protocol SectionBoundary {
  associatedtype ViewType: UIView & SizingSectionView

  /// A stable reusable-view identifier that always maps to one `ViewType`.
  ///
  /// Headers and footers retain identity separately by section, but share one
  /// reuse-ID namespace for the lifetime of their `FolioView`.
  var viewReuseID: String { get }

  /// Applies the descriptor's complete current presentation to `view`.
  ///
  /// Folio calls this for display and offscreen sizing views, and may call it
  /// repeatedly on a retained visible view. Implementations must be idempotent,
  /// replace stale presentation, avoid application-state or lifecycle effects,
  /// and invalidate manual-layout measurements affected by the new presentation.
  func configure(_ view: ViewType)
}
