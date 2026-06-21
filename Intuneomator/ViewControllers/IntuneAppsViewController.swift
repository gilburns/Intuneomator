//
//  IntuneAppsViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 6/20/26.
//

import Cocoa

/// Sheet view controller displaying all Intune deployments matching a label's tracking ID.
/// Shows app name, version, creation date, and a link to each entry in the Intune portal.
class IntuneAppsViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

    // MARK: - Data

    /// Apps returned by findAppsByTrackingID — each dict has displayName, primaryBundleVersion,
    /// createdDateTime, and id keys.
    var apps: [[String: Any]] = []

    /// Display name shown in the sheet title (e.g. "Wireshark").
    var appDisplayName: String = ""

    // MARK: - Private subviews

    private var tableView: NSTableView!
    private var titleLabel: NSTextField!

    // MARK: - Date formatters

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    // MARK: - View lifecycle

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 380))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        apps.sort { ($0["createdDateTime"] as? String ?? "") < ($1["createdDateTime"] as? String ?? "") }
        buildUI()
        titleLabel.stringValue = apps.isEmpty
            ? "No Intune deployments found for \(appDisplayName)"
            : "Intune deployments for \(appDisplayName)"
        tableView.delegate = self
        tableView.dataSource = self
        tableView.reloadData()
    }

    // MARK: - UI construction

    private func buildUI() {
        // Title
        titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = .boldSystemFont(ofSize: 13)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // Table columns
        tableView = NSTableView()
        tableView.allowsColumnReordering = false
        tableView.allowsColumnResizing = true
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        tableView.selectionHighlightStyle = .none

        let nameCol = NSTableColumn(identifier: .init("AppNameColumn"))
        nameCol.title = "Application"
        nameCol.width = 220
        nameCol.minWidth = 120
        nameCol.maxWidth = 300

        let verCol = NSTableColumn(identifier: .init("VersionColumn"))
        verCol.title = "Version"
        verCol.width = 90
        verCol.minWidth = 60
        verCol.maxWidth = 120

        let dateCol = NSTableColumn(identifier: .init("CreatedColumn"))
        dateCol.title = "Created"
        dateCol.width = 165
        dateCol.minWidth = 120
        dateCol.maxWidth = 180

        let assignedCol = NSTableColumn(identifier: .init("AssignedColumn"))
        assignedCol.title = "Assigned"
        assignedCol.width = 55
        assignedCol.minWidth = 55
        assignedCol.maxWidth = 55

        let linkCol = NSTableColumn(identifier: .init("IntuneColumn"))
        linkCol.title = "Intune"
        linkCol.width = 50
        linkCol.minWidth = 50
        linkCol.maxWidth = 50

        for col in [nameCol, verCol, dateCol, assignedCol, linkCol] {
            tableView.addTableColumn(col)
        }

        // Scroll view wrapping the table
        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        // Close button
        let closeButton = NSButton(title: "Close", target: self, action: #selector(dismissSheet(_:)))
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\u{1b}"
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)

        // Layout
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 700),
            view.heightAnchor.constraint(equalToConstant: 380),

            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: closeButton.topAnchor, constant: -12),

            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 89),
        ])
    }

    // MARK: - Actions

    @objc private func dismissSheet(_ sender: Any) {
        dismiss(self)
    }

    @objc private func openInIntune(_ sender: NSButton) {
        let row = tableView.row(for: sender)
        guard row >= 0, let id = apps[row]["id"] as? String else { return }
        let urlString = "https://intune.microsoft.com/#view/Microsoft_Intune_Apps/SettingsMenu/~/0/appId/\(id)"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Date formatting

    private func formattedDate(_ iso8601: String) -> String {
        guard !iso8601.isEmpty,
              let date = Self.isoFormatter.date(from: iso8601) else { return iso8601 }
        return Self.displayFormatter.string(from: date)
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int { apps.count }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let app = apps[row]

        switch tableColumn?.identifier.rawValue {

        case "AppNameColumn":
            return labelCell(app["displayName"] as? String ?? "")

        case "VersionColumn":
            return labelCell(app["primaryBundleVersion"] as? String ?? "")

        case "CreatedColumn":
            let raw = app["createdDateTime"] as? String ?? ""
            return labelCell(formattedDate(raw))

        case "AssignedColumn":
            let assigned = app["isAssigned"] as? Bool ?? false
            let cell = labelCell(assigned ? "✓" : "—")
            cell.textField?.alignment = .center
            cell.textField?.textColor = assigned ? .systemGreen : .secondaryLabelColor
            return cell

        case "IntuneColumn":
            let cell = NSTableCellView()  // TAMIC stays true — table sets the frame directly

            let button = NSButton(frame: .zero)
            button.isBordered = false
            button.bezelStyle = .inline
            button.target = self
            button.action = #selector(openInIntune(_:))
            button.toolTip = "Open in Intune portal"
            button.translatesAutoresizingMaskIntoConstraints = false

            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            button.image = NSImage(systemSymbolName: "arrow.up.forward.app", accessibilityDescription: "Open in Intune")?
                .withSymbolConfiguration(config)
            button.contentTintColor = .linkColor

            cell.addSubview(button)
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 20),
                button.heightAnchor.constraint(equalToConstant: 20),
                button.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
                button.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
            return cell

        default:
            return nil
        }
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat { 24 }

    // MARK: - Helpers

    private func labelCell(_ text: String) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.translatesAutoresizingMaskIntoConstraints = false

        let tf = NSTextField(labelWithString: text)
        tf.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(tf)
        cell.textField = tf

        NSLayoutConstraint.activate([
            tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }
}
