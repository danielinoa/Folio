/// A section boundary descriptor valid in a section's footer position.
/// It inherits typed configuration and sizing from `SectionBoundary`.
/// This prevents footer-only descriptors from being supplied as headers.
@MainActor
public protocol SectionFooter: SectionBoundary {}
