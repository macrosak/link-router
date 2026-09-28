import AppKit
import SwiftUI
import LinkRouterCore

/// App icons and Chromium profile pictures, cached for the process lifetime
/// so the picker renders without touching disk.
@MainActor
final class IconCache {
    static let shared = IconCache()
    private var apps: [String: NSImage] = [:]
    private var pictures: [String: NSImage?] = [:]

    func appIcon(_ path: String) -> NSImage {
        if let hit = apps[path] { return hit }
        let img = NSWorkspace.shared.icon(forFile: path)
        apps[path] = img
        return img
    }

    func profilePicture(_ t: BrowserTarget) -> NSImage? {
        guard let dir = t.profileDirectory else { return nil }
        if let hit = pictures[t.id] { return hit }
        let img = ChromiumProfiles.pictureURL(bundleID: t.bundleID, profileDirectory: dir).flatMap { NSImage(contentsOf: $0) }
        pictures[t.id] = img
        return img
    }

    /// Warm the cache ahead of the first link so the picker opens instantly.
    func preload(_ targets: [BrowserTarget]) {
        for t in targets { _ = appIcon(t.appPath); _ = profilePicture(t) }
    }
}

/// Browser icon; for a profile, its avatar (or an initial) with the browser
/// icon as a badge.
struct TargetIconView: View {
    let target: BrowserTarget
    var size: CGFloat = 28

    var body: some View {
        if target.profileDirectory == nil && !target.incognito {
            appIcon
        } else {
            avatar
                .frame(width: size, height: size)
                .overlay(alignment: .bottomTrailing) {
                    Image(nsImage: IconCache.shared.appIcon(target.appPath))
                        .resizable()
                        .frame(width: size * 0.55, height: size * 0.55)
                        .offset(x: size * 0.12, y: size * 0.1)
                }
        }
    }

    private var appIcon: some View {
        Image(nsImage: IconCache.shared.appIcon(target.appPath))
            .resizable()
            .frame(width: size, height: size)
    }

    @ViewBuilder
    private var avatar: some View {
        if target.incognito {
            Circle()
                .fill(Color(hex: 0x3C4043))
                .overlay(
                    Image(systemName: "eyeglasses")
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(.white)
                )
        } else if let pic = IconCache.shared.profilePicture(target) {
            Image(nsImage: pic)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Self.color(for: target.id))
                .overlay(
                    Text(String(target.title.prefix(1)).uppercased())
                        .font(.system(size: size * 0.46, weight: .semibold))
                        .foregroundStyle(.white)
                )
        }
    }

    /// Stable per-profile color for the initial avatar.
    static func color(for id: String) -> Color {
        let palette: [UInt32] = [0x0A84FF, 0x30A46C, 0xE5484D, 0xF76B15, 0x8E4EC6, 0x12A594, 0xD6409F, 0x3E63DD]
        let h = id.unicodeScalars.reduce(UInt32(5381)) { ($0 &* 33) &+ $1.value }
        return Color(hex: palette[Int(h % UInt32(palette.count))])
    }
}
