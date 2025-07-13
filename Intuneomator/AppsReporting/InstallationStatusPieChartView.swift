//
//  InstallationStatusPieChartView.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/12/25.
//

import Cocoa

// MARK: - Custom Pie Chart View

/// Custom NSView that draws a pie chart showing installation status distribution
class InstallationStatusPieChartView: NSView {
    
    // MARK: - Properties
    
    private var installedCount: Int = 0
    private var failedCount: Int = 0
    private var pendingCount: Int = 0
    private var notApplicableCount: Int = 0
    private var totalCount: Int = 0
    
    // Color scheme for different installation states
    private let installedColor = NSColor.systemGreen
    private let failedColor = NSColor.systemRed
    private let pendingColor = NSColor.systemOrange
    private let notApplicableColor = NSColor.systemGray
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = .clear
    }
    
    // MARK: - Data Update
    
    /// Updates the pie chart with new installation status data
    /// - Parameters:
    ///   - installed: Number of devices with successful installation
    ///   - failed: Number of devices with failed installation
    ///   - pending: Number of devices with pending installation
    ///   - notApplicable: Number of devices where app is not applicable
    ///   - total: Total number of devices
    func updateData(installed: Int, failed: Int, pending: Int, notApplicable: Int, total: Int) {
        self.installedCount = installed
        self.failedCount = failed
        self.pendingCount = pending
        self.notApplicableCount = notApplicable
        self.totalCount = total
        
        needsDisplay = true
    }
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard totalCount > 0 else {
            drawEmptyState()
            return
        }
        
        // Calculate layout for pie chart on right and legend on left
        let legendWidth: CGFloat = bounds.width * 0.4 // 40% for legend
        let chartWidth = bounds.width - legendWidth
        let chartSize = min(chartWidth, bounds.height) * 0.8 // 80% of available space
        let radius = chartSize / 2
        
        // Position pie chart on the right side
        let chartCenterX = legendWidth + (chartWidth / 2)
        let chartCenterY = bounds.midY
        let center = NSPoint(x: chartCenterX, y: chartCenterY)
        
        // Draw pie chart
        drawPieChart(center: center, radius: radius)
        
        // Draw legend on the left side
        drawLegend(width: legendWidth)
    }
    
    private func drawPieChart(center: NSPoint, radius: CGFloat) {
        var currentAngle: CGFloat = -CGFloat.pi / 2 // Start at top
        
        // Calculate angles for each segment
        let installedAngle = (CGFloat(installedCount) / CGFloat(totalCount)) * 2 * CGFloat.pi
        let failedAngle = (CGFloat(failedCount) / CGFloat(totalCount)) * 2 * CGFloat.pi
        let pendingAngle = (CGFloat(pendingCount) / CGFloat(totalCount)) * 2 * CGFloat.pi
        let notApplicableAngle = (CGFloat(notApplicableCount) / CGFloat(totalCount)) * 2 * CGFloat.pi
        
        // Draw installed segment (green)
        if installedCount > 0 {
            drawSegment(center: center, radius: radius, startAngle: currentAngle, endAngle: currentAngle + installedAngle, color: installedColor)
            currentAngle += installedAngle
        }
        
        // Draw failed segment (red)
        if failedCount > 0 {
            drawSegment(center: center, radius: radius, startAngle: currentAngle, endAngle: currentAngle + failedAngle, color: failedColor)
            currentAngle += failedAngle
        }
        
        // Draw pending segment (orange)
        if pendingCount > 0 {
            drawSegment(center: center, radius: radius, startAngle: currentAngle, endAngle: currentAngle + pendingAngle, color: pendingColor)
            currentAngle += pendingAngle
        }
        
        // Draw not applicable segment (gray)
        if notApplicableCount > 0 {
            drawSegment(center: center, radius: radius, startAngle: currentAngle, endAngle: currentAngle + notApplicableAngle, color: notApplicableColor)
        }
    }
    
    private func drawSegment(center: NSPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, color: NSColor) {
        let path = NSBezierPath()
        path.move(to: center)
        path.appendArc(withCenter: center, radius: radius, startAngle: startAngle * 180 / CGFloat.pi, endAngle: endAngle * 180 / CGFloat.pi)
        path.close()
        
        color.setFill()
        path.fill()
        
        // Draw border
        NSColor.white.setStroke()
        path.lineWidth = 1.0
        path.stroke()
    }
    
    private func drawLegend(width: CGFloat) {
        let legendItemHeight: CGFloat = 22
        let colorBoxSize: CGFloat = 14
        let padding: CGFloat = 15
        
        // Legend items
        let legendItems = [
            (color: installedColor, label: "Installed", count: installedCount),
            (color: failedColor, label: "Failed", count: failedCount),
            (color: pendingColor, label: "Pending", count: pendingCount),
            (color: notApplicableColor, label: "Not Applicable", count: notApplicableCount)
        ]
        
        // Filter to only show items with data
        let visibleItems = legendItems.filter { $0.count > 0 }
        
        // Calculate vertical centering
        let totalLegendHeight = CGFloat(visibleItems.count) * legendItemHeight
        let startY = bounds.midY + (totalLegendHeight / 2) - (legendItemHeight / 2)
        
        for (index, item) in visibleItems.enumerated() {
            let y = startY - (CGFloat(index) * legendItemHeight)
            
            // Draw color box
            let colorRect = NSRect(x: padding, y: y - colorBoxSize/2, width: colorBoxSize, height: colorBoxSize)
            item.color.setFill()
            NSBezierPath(rect: colorRect).fill()
            
            // Add border to color box
            NSColor.tertiaryLabelColor.setStroke()
            let borderPath = NSBezierPath(rect: colorRect)
            borderPath.lineWidth = 0.5
            borderPath.stroke()
            
            // Draw label and count
            let text = "\(item.label): \(item.count)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.labelColor
            ]
            
            let textRect = NSRect(x: padding + colorBoxSize + 8, y: y - 8, width: width - padding * 2 - colorBoxSize - 8, height: 16)
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
    
    private func drawEmptyState() {
        let text = "No data available for pie chart"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        
        let textSize = text.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        text.draw(in: textRect, withAttributes: attributes)
    }
}
