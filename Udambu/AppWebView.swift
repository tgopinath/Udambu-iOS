import SwiftUI
import WebKit
import SafariServices
import QuickLook
import ARKit

/// Udambu's web app, bundled inside the iPhone app (the "web" folder), in a WKWebView set up to feel native:
/// edge swipe to go back, sound without a tap first, haptics from the page,
/// and outside links in Safari's in-app viewer. Only the real 3D models need the internet.
struct AppWebView: UIViewRepresentable {
    static let webFolder = Bundle.main.url(forResource: "web", withExtension: nil)!
    static let home: URL = {
        let index = webFolder.appendingPathComponent("index.html")
        #if DEBUG
        // Debug builds only: `simctl launch <device> com.gopinath.Udambu -KolamStartURL "#/parts"` opens another route (for screenshots).
        if let s = UserDefaults.standard.string(forKey: "KolamStartURL"), s.hasPrefix("#"),
           let u = URL(string: index.absoluteString + s) { return u }
        #endif
        return index
    }()

    let url: URL
    @Binding var loading: Bool
    @Binding var failed: Bool
    let reloadToken: Int

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        // "Udambu-iOS" + "Kolam-iOS" + window.KolamShell let the page's Kolam iOS kit turn on the Apple HIG look.
        config.applicationNameForUserAgent = "Udambu-iOS/1.0 Kolam-iOS/1.0 Mobile/15E148"
        config.userContentController.addUserScript(WKUserScript(source: Self.shellScript(), injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController.add(context.coordinator, name: "haptic")
        config.userContentController.add(context.coordinator, name: "ar")       // "View in your room" → AR Quick Look

        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true      // swipe from the left edge to go back
        web.allowsLinkPreview = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.isOpaque = false
        web.backgroundColor = .systemBackground
        #if DEBUG
        web.isInspectable = true                             // Safari ▸ Develop, for debugging
        #endif
        web.loadFileURL(url, allowingReadAccessTo: AppWebView.webFolder)
        context.coordinator.lastToken = reloadToken
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        if context.coordinator.lastToken != reloadToken {    // "Try Again" after being offline
            context.coordinator.lastToken = reloadToken
            web.loadFileURL(url, allowingReadAccessTo: AppWebView.webFolder)
        }
    }

    /// window.KolamShell tells the Kolam iOS kit it runs in this shell, and passes accessibility settings
    /// that have no CSS media query in WebKit yet.
    static func shellScript() -> String {
        let reduceTransparency = UIAccessibility.isReduceTransparencyEnabled ? "true" : "false"
        let boldText = UIAccessibility.isBoldTextEnabled ? "true" : "false"
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return """
        window.KolamShell = { platform: 'ios', app: 'Udambu', version: '\(version)', nativeBack: true,
          reduceTransparency: \(reduceTransparency), boldText: \(boldText) };
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, QLPreviewControllerDataSource {
        let parent: AppWebView
        var lastToken = 0
        var ranDebugJS = false
        init(_ parent: AppWebView) { self.parent = parent }

        // MARK: Loading state
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.loading = false
            #if DEBUG
            // simctl launch … -js "location.hash='#/part/heart'" runs a line of JavaScript, for testing
            if let js = UserDefaults.standard.string(forKey: "js"), !ranDebugJS { ranDebugJS = true; webView.evaluateJavaScript(js) }
            #endif
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.failed = true
        }

        // MARK: Links: the app stays in the web view; everything else opens in Safari's viewer
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url else { return decisionHandler(.allow) }
            let host = url.host ?? ""
            let isApp = url.isFileURL || host.isEmpty
            if action.navigationType == .linkActivated && action.targetFrame?.isMainFrame != false && !isApp && (url.scheme == "https" || url.scheme == "http") {
                openInSafari(url, from: webView)
                return decisionHandler(.cancel)
            }
            decisionHandler(.allow)
        }

        // target="_blank" links
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = action.request.url { openInSafari(url, from: webView) }
            return nil
        }

        private func openInSafari(_ url: URL, from view: UIView) {
            guard let root = view.window?.rootViewController else { return }
            let safari = SFSafariViewController(url: url)
            safari.preferredControlTintColor = UIColor(named: "AccentColor")
            (root.presentedViewController ?? root).present(safari, animated: true)
        }

        // MARK: Haptics requested by the page: "success", "error" or a light tap
        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "ar" { showAR(message.body, from: message.webView); return }
            guard message.name == "haptic" else { return }
            switch message.body as? String ?? "light" {     // KolamIOS.haptic(kind) and the app's own taps
            case "success": UINotificationFeedbackGenerator().notificationOccurred(.success)
            case "warning": UINotificationFeedbackGenerator().notificationOccurred(.warning)
            case "error": UINotificationFeedbackGenerator().notificationOccurred(.error)
            case "selection": UISelectionFeedbackGenerator().selectionChanged()
            case "medium": UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            case "heavy": UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            case "soft": UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            case "rigid": UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            default: UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    
        // MARK: AR Quick Look: the part is placed on the floor through the camera (the USDZ ships inside the app)
        private var arItem: ARQuickLookPreviewItem?
        func showAR(_ body: Any, from web: WKWebView?) {
            guard let info = body as? [String: Any], let file = info["file"] as? String,
                  let root = web?.window?.rootViewController else { return }
            let url = AppWebView.webFolder.appendingPathComponent(file)
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            let item = ARQuickLookPreviewItem(fileAt: url)
            item.canonicalWebPageURL = nil
            item.allowsContentScaling = true
            arItem = item
            let ql = QLPreviewController(); ql.dataSource = self
            (root.presentedViewController ?? root).present(ql, animated: true)
        }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { arItem == nil ? 0 : 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { arItem! }
    }
}
