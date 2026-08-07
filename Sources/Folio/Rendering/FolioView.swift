// Copyright © 2026 Daniel Inoa.

import UIKit

/// A table view that manually measures row heights and reconciles `Folio` snapshots.
///
/// It validates stable identities, applies structural changes through a diffable
/// data source, and opens row and section-boundary existentials for typed view
/// configuration and measurement. This lets table content be rebuilt from state
/// without losing its row, header, or footer type guarantees.
///
/// Folio requires ownership of the inherited `dataSource` and `delegate` properties;
/// replacing either one is unsupported because it bypasses reconciliation.
@MainActor
public final class FolioView<SectionID, RowID>: UITableView, UITableViewDelegate
where
  SectionID: Hashable & Sendable,
  RowID: Hashable & Sendable
{

  // MARK: - State

  private typealias DataSource = UITableViewDiffableDataSource<SectionID, RowID>

  private var cellRegistrations: [String: UITableViewCell.Type] = [:]
  private var rowRenderingIdentities: [RowID: RowRenderingIdentity] = [:]
  private var boundaryViewTypesByReuseID: [String: UIView.Type] = [:]
  private var headerRenderingIdentities: [SectionID: SectionBoundaryRenderingIdentity] = [:]
  private var footerRenderingIdentities: [SectionID: SectionBoundaryRenderingIdentity] = [:]
  private var rowMeasurer = RowMeasurer()
  private var sectionBoundaryMeasurer = SectionBoundaryMeasurer()

  // Current descriptors serve new cells and interactions. The active maps also
  // retain outgoing descriptors until the newest animated transition completes.
  private var currentSectionIDs: Set<SectionID> = []
  private var currentRows: [RowID: RowEntry<RowID>] = [:]
  private var currentHeaders: [SectionID: SectionBoundaryEntry] = [:]
  private var currentFooters: [SectionID: SectionBoundaryEntry] = [:]
  private var activeRows: [RowID: RowEntry<RowID>] = [:]
  private var activeHeaders: [SectionID: SectionBoundaryEntry] = [:]
  private var activeFooters: [SectionID: SectionBoundaryEntry] = [:]
  private var applyGeneration = 0

  private var snapshotDataSource: DataSource!

  // MARK: - Initialization

  public init(style: UITableView.Style) {
    super.init(frame: .zero, style: style)

    delegate = self
    estimatedSectionHeaderHeight = 0
    estimatedSectionFooterHeight = 0
    // Folio's manual measurement is the complete header or footer height; UIKit's
    // default plain-table padding would otherwise add unmeasured space above it.
    sectionHeaderTopPadding = 0
    register(
      HeaderFooterContainerView.self,
      forHeaderFooterViewReuseIdentifier: HeaderFooterContainerView.headerReuseID
    )
    register(
      HeaderFooterContainerView.self,
      forHeaderFooterViewReuseIdentifier: HeaderFooterContainerView.footerReuseID
    )
    snapshotDataSource = DataSource(tableView: self) { [weak self] tableView, indexPath, rowID in
      guard let self else { return nil }
      return self.displayCell(for: rowID, at: indexPath, in: tableView)
    }
  }

  @available(
    *,
    unavailable,
    message: "FolioView does not support Interface Builder. Use init(style:) instead."
  )
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Applying Content

  /// Reconciles the table with a complete identified content snapshot.
  ///
  /// The first render should normally pass `false`; later renders can animate
  /// structural insertions, removals, and moves. New row IDs create or dequeue
  /// cells, removed IDs delete them, and retained IDs use `reconfigureItems(_:)`
  /// to update visible cells in place. Reconfiguration reruns configuration and
  /// row measurement, allowing value-only changes to resize without replacing
  /// the row. Retained headers and footers are likewise reconfigured and
  /// remeasured without reloading their section or its cells. Rapid successive
  /// applies are supported; only the newest completion prunes descriptors
  /// retained for an in-flight transition.
  public func apply(
    _ content: Folio<SectionID, RowID>,
    animatingDifferences: Bool = true,
    completion: (() -> Void)? = nil
  ) {
    let prepared = prepare(content)
    var nextSnapshot = prepared.snapshot
    let previousRowIDs = Set(snapshotDataSource.snapshot().itemIdentifiers)
    let retainedRowIDs = nextSnapshot.itemIdentifiers.filter(previousRowIDs.contains)
    let shouldReconcileHeadersAndFooters =
      !currentHeaders.isEmpty || !activeHeaders.isEmpty
      || !prepared.headersBySectionID.isEmpty || !currentFooters.isEmpty
      || !activeFooters.isEmpty || !prepared.footersBySectionID.isEmpty

    if !retainedRowIDs.isEmpty {
      // Preserve row identity and visible cells while refreshing their values and heights.
      nextSnapshot.reconfigureItems(retainedRowIDs)
    }

    commitRegistrations(in: prepared)

    activeRows.merge(currentRows) { _, current in current }
    activeHeaders.merge(currentHeaders) { _, current in current }
    activeFooters.merge(currentFooters) { _, current in current }
    activeRows.merge(prepared.rowsByID) { _, next in next }
    activeHeaders.merge(prepared.headersBySectionID) { _, next in next }
    activeFooters.merge(prepared.footersBySectionID) { _, next in next }
    currentSectionIDs = prepared.sectionIDs
    currentRows = prepared.rowsByID
    currentHeaders = prepared.headersBySectionID
    currentFooters = prepared.footersBySectionID

    rowRenderingIdentities = prepared.rowRenderingIdentities
    headerRenderingIdentities = prepared.headerRenderingIdentities
    footerRenderingIdentities = prepared.footerRenderingIdentities

    // Prototype instances can hold trait-dependent presentation. Recreate them
    // at each coherent render boundary while retaining them between measurements.
    rowMeasurer.reset()
    sectionBoundaryMeasurer.reset()

    applyGeneration += 1
    let generation = applyGeneration
    snapshotDataSource.apply(
      nextSnapshot,
      animatingDifferences: animatingDifferences
    ) { [weak self] in
      guard let self else {
        completion?()
        return
      }
      guard generation == self.applyGeneration else {
        completion?()
        return
      }

      self.activeRows = self.currentRows
      self.activeHeaders = self.currentHeaders
      self.activeFooters = self.currentFooters
      if shouldReconcileHeadersAndFooters {
        self.reconcileVisibleHeadersAndFooters(
          animatingDifferences: animatingDifferences,
          completion: completion
        )
      } else {
        completion?()
      }
    }
  }

  // MARK: - Content Preparation

  private func prepare(
    _ content: Folio<SectionID, RowID>
  ) -> PreparedContent<SectionID, RowID> {
    let validator = SnapshotValidator<SectionID, RowID>(
      existingCellRegistrations: cellRegistrations,
      existingRowRenderingIdentities: rowRenderingIdentities,
      existingBoundaryViewTypesByReuseID: boundaryViewTypesByReuseID,
      existingHeaderRenderingIdentities: headerRenderingIdentities,
      existingFooterRenderingIdentities: footerRenderingIdentities
    )

    switch validator.prepare(content) {
    case .success(let prepared):
      return prepared
    case .failure(let error):
      preconditionFailure(error.preconditionMessage)
    }
  }

  private func commitRegistrations(in content: PreparedContent<SectionID, RowID>) {
    for (reuseID, cellType) in content.cellRegistrations {
      guard cellRegistrations[reuseID] == nil else { continue }

      register(cellType, forCellReuseIdentifier: reuseID)
    }
    cellRegistrations = content.cellRegistrations

    boundaryViewTypesByReuseID = content.boundaryViewTypesByReuseID
  }

  // MARK: - Row Display

  private func displayCell(
    for rowID: RowID,
    at indexPath: IndexPath,
    in tableView: UITableView
  ) -> UITableViewCell {
    guard let entry = currentRows[rowID] ?? activeRows[rowID] else {
      preconditionFailure(
        "No applied row descriptor exists for identity \(String(reflecting: rowID))."
      )
    }
    return dequeueAndConfigureCell(for: entry.row, at: indexPath, in: tableView)
  }

  /// Passing an existential row to this generic helper implicitly opens it,
  /// restoring `R.CellType` for typed configuration.
  ///
  /// See [SE-0352: Implicitly Opened Existentials](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0352-implicit-open-existentials.md).
  private func dequeueAndConfigureCell<R: Row>(
    for row: R,
    at indexPath: IndexPath,
    in tableView: UITableView
  ) -> UITableViewCell where R.ID == RowID {
    let cell = tableView.dequeueReusableCell(
      withIdentifier: row.cellReuseID,
      for: indexPath
    )
    guard let typedCell = cell as? R.CellType else {
      preconditionFailure(
        """
        Dequeued \(String(reflecting: type(of: cell))) for reuse identifier \
        '\(row.cellReuseID)', but the row requires \
        \(String(reflecting: R.CellType.self)).
        """
      )
    }
    row.configure(typedCell)
    return typedCell
  }

  // MARK: - Row Measurement

  public func tableView(
    _ tableView: UITableView,
    heightForRowAt indexPath: IndexPath
  ) -> CGFloat {
    guard
      let rowID = snapshotDataSource.itemIdentifier(for: indexPath),
      let entry = currentRows[rowID] ?? activeRows[rowID]
    else {
      preconditionFailure("No applied row exists at index path \(indexPath).")
    }
    return rowMeasurer.height(for: entry.row, width: tableView.bounds.width)
  }

  // MARK: - Selection

  public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    guard
      let rowID = snapshotDataSource.itemIdentifier(for: indexPath),
      let row = currentRows[rowID]?.row
    else {
      return
    }

    // Capture the descriptor because the action may synchronously apply new content.
    row.didSelect()
  }

  // MARK: - Header and Footer Display

  public func tableView(
    _ tableView: UITableView,
    viewForHeaderInSection section: Int
  ) -> UIView? {
    displayHeader(at: section, in: tableView)
  }

  public func tableView(
    _ tableView: UITableView,
    viewForFooterInSection section: Int
  ) -> UIView? {
    displayFooter(at: section, in: tableView)
  }

  private func displayHeader(
    at section: Int,
    in tableView: UITableView
  ) -> UIView? {
    displaySectionBoundary(
      headerEntry(at: section),
      containerReuseID: HeaderFooterContainerView.headerReuseID,
      in: tableView
    )
  }

  private func displayFooter(
    at section: Int,
    in tableView: UITableView
  ) -> UIView? {
    displaySectionBoundary(
      footerEntry(at: section),
      containerReuseID: HeaderFooterContainerView.footerReuseID,
      in: tableView
    )
  }

  private func displaySectionBoundary(
    _ entry: SectionBoundaryEntry?,
    containerReuseID: String,
    in tableView: UITableView
  ) -> UIView? {
    guard
      let container = tableView.dequeueReusableHeaderFooterView(
        withIdentifier: containerReuseID
      ) as? HeaderFooterContainerView
    else {
      preconditionFailure("Folio could not dequeue its header/footer container.")
    }

    if let entry {
      configure(entry.boundary, in: container)
      container.isHidden = false
    } else {
      container.removeHostedView()
      container.isHidden = true
    }
    return container
  }

  /// Opening the boundary existential restores and configures its exact view type.
  private func configure<S: SectionBoundary>(
    _ boundary: S,
    in container: HeaderFooterContainerView
  ) {
    let view: S.ViewType

    if container.hostedReuseID == boundary.viewReuseID,
      let hostedView = container.hostedView as? S.ViewType
    {
      view = hostedView
    } else {
      view = S.ViewType(frame: .zero)
      container.host(view, reuseID: boundary.viewReuseID)
    }

    view.isHidden = false
    boundary.configure(view)
  }

  // MARK: - Header and Footer Measurement

  public func tableView(
    _ tableView: UITableView,
    heightForHeaderInSection section: Int
  ) -> CGFloat {
    measuredHeaderHeight(at: section, in: tableView)
  }

  public func tableView(
    _ tableView: UITableView,
    heightForFooterInSection section: Int
  ) -> CGFloat {
    measuredFooterHeight(at: section, in: tableView)
  }

  private func measuredHeaderHeight(
    at section: Int,
    in tableView: UITableView
  ) -> CGFloat {
    guard let entry = headerEntry(at: section) else {
      // Zero asks UIKit to use its default section metric; the smallest positive
      // value explicitly suppresses an absent custom header instead.
      return .leastNormalMagnitude
    }
    return sectionBoundaryMeasurer.height(
      for: entry.boundary,
      width: tableView.bounds.width
    )
  }

  private func measuredFooterHeight(
    at section: Int,
    in tableView: UITableView
  ) -> CGFloat {
    guard let entry = footerEntry(at: section) else {
      // Zero asks UIKit to use its default section metric; the smallest positive
      // value explicitly suppresses an absent custom footer instead.
      return .leastNormalMagnitude
    }
    return sectionBoundaryMeasurer.height(
      for: entry.boundary,
      width: tableView.bounds.width
    )
  }

  private func headerEntry(at section: Int) -> SectionBoundaryEntry? {
    guard let sectionID = sectionID(at: section) else { return nil }

    // An existing current section with an absent descriptor intentionally hides
    // its header; only an outgoing section may fall back to the active header.
    if currentSectionIDs.contains(sectionID) {
      return currentHeaders[sectionID]
    }
    return activeHeaders[sectionID]
  }

  private func footerEntry(at section: Int) -> SectionBoundaryEntry? {
    guard let sectionID = sectionID(at: section) else { return nil }

    // An existing current section with an absent descriptor intentionally hides
    // its footer; only an outgoing section may fall back to the active footer.
    if currentSectionIDs.contains(sectionID) {
      return currentFooters[sectionID]
    }
    return activeFooters[sectionID]
  }

  private func sectionID(at section: Int) -> SectionID? {
    let sectionIDs = snapshotDataSource.snapshot().sectionIdentifiers
    guard sectionIDs.indices.contains(section) else { return nil }
    return sectionIDs[section]
  }

  // MARK: - Header and Footer Reconciliation

  private func reconcileVisibleHeadersAndFooters(
    animatingDifferences: Bool,
    completion: (() -> Void)?
  ) {
    reconfigureVisibleHeadersAndFooters()

    if animatingDifferences {
      // An empty table update asks the delegate for current header and footer
      // heights, animating geometry without reloading retained row cells.
      performBatchUpdates(nil) { _ in completion?() }
    } else {
      UIView.performWithoutAnimation {
        beginUpdates()
        endUpdates()
        layoutIfNeeded()
      }
      completion?()
    }
  }

  private func reconfigureVisibleHeadersAndFooters() {
    let sectionIDs = snapshotDataSource.snapshot().sectionIdentifiers

    for (section, sectionID) in sectionIDs.enumerated() {
      reconfigureVisibleSectionBoundary(
        headerView(forSection: section),
        entry: currentHeaders[sectionID]
      )
      reconfigureVisibleSectionBoundary(
        footerView(forSection: section),
        entry: currentFooters[sectionID]
      )
    }
  }

  private func reconfigureVisibleSectionBoundary(
    _ view: UITableViewHeaderFooterView?,
    entry: SectionBoundaryEntry?
  ) {
    guard let container = view as? HeaderFooterContainerView else {
      return
    }
    guard let entry else {
      container.removeHostedView()
      container.isHidden = true
      return
    }

    configure(entry.boundary, in: container)
    container.isHidden = false
  }
}
