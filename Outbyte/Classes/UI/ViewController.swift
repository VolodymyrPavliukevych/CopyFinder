//
//  ViewController.swift
//  Outbyte
//
//  Created by Volodymyr Pavliukevych on 12/15/18.
//  Copyright © 2018 Volodymyr Pavliukevych. All rights reserved.
//

import Cocoa

extension SearchLevel {
    var progressStep: Double {
        return 100.0
    }
}

class ViewController: NSViewController {
    var fileProcessor: FileProcessor?
    @IBOutlet var startButton: NSButton!
    @IBOutlet var tableView: NSTableView!
    @IBOutlet var stopButton: NSButton!
    @IBOutlet var descriptionLabel: NSTextField!
    @IBOutlet var progressIndicator: NSProgressIndicator!
    
    var internalProgressHandler: ProgressHandler?
    let sizeFormatter = ByteCountFormatter()
    var items = [Metadata]()
    var sortOrder = Metadata.FileOrder.Name
    var sortAscending = true
    
    @IBAction func start(_ sender: NSButton) {
        startButton.isEnabled = false
        stopButton.isEnabled = true
        items.removeAll()
        guard let processor = fileProcessor else { return }
        processor.launch(progress: progressHandler(), callback: completeHandler())
        self.descriptionLabel.stringValue = "Please wait, indexing home folder ..."
        self.progressIndicator.isIndeterminate = true
        self.progressIndicator.startAnimation(nil)
    }

    @IBAction func stop(_ sender: NSButton) {
        startButton.isEnabled = true
        stopButton.isEnabled = false
        guard let processor = fileProcessor else { return }
        processor.abort { (_) in
            
        }
        progressIndicator.doubleValue = 0.0
    }

    override func awakeAfter(using aDecoder: NSCoder) -> Any? {
        do {
            fileProcessor = try Processor()
        } catch {
            handleError(title: "Error heppend", text: "Can't search, folder not found.")
        }
        return super.awakeAfter(using: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        guard fileProcessor != nil else { return }
        startButton.isEnabled = true
        progressIndicator.minValue = 0.0
        progressIndicator.maxValue = SearchLevel.allCases.map { $0.progressStep }.reduce(0, +)
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.target = self
        tableView.doubleAction = #selector(tableViewDoubleClick(_:))
        
        let descriptorName = NSSortDescriptor(key: Metadata.FileOrder.Name.rawValue, ascending: true)
        let descriptorPath = NSSortDescriptor(key: Metadata.FileOrder.Path.rawValue, ascending: true)
        let descriptorSize = NSSortDescriptor(key: Metadata.FileOrder.Size.rawValue, ascending: true)
        
        tableView.tableColumns[0].sortDescriptorPrototype = descriptorName
        tableView.tableColumns[1].sortDescriptorPrototype = descriptorPath
        tableView.tableColumns[2].sortDescriptorPrototype = descriptorSize
    }

    @objc func tableViewDoubleClick(_ sender:AnyObject) {
        guard tableView.selectedRow >= 0 else {
                return
        }
        let item = items[tableView.selectedRow]
        NSWorkspace.shared.openFile(item.path)
    }
    
    @discardableResult func handleError(title: String, text: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        return alert.runModal() == .alertFirstButtonReturn
    }
    
    func progressHandler() -> ProgressHandler {
        let handler = { [weak self] (value: Double, found: [FileDescriptor], level: SearchLevel) in
            guard let wSelf = self else { return }
            wSelf.updateProgress(value, for: level)
            guard level != .index else { return }
            DispatchQueue.main.async {
                wSelf.items.append(contentsOf: found.map { Metadata(fileDescriptor: $0)})
                wSelf.reloadFileList()
            }
        }
        self.internalProgressHandler = handler
        return handler
    }
    
    func completeHandler() -> ResultCompletion<[[FileDescriptor]]> {
        let handler = { [weak self] (result: Result<[[FileDescriptor]]>)in
            guard let wSelf = self else { return }
            result.onPositive { _ in
                wSelf.updateProgress(SearchLevel.full.progressStep, for: .full)
                DispatchQueue.main.async {
                    wSelf.descriptionLabel.stringValue = "Done!"
                    wSelf.startButton.isEnabled = true
                    wSelf.stopButton.isEnabled = false
                    wSelf.reloadFileList()
                }
            }
        }
        return handler
    }
    
    func updateProgress(_ value: Double, for level: SearchLevel) {
        DispatchQueue.main.async {
            var shift = 0.0
            switch level {
            case .index: shift = 0.0
            case .height: shift = SearchLevel.index.progressStep
            case .full: shift = SearchLevel.index.progressStep + SearchLevel.height.progressStep
            }
            if level != .index {
                if self.progressIndicator.isIndeterminate {
                    self.descriptionLabel.stringValue = "Searching copies ..."
                    self.progressIndicator.stopAnimation(nil)
                    self.progressIndicator.isIndeterminate = false
                }
                self.progressIndicator.doubleValue = value + shift
            }
        }
    }
    
    func reloadFileList() {
        items = items.contentsOrderedBy(sortOrder, ascending: sortAscending)
        tableView.reloadData()
    }
}



extension ViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let sortDescriptor = tableView.sortDescriptors.first else {
            return
        }
        
        if let order = Metadata.FileOrder(rawValue: sortDescriptor.key!) {
            sortOrder = order
            sortAscending = sortDescriptor.ascending
            reloadFileList()
        }
    }
}

extension ViewController: NSTableViewDelegate {
    
    fileprivate enum CellIdentifiers {
        static let NameCell = "NameCellID"
        static let DateCell = "PathCellID"
        static let SizeCell = "SizeCellID"
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        var image: NSImage?
        var text: String = ""
        var cellIdentifier: String = ""
        
        let item = items[row]
        
        if tableColumn == tableView.tableColumns[0] {
            image = item.icon
            text = item.name
            cellIdentifier = CellIdentifiers.NameCell
        } else if tableColumn == tableView.tableColumns[1] {
            text = item.path
            cellIdentifier = CellIdentifiers.DateCell
        } else if tableColumn == tableView.tableColumns[2] {
            text = sizeFormatter.string(fromByteCount: Int64(item.size))
            cellIdentifier = CellIdentifiers.SizeCell
        }
        let id = NSUserInterfaceItemIdentifier(rawValue: cellIdentifier)
        if let cell = tableView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            cell.imageView?.image = image ?? nil
            return cell
        }
        return nil
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) { }
    
}
