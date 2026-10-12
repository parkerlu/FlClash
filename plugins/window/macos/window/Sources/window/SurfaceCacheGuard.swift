import Foundation
import ObjectiveC

// The engine's back buffer cache can hand out a surface of another size, which crashes
// Impeller's raster thread (flutter/flutter#185394); see .agents/flutter-upgrade.md.
enum SurfaceCacheGuard {
    private typealias RemoveSurface = @convention(c) (AnyObject, Selector, CGSize) -> AnyObject?
    private typealias SurfaceSize = @convention(c) (AnyObject, Selector) -> CGSize

    private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true

        let removeSelector = NSSelectorFromString("removeSurfaceForSize:")
        let sizeSelector = NSSelectorFromString("size")
        guard let cacheClass = NSClassFromString("FlutterBackBufferCache"),
              let surfaceClass = NSClassFromString("FlutterSurface"),
              let method = class_getInstanceMethod(cacheClass, removeSelector),
              let sizeMethod = class_getInstanceMethod(surfaceClass, sizeSelector),
              encoding(method) == "@32@0:8{CGSize=dd}16",
              encoding(sizeMethod) == "{CGSize=dd}16@0:8" else {
            NSLog("SurfaceCacheGuard: not installed, FlutterBackBufferCache does not match")
            return
        }

        let original = unsafeBitCast(method_getImplementation(method), to: RemoveSurface.self)
        let surfaceSize = unsafeBitCast(method_getImplementation(sizeMethod), to: SurfaceSize.self)
        let guarded: @convention(block) (AnyObject, CGSize) -> AnyObject? = { cache, size in
            while let surface = original(cache, removeSelector, size) {
                if surfaceSize(surface, sizeSelector) == size {
                    return surface
                }
            }
            return nil
        }
        method_setImplementation(method, imp_implementationWithBlock(guarded))
    }

    private static func encoding(_ method: Method) -> String? {
        method_getTypeEncoding(method).map { String(cString: $0) }
    }
}
