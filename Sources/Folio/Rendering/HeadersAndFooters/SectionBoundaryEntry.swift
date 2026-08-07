// Copyright © 2026 Daniel Inoa.

import UIKit

/// A type-erased section-boundary descriptor with reusable view metadata.
/// Separate header and footer maps store entries keyed directly by section ID.
/// This preserves typed configuration while keeping each rendering role explicit.
@MainActor
struct SectionBoundaryEntry {
  let boundary: any SectionBoundary
  let renderingIdentity: SectionBoundaryRenderingIdentity
  let viewType: UIView.Type
}
