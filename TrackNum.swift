// TrackNum — Trackpad as Numpad (macOS)
// Toggle: tap Control alone (press + release).
// Build: swiftc TrackNum.swift -o TrackNum -framework Cocoa
// Run:   ./TrackNum   (grant Accessibility + Input Monitoring)

import Cocoa
import ApplicationServices

// MARK: - Private MultitouchSupport
struct MTPoint { var x: Float; var y: Float }
struct MTReadout { var pos: MTPoint; var vel: MTPoint }
struct MTFinger {
    var frame: Int32
    var timestamp: Double
    var identifier: Int32
    var state: Int32
    var fingerId: Int32
    var handId: Int32
    var normalized: MTReadout
    var size: Float
    var zero1: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var mm: MTReadout
    var zero2: (Int32, Int32)
    var unk2: Float
}

typealias MTContactCB = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32
typealias MTCreateListFn = @convention(c) () -> Unmanaged<CFMutableArray>
typealias MTRegisterFn = @convention(c) (UnsafeMutableRawPointer, MTContactCB) -> Void
typealias MTStartFn = @convention(c) (UnsafeMutableRawPointer, Int32) -> Void

// MARK: - Layout (keypad keycodes)
struct Key { let label: String; let code: CGKeyCode }
let grid: [[Key]] = [
    [Key(label: "7", code: 0x59), Key(label: "8", code: 0x5B), Key(label: "9", code: 0x5C), Key(label: "⌫", code: 0x33)],
    [Key(label: "4", code: 0x56), Key(label: "5", code: 0x57), Key(label: "6", code: 0x58), Key(label: "−", code: 0x4E)],
    [Key(label: "1", code: 0x53), Key(label: "2", code: 0x54), Key(label: "3", code: 0x55), Key(label: "+", code: 0x45)],
    [Key(label: "0", code: 0x52), Key(label: ".", code: 0x41), Key(label: "×", code: 0x43), Key(label: "↵", code: 0x4C)],
]

// MARK: - State
var active = false
var ctrlDown = false
var ctrlClean = false
var starts: [Int32: (x: Float, y: Float, t: Double)] = [:]
var devices: CFMutableArray?
var eventTap: CFMachPort?

// MARK: - HUD
final class PadView: NSView {
    var hit: (Int, Int)?
    var hover: (Int, Int)?
    var dot: CGPoint?   // normalized 0...1, y up
    override func draw(_ dirtyRect: NSRect) {
        let inset: CGFloat = 14, gap: CGFloat = 8
        let w = (bounds.width - inset * 2 - gap * 3) / 4
        let h = (bounds.height - inset * 2 - gap * 3) / 4
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 26, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        for r in 0..<4 {
            for c in 0..<4 {
                let rect = NSRect(x: inset + CGFloat(c) * (w + gap),
                                  y: bounds.height - inset - CGFloat(r + 1) * h - CGFloat(r) * gap,
                                  width: w, height: h)
                let on = hit.map { $0.0 == r && $0.1 == c } ?? false
                let hov = hover.map { $0.0 == r && $0.1 == c } ?? false
                (on ? NSColor.controlAccentColor
                    : hov ? NSColor.controlAccentColor.withAlphaComponent(0.45)
                    : NSColor.white.withAlphaComponent(c == 3 ? 0.18 : 0.10)).setFill()
                NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12).fill()
                let label = grid[r][c].label as NSString
                let sz = label.size(withAttributes: attrs)
                label.draw(at: NSPoint(x: rect.midX - sz.width / 2, y: rect.midY - sz.height / 2),
                           withAttributes: attrs)
            }
        }
        if let d = dot {
            let p = NSPoint(x: inset + d.x * (bounds.width - inset * 2),
                            y: inset + d.y * (bounds.height - inset * 2))
            NSColor.white.setFill()
            NSBezierPath(ovalIn: NSRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14)).fill()
        }
    }
}

final class HUD {
    let panel: NSPanel
    let pad = PadView()

    init() {
        let size = NSSize(width: 380, height: 380)
        panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let blur = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        blur.material = .hudWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 22
        blur.layer?.masksToBounds = true
        pad.frame = blur.bounds
        pad.autoresizingMask = [.width, .height]
        blur.addSubview(pad)
        panel.contentView = blur
    }

    func show() {
        if let s = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: s.midX - panel.frame.width / 2, y: s.minY + 40))
        }
        panel.orderFrontRegardless()
    }

    func hide() { panel.orderOut(nil) }

    func aim(_ cell: (Int, Int)?, _ p: CGPoint?) {
        pad.hover = cell
        pad.dot = p
        pad.needsDisplay = true
    }

    func flash(_ r: Int, _ c: Int) {
        pad.hit = (r, c)
        pad.needsDisplay = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.pad.hit = nil
            self?.pad.needsDisplay = true
        }
    }
}

