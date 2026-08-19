// Print one line per online display, for scripts/alacritty-font-size.
//
//   <backingScaleFactor>\t<logical PPI>\t<name>
//
// Logical PPI is points per inch: the display's width in points divided by its
// physical width. That is the number that decides how big text actually looks,
// and unlike a resolution it needs no table of known monitors. CoreGraphics
// reports the physical size in millimetres from the display's EDID.
//
// Run with `swift display-info.swift`. Script mode costs about 0.25s against
// 0.01s compiled, which is irrelevant for something that fires when a monitor
// is plugged in, and it saves carrying a build step and a binary.

import AppKit

for screen in NSScreen.screens {
    let number = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    let millimetres = CGDisplayScreenSize(number)
    guard millimetres.width > 0 else { continue }   // no EDID size, nothing to divide by
    let inches = millimetres.width / 25.4
    let ppi = screen.frame.width / inches
    print("\(screen.backingScaleFactor)\t\(String(format: "%.1f", ppi))\t\(screen.localizedName)")
}
