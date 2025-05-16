//
//  ImageSelectorViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/15/25.
//

import Cocoa

protocol ImageSelectorDelegate: AnyObject {
    func didSelectImage(_ image: NSImage, at path: URL)
}

class ImageSelectorViewController: NSViewController {
    var images: [NSImage] = []
    var imagePaths: [URL] = []
    weak var delegate: ImageSelectorDelegate?
    weak var popover: NSPopover?
    

    private var collectionView: NSCollectionView!
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        
        // Create title label
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

        // Add a separator line
        let separator = NSBox(frame: NSRect(x: 0, y: view.bounds.height - 25, width: view.bounds.width, height: 1))
        separator.boxType = .separator
        separator.autoresizingMask = [.width]
        view.addSubview(separator)

        // Create a scroll view - adjusted to account for the title area
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height - 25))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true

        // Create the collection view
        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.itemSize = NSSize(width: 100, height: 120)
        flowLayout.sectionInset = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        flowLayout.minimumInteritemSpacing = 10
        flowLayout.minimumLineSpacing = 10
        
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.reloadData()
    }
}

extension ImageSelectorViewController: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier("ImageCell"), for: indexPath)
        
        if let imageItem = item as? ImageItemView {
            // Get a readable description of the image path
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

extension ImageSelectorViewController: NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first else { return }
        
        let selectedImage = images[indexPath.item]
        let selectedPath = imagePaths[indexPath.item]
        
        delegate?.didSelectImage(selectedImage, at: selectedPath)
        
        // Dismiss the popover
        popover?.close()
    }
}

// Custom NSCollectionViewItem for displaying images
class ImageItemView: NSCollectionViewItem {
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 120))
        
        // Create image view
        let imageView = NSImageView(frame: NSRect(x: 10, y: 30, width: 80, height: 80))
        imageView.imageScaling = .scaleProportionallyUpOrDown
        self.imageView = imageView
        view.addSubview(imageView)
        
        // Create text label
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 20))
        textField.isEditable = false
        textField.isBordered = false
        textField.drawsBackground = false
        textField.alignment = .center
        textField.lineBreakMode = .byTruncatingTail
        self.textField = textField
        view.addSubview(textField)
    }
    
    override var isSelected: Bool {
        didSet {
            view.layer?.backgroundColor = isSelected ?
                NSColor.selectedControlColor.cgColor :
                NSColor.clear.cgColor
        }
    }
}

