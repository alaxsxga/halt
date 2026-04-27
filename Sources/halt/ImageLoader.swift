import AppKit

func loadImage(path: String, bookmark: Data?) -> NSImage? {
    if let bookmark {
        var isStale = false
        if let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) {
            url.startAccessingSecurityScopedResource()
            let image = NSImage(contentsOf: url)
            url.stopAccessingSecurityScopedResource()
            if image != nil { return image }
        }
    }
    return NSImage(contentsOfFile: path)
}