let hud = HUD()

// MARK: - Logic
func press(_ code: CGKeyCode) {
    let src = CGEventSource(stateID: .hidSystemState)
    for down in [true, false] {
        let e = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: down)
        e?.flags = (code == 0x33) ? [] : .maskNumericPad
        e?.post(tap: .cghidEventTap)
    }
}

func cell(_ x: Float, _ y: Float) -> (Int, Int) {
    (min(3, max(0, Int((1 - y) * 4))), min(3, max(0, Int(x * 4))))
}

func tick() {
    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
}

var lastCell: (Int, Int)?

// Slide finger to aim (highlight + haptic), lift to type.
func handle(_ fingers: [MTFinger], _ ts: Double) {
    guard active else { starts.removeAll(); return }
    var live = Set<Int32>()
    var aimFinger: MTFinger?
    for f in fingers where f.state == 4 || f.state == 5 {
        live.insert(f.identifier)
        starts[f.identifier] = (f.normalized.pos.x, f.normalized.pos.y, ts)
        aimFinger = f
    }
    for (id, s) in starts where !live.contains(id) {
        starts[id] = nil
        let (r, c) = cell(s.x, s.y)
        press(grid[r][c].code)
        hud.flash(r, c)
        tick()
    }
    if let f = aimFinger {
        let rc = cell(f.normalized.pos.x, f.normalized.pos.y)
        if lastCell == nil || lastCell! != rc { tick() }
        lastCell = rc
        hud.aim(rc, CGPoint(x: CGFloat(f.normalized.pos.x), y: CGFloat(f.normalized.pos.y)))
    } else if lastCell != nil {
        lastCell = nil
        hud.aim(nil, nil)
    }
}

func toggle() {
    active.toggle()
    starts.removeAll()
    CGAssociateMouseAndMouseCursorPosition(active ? 0 : 1)
    if active { hud.show() } else { hud.hide() }
}

let contactCB: MTContactCB = { _, data, n, ts, _ in
    var fingers: [MTFinger] = []
    if let data = data, n > 0 {
        let stride = MemoryLayout<MTFinger>.stride
        for i in 0..<Int(n) {
            fingers.append(data.load(fromByteOffset: i * stride, as: MTFinger.self))
        }
    }
    DispatchQueue.main.async { handle(fingers, ts) }
    return 0
}

let tapCB: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let t = eventTap { CGEvent.tapEnable(tap: t, enable: true) }
        return Unmanaged.passUnretained(event)
    }
    switch type {
    case .flagsChanged:
        let kc = event.getIntegerValueField(.keyboardEventKeycode)
        if kc == 59 || kc == 62 {
            if event.flags.contains(.maskControl) {
                ctrlDown = true; ctrlClean = true
            } else {
                if ctrlDown && ctrlClean { DispatchQueue.main.async { toggle() } }
                ctrlDown = false
            }
        } else {
            ctrlClean = false
        }
    case .keyDown:
        if ctrlDown { ctrlClean = false }
    case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
         .otherMouseDown, .otherMouseUp, .leftMouseDragged, .scrollWheel:
        if ctrlDown { ctrlClean = false }
        if active { return nil } // swallow clicks/scroll in numpad mode
    default:
        break
    }
    return Unmanaged.passUnretained(event)
}

// MARK: - Boot
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let axOpts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
if !AXIsProcessTrustedWithOptions(axOpts) {
    print("Grant Accessibility, then rerun.")
}

let mtPath = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
guard let mt = dlopen(mtPath, RTLD_NOW),
      let fList = dlsym(mt, "MTDeviceCreateList"),
      let fReg = dlsym(mt, "MTRegisterContactFrameCallback"),
      let fStart = dlsym(mt, "MTDeviceStart") else {
    fatalError("MultitouchSupport unavailable")
}
let createList = unsafeBitCast(fList, to: MTCreateListFn.self)
let register = unsafeBitCast(fReg, to: MTRegisterFn.self)
let start = unsafeBitCast(fStart, to: MTStartFn.self)

devices = createList().takeRetainedValue()
for d in devices! as NSArray {
    let p = Unmanaged.passUnretained(d as AnyObject).toOpaque()
    register(p, contactCB)
    start(p, 0)
}

let types: [CGEventType] = [.flagsChanged, .keyDown, .leftMouseDown, .leftMouseUp,
                            .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
                            .leftMouseDragged, .scrollWheel]
let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                             options: .defaultTap, eventsOfInterest: mask,
                             callback: tapCB, userInfo: nil)
if let t = eventTap {
    let src = CFMachPortCreateRunLoopSource(nil, t, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
    CGEvent.tapEnable(tap: t, enable: true)
} else {
    print("Event tap failed: grant Accessibility + Input Monitoring.")
}

print("TrackNum running. Tap Control to toggle.")
app.run()
