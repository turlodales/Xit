import Cocoa

fileprivate let batchSize = 500

public class HistoryTableController: NSViewController,
                                     RepositoryWindowViewController
{
  typealias Repository = BasicRepository & FileChangesRepo &
                         CommitStorage & FileContents
  
  enum ColumnID
  {
    static let commit = ¶"commit"
    static let author = ¶"author"
    static let authorDate = ¶"authorDate"
    static let committer = ¶"committer"
    static let committerDate = ¶"committerDate"
    static let sha = ¶"sha"
  }
  
  @IBOutlet var contextMenu: NSMenu!
  
  var tableView: HistoryTableView { view as! HistoryTableView }

  let history = GitCommitHistory()
  
  var repository: Repository { repoController?.repository as! Repository }
  
  func finishLoad(repository: Repository)
  {
    history.repository = repository
    
    guard let table = view as? NSTableView
    else { return }
    var spacing = table.intercellSpacing
    
    spacing.height = 0
    table.intercellSpacing = spacing
    
    loadHistory()
    
    let center = NotificationCenter.default
    
    center.addObserver(forName: .XTRepositoryRefsChanged,
                          object: repository, queue: .main) {
      [weak self] _ in
      // To do: dynamic updating
      // - new and changed refs: add if they're not already in the list
      // - deleted and changed refs: recursively remove unreferenced commits
      
      // For now: just reload
      self?.reload()
    }
    center.addObserver(forName: .XTReselectModel,
                          object: repository, queue: .main) {
                            [weak self] _ in
      guard let tableView = self?.view as? NSTableView,
            let selectedIndex = tableView.selectedRowIndexes.first
      else { return }
      
      tableView.scrollRowToCenter(selectedIndex)
    }
  }
  
  public override func viewDidLoad()
  {
    super.viewDidLoad()
  
    tableView.setAccessibilityIdentifier("history")
    let controller = view.window?.windowController!
    
    NotificationCenter.default.addObserver(
        forName: .XTSelectedModelChanged,
        object: controller,
        queue: .main) {
      [weak self] (_) in
      guard let self = self,
            let selection = self.repoUIController?.selection,
            // In spite of the `object` parameter, notifications can come
            // through for the wrong repository
            selection.repository.repoURL == self.repository.repoURL
      else { return }
      
      self.selectRow(sha: selection.shaToSelect)
    }
    
    history.postProgress = {
      [weak self] in
      self?.batchFinished(start: $0, end: $1)
    }
  }
  
  public override func viewWillDisappear()
  {
    history.abort()
  }
  
  /// Reloads the commit history from scratch.
  public func reload()
  {
    loadHistory()
    tableView.reloadData()
  }
  
  func loadHistory()
  {
    let history = self.history
    weak var tableView = view as? NSTableView
    
    history.withSync {
      history.reset()
    }
    repoUIController?.queue.executeOffMainThread {
      let repository = self.repository

      Signpost.intervalStart(.historyWalking, object: self)
      defer {
        Signpost.intervalEnd(.historyWalking, object: self)
      }
      
      guard let walker = repository.walker()
      else {
        NSLog("RevWalker failed")
        return
      }
      
      walker.setSorting([.topological])
      
      let refs = repository.allRefs()
      
      for ref in refs where ref != "refs/stash" {
        repository.oid(forRef: ref).map { walker.push(oid: $0) }
      }

      history.withSync {
        while let oid = walker.next() {
          guard let commit = repository.commit(forOID: oid)
          else { continue }
          
          history.appendCommit(commit)
        }
      }
      
      DispatchQueue.global(qos: .utility).async {
        // Get off the queue thread, but run this as a queue task so that
        // progress will be displayed.
        self.repoUIController?.queue.executeTask {
          Signpost.interval(.connectCommits) {
            history.processFirstBatch()
          }
        }
        DispatchQueue.main.async {
          [weak self] in
          tableView?.reloadData()
          self?.ensureSelection()
        }
      }
    }
  }
  
  /// Notifier for history processing progress
  /// - parameter start: Row where the batch started
  /// - parameter end: Row where the batch ended
  func batchFinished(start: Int, end: Int)
  {
    DispatchQueue.main.async {
      [weak self] in
      guard let tableView = self?.tableView
      else { return }
      
      let batchRange = start..<end
      let columnRange = 0..<tableView.tableColumns.count
      var updateRange: ClosedRange<Int>?
      
      tableView.enumerateAvailableRowViews {
        (rowView, row) in
        guard batchRange.contains(row)
        else { return }
        
        if let oldRange = updateRange {
          let start = min(row, oldRange.lowerBound)
          let end = max(row, oldRange.upperBound)

          updateRange = start...end
        }
        else {
          updateRange = row...row
        }
        
        if let cellView = rowView.view(atColumn: 0) as? HistoryCellView {
          cellView.needsUpdateConstraints = true
          cellView.needsDisplay = true
        }
        else {
          rowView.needsDisplay = true
        }
      }
      if let range = updateRange {
        tableView.reloadData(forRowIndexes: IndexSet(integersIn: range),
                             columnIndexes: IndexSet(integersIn: columnRange))
      }
    }
  }
  
  func ensureSelection()
  {
    guard let tableView = view as? NSTableView,
          tableView.selectedRowIndexes.isEmpty
    else { return }
    
    guard let selection = repoUIController?.selection
    else { return }
    
    selectRow(sha: selection.shaToSelect, forceScroll: true)
  }
  
  /// Selects the row for the given commit SHA.
  func selectRow(sha: String?, forceScroll: Bool = false)
  {
    let tableView = view as! NSTableView
    
    objc_sync_enter(self)
    objc_sync_enter(history)
    defer {
      objc_sync_exit(history)
      objc_sync_exit(self)
    }
    
    guard let sha = sha,
          let row = history.entries.firstIndex(where: { $0.commit.sha == sha })
    else {
      tableView.deselectAll(self)
      return
    }
    guard tableView.selectedRow != row || tableView.numberOfSelectedRows != 1
    else { return }
    
    tableView.selectRowIndexes(IndexSet(integer: row),
                               byExtendingSelection: false)
    if forceScroll || (view.window?.firstResponder !== tableView) {
      tableView.scrollRowToCenter(row)
    }
  }
  
  public func refreshText()
  {
    for rowIndex in tableView.visibleRows() {
      guard let rowView = tableView.rowView(atRow: rowIndex,
                                            makeIfNecessary: false)
      else { continue }
      
      for column in 0..<rowView.numberOfColumns {
        guard let cellView = rowView.view(atColumn: column) as? NSTableCellView
        else { continue }
        
        setCellTextColor(cellView, index: rowIndex)
      }
    }
  }
  
  func setCellTextColor(_ cellView: NSTableCellView, index: Int)
  {
    let entry = history.entries[index]
    let deemphasized = (entry.commit.parentOIDs.count > 1) &&
                       UserDefaults.standard.deemphasizeMerges

    if let textField = cellView.textField {
      textField.textColor = deemphasized
          ? NSColor.disabledControlTextColor
          : NSColor.controlTextColor
    }
    else if let historyCellView = cellView as? HistoryCellView {
      historyCellView.deemphasized = deemphasized
    }
  }
}

