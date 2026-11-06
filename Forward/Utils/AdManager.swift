//
//  AdManager.swift
//  FutureJoy
//
//  Created by Hoang Nguyen on 12/5/25.
//

import Foundation
import GoogleMobileAds
import SwiftUI
import Combine

/// Manages native ad loading and caching for the app
@MainActor
final class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()
    
    // TODO: Replace with your actual AdMob Native Ad Unit ID
    // You can get this from your AdMob dashboard after creating a native ad unit
    private let nativeAdUnitID = "ca-app-pub-3940256099942544/3986624511" // Test ad unit ID
    
    // Cache for loaded native ads
    // Using fully qualified names to avoid naming conflicts (SDK 12.0.0+)
    private var nativeAdCache: [GoogleMobileAds.NativeAd] = []
    private let maxCacheSize = 5
    
    // Track which ad positions have been used
    private var usedAdPositions: Set<Int> = []
    
    // Track if we've started preloading
    private var hasStartedPreloading = false
    
    private override init() {
        super.init()
    }
    
    /// Preloads native ads into cache
    func preloadAds(count: Int = 3) async {
        for _ in 0..<count {
            await loadNativeAd()
        }
    }
    
    /// Starts preloading ads if not already started
    private func startPreloadingIfNeeded() {
        guard !hasStartedPreloading else { return }
        hasStartedPreloading = true
        Task {
            await preloadAds(count: 3)
        }
    }
    
    // Track pending ad loaders and their continuations
    private var pendingAdLoaders: [GoogleMobileAds.AdLoader: CheckedContinuation<GoogleMobileAds.NativeAd?, Never>] = [:]
    
    /// Loads a native ad and adds it to cache
    @discardableResult
    func loadNativeAd() async -> GoogleMobileAds.NativeAd? {
        // Get the root view controller for ad loading (must be on main thread)
        let rootViewController: UIViewController? = await MainActor.run {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                return nil
            }
            return window.rootViewController
        }
        
        // If we can't get root view controller, we can still load ads (it's optional)
        let adLoader = GoogleMobileAds.AdLoader(
            adUnitID: nativeAdUnitID,
            rootViewController: rootViewController,
            adTypes: [.native],
            options: nil
        )
        
        adLoader.delegate = self
        
        // Create a request
        let request = GoogleMobileAds.Request()
        
        // Wait for the ad to load
        return await withCheckedContinuation { continuation in
            self.pendingAdLoaders[adLoader] = continuation
            
            // Load the ad
            adLoader.load(request)
        }
    }
    
    /// Gets a native ad from cache, or loads a new one if cache is empty
    func getNativeAd() async -> GoogleMobileAds.NativeAd? {
        // Start preloading on first access
        startPreloadingIfNeeded()
        
        // Return cached ad if available
        if let ad = nativeAdCache.popFirst() {
            // Preload a new ad to keep cache ready
            Task {
                await loadNativeAd()
            }
            return ad
        }
        
        // Otherwise load a new one
        return await loadNativeAd()
    }
    
    /// Checks if an ad should be shown at a given position (every 10 items)
    func shouldShowAd(at index: Int) -> Bool {
        // Show ad at positions 9, 19, 29, etc. (every 10 items, starting after 9)
        return (index + 1) % 10 == 0
    }
    
    /// Calculates the ad position index from the event index
    func adPositionIndex(from eventIndex: Int) -> Int {
        // Ad positions: 0 (after 9th event), 1 (after 19th), etc.
        return (eventIndex + 1) / 10 - 1
    }
}

// MARK: - NativeAdLoaderDelegate
extension AdManager: GoogleMobileAds.NativeAdLoaderDelegate {
    func adLoader(_ adLoader: GoogleMobileAds.AdLoader, didReceive nativeAd: GoogleMobileAds.NativeAd) {
        // Add to cache if we have room
        if nativeAdCache.count < maxCacheSize {
            nativeAdCache.append(nativeAd)
        }
        
        // Resume continuation if waiting
        if let continuation = pendingAdLoaders.removeValue(forKey: adLoader) {
            continuation.resume(returning: nativeAd)
        }
    }
    
    func adLoader(_ adLoader: GoogleMobileAds.AdLoader, didFailToReceiveAdWithError error: Error) {
        print("Failed to load native ad: \(error.localizedDescription)")
        // Resume continuation with nil on error
        if let continuation = pendingAdLoaders.removeValue(forKey: adLoader) {
            continuation.resume(returning: nil)
        }
    }
}

// MARK: - AdLoaderDelegate
extension AdManager: GoogleMobileAds.AdLoaderDelegate {
    func adLoaderDidFinishLoading(_ adLoader: GoogleMobileAds.AdLoader) {
        // Called when ad loader finishes loading
    }
}

// Helper extension to pop first element from array
extension Array {
    mutating func popFirst() -> Element? {
        guard !isEmpty else { return nil }
        return removeFirst()
    }
}

