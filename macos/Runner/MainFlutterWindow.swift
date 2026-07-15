import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Make the window itself transparent
    self.isOpaque = false
    self.backgroundColor = NSColor.clear
    self.hasShadow = false
    self.ignoresMouseEvents = false

    // Hide the title bar ourselves natively — avoids calling window_manager's
    // setTitleBarStyle(), which crashes on this Flutter/macOS combo.
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    self.standardWindowButton(.closeButton)?.isHidden = true
    self.standardWindowButton(.miniaturizeButton)?.isHidden = true
    self.standardWindowButton(.zoomButton)?.isHidden = true

    // We drag the window ourselves via windowManager.startDragging() in Dart,
    // so disable macOS's automatic "drag by background" behavior.
    self.isMovableByWindowBackground = false

    // Make the Flutter view's background transparent too
    flutterViewController.backgroundColor = NSColor.clear

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  // Borderless windows can't become key/main by default, which blocks clicks.
  override var canBecomeKey: Bool {
    return true
  }

  override var canBecomeMain: Bool {
    return true
  }
}