extension HistoryTableController: NSTableViewDelegate
{
  public func displayString(name: String?, email: String?) -> String
  {
    if let name = name {
      if let email = email {
        return "\(name) <\(email)>"
      }
      else {
        return name
      }
    }
    else {
      return email ?? "—"
    }
  }

  public func tableView(_ tableView: NSTableView,
                        viewFor tableColumn: NSTableColumn?,
                        row: Int) -> NSView?
  {
    let visibleRowCount =
          tableView.rows(in: tableView.enclosingScrollView!.bounds).length
    let (entryCount, batchStart) = history.withSync {
      (history.entries.count, history.batchStart)
    }
    let firstProcessRow = min(entryCount, row + visibleRowCount)
    
    if firstProcessRow > batchStart
    {
      history.processBatches(throughRow: firstProcessRow,
                             queue: repoUIController!.queue)
    }
    
    guard (row >= 0) && (row < entryCount)
    else {
      NSLog("Object value request out of bounds")
      return nil
    }
    guard let tableColumn = tableColumn,
          let result = tableView.makeView(withIdentifier: tableColumn.identifier,
                                          owner: self) as? NSTableCellView
    else { return nil }
    
    let entry = history.entries[row]

    switch tableColumn.identifier {
      
      case ColumnID.commit:
        let historyCell = result as! HistoryCellView
        
        historyCell.configure(
              entry: entry,
              repository: repository as! Branching & CommitReferencing)
        historyCell.lockObject = history

      case ColumnID.author:
        result.textField?.stringValue =
            displayString(name: entry.commit.authorName,
                          email: entry.commit.authorEmail)

      case ColumnID.authorDate:
        (result as! DateCellView).date = entry.commit.authorDate

      case ColumnID.committer:
        result.textField?.stringValue =
            displayString(name: entry.commit.committerName,
                          email: entry.commit.committerEmail)

      case ColumnID.committerDate:
        (result as! DateCellView).date = entry.commit.commitDate

      case ColumnID.sha:
        result.textField?.stringValue = entry.commit.sha.firstSix()

      default:
        return nil
    }
    
    setCellTextColor(result, index: row)
    
    return result
  }
 
  public func tableViewSelectionDidChange(_ notification: Notification)
  {
    guard view.window?.firstResponder === view,
          let tableView = notification.object as? NSTableView
    else { return }
    
    let selectedRow = tableView.selectedRow
    
    if (selectedRow >= 0) && (selectedRow < history.entries.count) {
      repoUIController?.selection =
          CommitSelection(repository: repository,
                          commit: history.entries[selectedRow].commit)
    }
  }

  public func tableView(_ tableView: NSTableView,
                        shouldReorderColumn columnIndex: Int,
                        toColumn newColumnIndex: Int) -> Bool
  {
    return columnIndex != 0 && newColumnIndex != 0
  }
}

extension HistoryTableController: XTTableViewDelegate
{
  func tableViewClickedSelectedRow(_ tableView: NSTableView)
  {
    guard let selectionIndex = tableView.selectedRowIndexes.first,
          let controller = repoUIController
    else { return }
    
    let entry = history.entries[selectionIndex]
    let newSelection = CommitSelection(repository: repository,
                                       commit: entry.commit)
    
    if (controller.selection == nil) ||
       (controller.selection?.shaToSelect != newSelection.shaToSelect) ||
       (type(of: controller.selection!) != type(of: newSelection)) {
      controller.selection = newSelection
    }
  }
  
  func menu(forRow row: Int, column: Int) -> NSMenu?
  {
    guard row >= 0
    else { return nil }
    
    return contextMenu
  }
}

extension HistoryTableController: NSTableViewDataSource
{
  public func numberOfRows(in tableView: NSTableView) -> Int
  {
    objc_sync_enter(history)
    defer {
      objc_sync_exit(history)
    }
    return history.entries.count
  }
}
