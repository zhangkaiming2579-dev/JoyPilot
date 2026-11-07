import AppKit
import Foundation
let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
for size in [16,32,128,256,512] {
    for scale in [1,2] {
        let pixels = size*scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels)/512, y: CGFloat(pixels)/512)
        let background = NSBezierPath(roundedRect: NSRect(x: 25,y:25,width:462,height:462), xRadius:110,yRadius:110)
        NSGradient(starting: NSColor(red:0.47,green:0.55,blue:1,alpha:1), ending:NSColor(red:0.30,green:0.36,blue:0.88,alpha:1))!.draw(in: background, angle: -80)
        NSColor.white.setFill()
        NSBezierPath(roundedRect: NSRect(x:158,y:91,width:195,height:334),xRadius:65,yRadius:65).fill()
        NSColor(red:0.35,green:0.40,blue:0.86,alpha:1).setFill()
        for (x,y,r) in [(255.0,345.0,16.0),(219,309,16),(291,309,16),(255,273,16),(255,199,36),(255,131,12)] {
            NSBezierPath(ovalIn: NSRect(x:x-r,y:y-r,width:2*r,height:2*r)).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        let filename="icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent(filename))
    }
}
