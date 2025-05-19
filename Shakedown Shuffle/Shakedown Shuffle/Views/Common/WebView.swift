import SwiftUI
import WebKit

// Coordinator class separate from the WebView for better state management
class WebViewCoordinator: NSObject, WKNavigationDelegate, ObservableObject {
    @Published var isLoading = true
    @Published var didFinishLoading = false
    @Published var hasError = false
    var url: URL
    var fallbackURL: URL?
    var webView: WKWebView?
    private var hasAttemptedCookieAccept = false
    private var didAttemptFallback = false

    init(url: URL, fallbackURL: URL? = nil) {
        self.url = url
        self.fallbackURL = fallbackURL
        super.init()
    }

    func setURL(_ newURL: URL, fallback: URL? = nil) {
        url = newURL
        if let fallback = fallback {
            fallbackURL = fallback
        }
        if let webView = webView {
            let request = URLRequest(url: newURL, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30.0)
            webView.load(request)
        }
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        didFinishLoading = true

        if !hasAttemptedCookieAccept {
            hasAttemptedCookieAccept = true
            acceptCookies(webView: webView)
        }
        unmuteVideo(webView: webView)
        checkForPlaybackRestriction(webView: webView)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        hasError = true
        attemptFallbackIfNeeded(webView: webView)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        hasError = true
        attemptFallbackIfNeeded(webView: webView)
    }
    
    private func acceptCookies(webView: WKWebView) {
        let script = """
        (function() {
            const cookieButtons = document.querySelectorAll('button, a');
            for (let btn of cookieButtons) {
                const text = btn.textContent || '';
                if (text.includes('Accept') || text.includes('Agree') || text.includes('Cookie')) {
                    btn.click();
                    return;
                }
            }
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    private func unmuteVideo(webView: WKWebView) {
        let script = """
        (function() {
            var vid = document.querySelector('video');
            if (vid) {
                vid.muted = false;
                vid.play();
            }
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    private func checkForPlaybackRestriction(webView: WKWebView) {
        guard !didAttemptFallback, let fallback = fallbackURL else { return }
        let script = """
        (function() {
            const text = document.body.innerText || '';
            return text.includes('Watch on YouTube') || text.includes('Playback on other websites has been disabled');
        })();
        """
        webView.evaluateJavaScript(script) { result, _ in
            if let blocked = result as? Bool, blocked {
                self.didAttemptFallback = true
                let request = URLRequest(url: fallback, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30.0)
                webView.load(request)
            }
        }
    }

    private func attemptFallbackIfNeeded(webView: WKWebView) {
        guard !didAttemptFallback, let fallback = fallbackURL else { return }
        didAttemptFallback = true
        let request = URLRequest(url: fallback, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30.0)
        webView.load(request)
    }
}

struct WebView: UIViewRepresentable {
    let coordinator: WebViewCoordinator
    
    init(coordinator: WebViewCoordinator) {
        self.coordinator = coordinator
    }
    
    func makeUIView(context: Context) -> WKWebView {
        if let existing = coordinator.webView {
            return existing
        }

        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = coordinator
        webView.isUserInteractionEnabled = true
        webView.allowsLinkPreview = false
        webView.scrollView.bounces = false

        let request = URLRequest(url: coordinator.url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30.0)
        webView.load(request)

        coordinator.webView = webView
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != coordinator.url {
            let request = URLRequest(url: coordinator.url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30.0)
            webView.load(request)
        }
    }
}

struct WebViewContainer: View {
    let url: URL
    let fallbackURL: URL?
    @StateObject private var coordinator: WebViewCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var timeoutTimerActive = true

    init(url: URL, fallbackURL: URL? = nil, coordinator: WebViewCoordinator? = nil) {
        self.url = url
        self.fallbackURL = fallbackURL
        if let coord = coordinator {
            self._coordinator = StateObject(wrappedValue: coord)
            coord.setURL(url, fallback: fallbackURL)
        } else {
            self._coordinator = StateObject(wrappedValue: WebViewCoordinator(url: url, fallbackURL: fallbackURL))
        }
    }
    
    private func openInSafari() {
        let target = coordinator.fallbackURL ?? coordinator.url
        UIApplication.shared.open(target)
    }
    
    var body: some View {
        ZStack {
            WebView(coordinator: coordinator)
                .ignoresSafeArea()
                .disabled(coordinator.isLoading && !timeoutTimerActive)
            
            if coordinator.isLoading && timeoutTimerActive {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .overlay(
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: openInSafari) {
                        Image(systemName: "safari")
                            .foregroundColor(.blue)
                    }
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                timeoutTimerActive = false
            }
        }
    }
}
