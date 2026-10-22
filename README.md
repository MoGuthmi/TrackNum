# TrackNum

**Turn your Mac trackpad into a numeric keypad.**
**حوّل التاتش باد في الماك إلى لوحة أرقام.**

Tap **Control** once — a numpad appears on screen. Slide your finger on the trackpad to aim, lift to type. Tap **Control** again to get your trackpad back.

```
 ┌────┬────┬────┬────┐
 │ 7  │ 8  │ 9  │ ⌫  │
 ├────┼────┼────┼────┤
 │ 4  │ 5  │ 6  │ −  │
 ├────┼────┼────┼────┤
 │ 1  │ 2  │ 3  │ +  │
 ├────┼────┼────┼────┤
 │ 0  │ .  │ ×  │ ↵  │
 └────┴────┴────┴────┘
```

---

## About

Mac keyboards (MacBooks and the compact Magic Keyboard) have no numeric keypad. TrackNum fills that gap with hardware you already have: the trackpad.

The trackpad surface is split into a 4×4 grid. While numpad mode is on, a floating keypad shows on screen, a dot follows your finger, the key under your finger lights up, and the trackpad gives a light haptic tick each time you cross into a new key. Lift your finger and that key is typed.

- Single Swift file, no dependencies, no installer
- Works with any app that accepts keyboard input (Excel, Numbers, Calculator, forms, design tools)
- Sends real **keypad** key codes, so apps that treat the keypad specially still work
- Free and open source (MIT)

Inspired by a reel from [@gojaehyun.go](https://www.instagram.com/gojaehyun.go/) showing the same idea.

---

## Requirements

| | |
|---|---|
| macOS | 13 Ventura or newer (tested target: recent macOS) |
| Trackpad | Built-in MacBook trackpad **or** Magic Trackpad (iMac / Mac mini / Mac Studio) |
| Tools | Xcode Command Line Tools (`xcode-select --install`) |

---

## Install

```bash
git clone https://github.com/MoGuthmi/TrackNum.git
cd TrackNum
swiftc TrackNum.swift -o TrackNum -framework Cocoa
./TrackNum
```

Or run the helper script:

```bash
./build.sh && ./TrackNum
```

### Permissions (first run)

macOS will block input access until you allow it.

1. Open **System Settings → Privacy & Security → Accessibility**.
2. Enable the app you launched TrackNum from (e.g. **Terminal**, iTerm).
3. Open **Privacy & Security → Input Monitoring** and enable the same app.
4. Quit TrackNum (`Ctrl + C` in Terminal) and run it again.

---

## Usage

| Action | Result |
|---|---|
| Tap **Control** alone (press and release) | Numpad mode **on** — keypad appears |
| Touch the trackpad | Dot shows your finger; key under it highlights |
| Slide | Highlight moves; haptic tick on each new key |
| Lift finger | Highlighted key is typed |
| Tap **Control** again | Numpad mode **off** — normal trackpad |

While numpad mode is on, the cursor is frozen and clicks/scrolling are blocked so you don't click things by accident.

Control used in a shortcut (e.g. `Ctrl + C`) does **not** toggle the numpad — only a clean Control tap does.

### Tips

- Look at the on-screen keypad, not the trackpad. Aim with the highlight, then lift.
- Rest your finger, slide to the key, lift. Don't tap blindly.
- The right column (⌫ − + ↵) is shaded darker so you can find it fast.

---

## Run at login (optional)

1. Move the built `TrackNum` binary somewhere permanent, e.g. `~/Applications/TrackNum`.
2. **System Settings → General → Login Items → +** and add it.
3. Grant Accessibility and Input Monitoring to the binary itself when prompted.

---

## How it works

| Part | What it does |
|---|---|
| `MultitouchSupport.framework` | Apple's private framework; gives raw finger positions (0–1 on each axis) from the trackpad |
| `CGEventTap` | Watches for a clean Control tap; blocks clicks and scrolling while numpad mode is on |
| `CGEvent` keyboard events | Posts keypad key codes (with the numeric-pad flag) to the active app |
| `NSPanel` + `NSVisualEffectView` | Floating, click-through, blurred keypad overlay on all Spaces |
| `NSHapticFeedbackManager` | Haptic tick when your finger enters a new key |

Finger position maps to a key:

```
column = floor(x × 4)
row    = floor((1 − y) × 4)
```

---

## Customize

Edit the `grid` array at the top of `TrackNum.swift` to change keys or layout. Each key is a label plus a macOS virtual key code:

```swift
Key(label: "7", code: 0x59)
```

Common keypad codes: `0x52`–`0x5C` (0–9), `0x41` (.), `0x45` (+), `0x4E` (−), `0x43` (×), `0x4B` (÷), `0x4C` (Enter), `0x51` (=).

Rebuild after editing.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `Event tap failed` | Grant Accessibility **and** Input Monitoring, then restart TrackNum |
| Nothing types | Check permissions; make sure the target app is focused |
| Keypad doesn't appear | Tap Control alone, without other keys, and release |
| `MultitouchSupport unavailable` | Your macOS version changed the private framework; open an issue |
| No haptic feedback | Only Force Touch trackpads support haptics |
| Cursor stuck | Tap Control to exit numpad mode, or quit TrackNum |

---

## Limitations

- Uses a **private** Apple framework. It works today, but a future macOS update may break it. Not eligible for the Mac App Store.
- Not signed or notarized. Building from source avoids Gatekeeper warnings.
- Typing without looking is harder than on a physical keypad — this is a convenience tool, not a replacement for heavy data entry.

---

## العربي — شرح سريع

**الفكرة:** لوحات مفاتيح الماك بدون أرقام جانبية. TrackNum يحوّل التاتش باد إلى لوحة أرقام 4×4.

**التثبيت:**
```bash
git clone https://github.com/MoGuthmi/TrackNum.git
cd TrackNum
swiftc TrackNum.swift -o TrackNum -framework Cocoa
./TrackNum
```

**الصلاحيات:** الإعدادات ← الخصوصية والأمان ← فعّل Accessibility و Input Monitoring للتيرمنال، ثم أعد التشغيل.

**الاستخدام:**
- اضغط Control وحده ← تظهر لوحة الأرقام.
- المس التاتش باد ← نقطة تتبع إصبعك.
- حرّك حتى يتلوّن الرقم ← ارفع إصبعك فيُكتب.
- اضغط Control مرة ثانية ← يرجع التاتش باد طبيعي.

**ملاحظة:** يعتمد على framework خاص من Apple، وقد يتأثر بتحديثات macOS.

---

## License

MIT © 2026 Mohamed Alaa Eldin — see [LICENSE](LICENSE).
