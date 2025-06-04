//
//  ImageSelectorViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/15/25.
//

import Cocoa

/// Protocol for handling image selection events from the image selector
/// Implemented by view controllers that need to receive selected image data
protocol ImageSelectorDelegate: AnyObject {
    /// Called when a user selects an image from the collection view
    /// - Parameters:
    ///   - image: The selected NSImage instance
    ///   - path: The file URL path to the selected image
    func didSelectImage(_ image: NSImage, at path: URL)
}

/// Modal image selector view controller for choosing application icons
/// Displays a collection view of available images with selection capabilities
/// Designed for use in popovers for icon selection workflows
class ImageSelectorViewController: NSViewController {
    
    // MARK: - Data Properties
    
    /// Array of images to display in the collection view
    var images: [NSImage] = []
    
    /// Array of file URLs corresponding to each image for path tracking
    var imagePaths: [URL] = []
    
    /// Delegate to receive image selection notifications
    weak var delegate: ImageSelectorDelegate?
    
    /// Reference to the containing popover for dismissal after selection
    weak var popover: NSPopover?
    
    /// Collection view for displaying images in a grid layout
    private var collectionView: NSCollectionView!
    
    // MARK: - View Lifecycle Methods
    
    /// Programmatically creates the view hierarchy for the image selector
    /// Builds title label, separator, scroll view, and collection view layout
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        
        // Create title label for user instruction
        let titleLabel = NSTextField(frame: NSRect(x: 0, y: view.bounds.height - 30, width: view.bounds.width, height: 25))
        titleLabel.stringValue = "Please choose an icon"
        titleLabel.alignment = .center
        titleLabel.isBezeled = false
        titleLabel.isEditable = false
        titleLabel.drawsBackground = false
        titleLabel.font = NSFont.boldSystemFont(ofSize: 14)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.autoresizingMask = [.width]
        view.addSubview(titleLabel)

        // Add visual separator line below title
        let separator = NSBox(frame: NSRect(x: 0, y: view.bounds.height - 25, width: view.bounds.width, height: 1))
        separator.boxType = .separator
        separator.autoresizingMask = [.width]
        view.addSubview(separator)

        // Create scroll view for collection view container
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height - 25))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true

        // Configure collection view flow layout with grid spacing
        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.itemSize = NSSize(width: 100, height: 120)
        flowLayout.sectionInset = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        flowLayout.minimumInteritemSpacing = 10
        flowLayout.minimumLineSpacing = 10
        
        // Create and configure collection view for image display
        collectionView = NSCollectionView(frame: scrollView.bounds)
        collectionView.collectionViewLayout = flowLayout
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = false
        collectionView.register(ImageItemView.self, forItemWithIdentifier: NSUserInterfaceItemIdentifier("ImageCell"))
        collectionView.dataSource = self
        collectionView.delegate = self
        
        scrollView.documentView = collectionView
        view.addSubview(scrollView)
    }
    
    /// Called after the view controller's view is loaded into memory
    /// Triggers initial collection view data reload to display images
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.reloadData()
    }
}

// MARK: - NSCollectionViewDataSource Extension

/// Extension implementing NSCollectionViewDataSource for populating the image grid
/// Provides image data and configures collection view items with images and tooltips
extension ImageSelectorViewController: NSCollectionViewDataSource {
    
    /// Returns the number of images available for display in the collection view
    /// - Parameters:
    ///   - collectionView: The collection view requesting the count
    ///   - section: The section index (unused, single section)
    /// - Returns: Total number of images in the images array
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }
    
    /// Creates and configures collection view items for image display
    /// Sets up image view, filename display, and tooltips for each item
    /// - Parameters:
    ///   - collectionView: The collection view requesting the item
    ///   - indexPath: The index path of the item to create
    /// - Returns: Configured NSCollectionViewItem with image and metadata
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier("ImageCell"), for: indexPath)
        
        if let imageItem = item as? ImageItemView {
            // Extract filename for display and tooltip
            let path = imagePaths[indexPath.item]
            let description = path.lastPathComponent

            imageItem.imageView?.image = images[indexPath.item]
            imageItem.imageView?.toolTip = "Click to select: \(description)"
            
            imageItem.textField?.stringValue = description
            imageItem.textField?.toolTip = description
        }
        
        return item
    }
}

// MARK: - NSCollectionViewDelegate Extension

/// Extension implementing NSCollectionViewDelegate for handling image selection
/// Manages user interaction and delegates selection events to the parent controller
extension ImageSelectorViewController: NSCollectionViewDelegate {
    
    /// Handles image selection events in the collection view
    /// Notifies delegate of selection and dismisses the popover interface
    /// - Parameters:
    ///   - collectionView: The collection view reporting the selection
    ///   - indexPaths: Set of selected index paths (single selection expected)
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first else { return }
        
        let selectedImage = images[indexPath.item]
        let selectedPath = imagePaths[indexPath.item]
        
        delegate?.didSelectImage(selectedImage, at: selectedPath)
        
        // Dismiss the popover
        popover?.close()
    }
}

// MARK: - Custom Collection View Item

/// Custom NSCollectionViewItem for displaying images with filename labels
/// Provides visual feedback for selection state with background color changes
class ImageItemView: NSCollectionViewItem {
    
    /// Programmatically creates the view hierarchy for each image item
    /// Sets up image view for icon display and text field for filename
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 120))
        
        // Create image view for icon display with proportional scaling
        let imageView = NSImageView(frame: NSRect(x: 10, y: 30, width: 80, height: 80))
        imageView.imageScaling = .scaleProportionallyUpOrDown
        self.imageView = imageView
        view.addSubview(imageView)
        
        // Create text field for filename display below image
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 20))
        textField.isEditable = false
        textField.isBordered = false
        textField.drawsBackground = false
        textField.alignment = .center
        textField.font = .systemFont(ofSize: 10)
        textField.lineBreakMode = .byTruncatingMiddle
        self.textField = textField
        view.addSubview(textField)
    }
    
    /// Updates visual appearance based on selection state
    /// Applies background color highlighting when item is selected
    override var isSelected: Bool {
        didSet {
            view.layer?.backgroundColor = isSelected ?
                NSColor.selectedControlColor.cgColor :
                NSColor.clear.cgColor
        }
    }
}

