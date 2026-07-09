import CoreGraphics

struct RemoteFramebufferUpdate: @unchecked Sendable {
    let image: CGImage?
    let imageSize: CGSize
    let dirtyRect: CGRect?

    static let empty = RemoteFramebufferUpdate(image: nil,
                                               imageSize: .zero,
                                               dirtyRect: nil)
}
