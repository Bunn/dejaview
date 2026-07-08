import CoreGraphics

struct RemoteFramebufferUpdate {
    let image: CGImage?
    let dirtyRect: CGRect?

    static let empty = RemoteFramebufferUpdate(image: nil, dirtyRect: nil)
}
