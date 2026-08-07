// Copyright © 2026 Daniel Inoa.

/// A section boundary descriptor valid in a section's header position.
/// It inherits typed configuration and sizing from `SectionBoundary`.
/// This prevents header-only descriptors from being supplied as footers.
@MainActor
public protocol SectionHeader: SectionBoundary {}
