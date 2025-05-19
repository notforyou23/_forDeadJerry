import SwiftUI
import WebKit

// Coordinator class separate from the WebView for better state management
class WebViewCoordinator: NSObject, WKNavigationDelegate, ObservableObject {
    @Published var isLoading = true
    @Published var didFinishLoading = false
    @Published var hasError = false
    var url: URL
    private var hasAttemptedCookieAccept = false
    
    init(url: URL) {
        self.url = url
        super.init()
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
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        hasError = true
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        hasError = true
    }
    
    private func acceptCookies(webView: WKWebView) {
        let script = """
        (function() {
            // Try to find and click cookie banner buttons
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
}

struct WebView: UIViewRepresentable {
    let coordinator: WebViewCoordinator
    
    init(coordinator: WebViewCoordinator) {
        self.coordinator = coordinator
    }
    
    func makeUIView(context: Context) -> WKWebView {
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
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Don't reload the webview when the view updates to prevent flickering
    }
}

struct WebViewContainer: View {
    let url: URL
    @StateObject private var coordinator: WebViewCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var timeoutTimerActive = true

    init(url: URL, coordinator: WebViewCoordinator? = nil) {
        self.url = url
        if let coord = coordinator {
            self._coordinator = StateObject(wrappedValue: coord)
        } else {
            self._coordinator = StateObject(wrappedValue: WebViewCoordinator(url: url))
        }
    }
    
    // Function to open URL in Safari
    private func openInSafari() {
        if let url = URL(string: coordinator.url.absoluteString) {
            UIApplication.shared.open(url)
        }
    }
    
    var body: some View {
        ZStack {
            // WebView with no unnecessary updates
            WebView(coordinator: coordinator)
                .ignoresSafeArea()
                .disabled(coordinator.isLoading && !timeoutTimerActive)
            
            // Loading overlay only shown during initial load and timeout hasn't expired
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
                    // Open in Safari button
                    Button(action: openInSafari) {
                        Image(systemName: "safari")
                            .foregroundColor(.blue)
                    }
                    
                    // Done button
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Force dismiss the loading overlay after a timeout to ensure interaction works
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                timeoutTimerActive = false
            }
        }
    }
} 