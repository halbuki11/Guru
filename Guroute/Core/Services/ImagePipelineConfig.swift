import Foundation
import Nuke
import NukeUI
import UIKit

// MARK: - Image Pipeline Configuration
/// Configures Nuke's image loading pipeline for optimal performance:
/// - Aggressive disk caching (300 MB)
/// - Tuned memory cache (150 MB)
/// - Progressive JPEG decoding
/// - Deduplication & rate limiting
/// - Device-aware image sizing
enum ImagePipelineConfigurator {

    /// Call once at app launch (in GurouteApp.init)
    static func configure() {
        var config = ImagePipeline.Configuration.withDataCache(
            name: "com.guroute.images",
            sizeLimit: 300 * 1024 * 1024 // 300 MB disk cache
        )

        // Memory cache: 150 MB
        config.imageCache = ImageCache(costLimit: 150 * 1024 * 1024)

        // Progressive JPEG decoding (show blurry → sharp)
        config.isProgressiveDecodingEnabled = true

        // Coalesce duplicate requests
        config.isTaskCoalescingEnabled = true

        // Rate limiting — max 6 concurrent image loads
        config.isRateLimiterEnabled = true

        // Larger URLSession with optimized timeouts
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.urlCache = nil // Nuke manages its own cache
        sessionConfig.httpMaximumConnectionsPerHost = 8
        sessionConfig.timeoutIntervalForRequest = 20
        sessionConfig.timeoutIntervalForResource = 60
        sessionConfig.requestCachePolicy = .returnCacheDataElseLoad
        config.dataLoader = DataLoader(configuration: sessionConfig)

        ImagePipeline.shared = ImagePipeline(configuration: config)
    }
}

// MARK: - Smart Image URL Builder
/// Builds optimal image URLs based on device, target size, and source type.
enum ImageURLBuilder {

    private static let screenScale = UIScreen.main.scale
    private static let screenWidth = UIScreen.main.bounds.width

    /// Tiers for different UI components
    enum Tier {
        case hero      // Full-screen hero: highest quality
        case card      // Horizontal scroll cards: high quality
        case thumbnail // List rows, small images: compact
        case icon      // Tiny thumbnails: minimal

        var maxPixelWidth: CGFloat {
            let scale = ImageURLBuilder.screenScale
            switch self {
            case .hero:      return min(ImageURLBuilder.screenWidth * scale, 2000)
            case .card:      return min(ImageURLBuilder.screenWidth * 0.78 * scale, 1400)
            case .thumbnail: return 300
            case .icon:      return 180
            }
        }

        var quality: Int {
            switch self {
            case .hero:      return 90
            case .card:      return 85
            case .thumbnail: return 80
            case .icon:      return 75
            }
        }
    }

    /// Build optimized URL for Ticketmaster images
    /// Falls back to TABLET format if RETINA not available
    static func ticketmasterURL(_ rawURL: String, tier: Tier) -> String {
        guard !rawURL.isEmpty,
              rawURL.contains("ticketm") || rawURL.contains("tmcdn")
        else { return rawURL }

        // Prefer landscape formats for hero/card, portrait for thumbnails
        let targetFormat: String
        switch tier {
        case .hero:
            targetFormat = "TABLET_LANDSCAPE_LARGE_16_9"  // Most widely available large format
        case .card:
            targetFormat = "TABLET_LANDSCAPE_16_9"
        case .thumbnail:
            targetFormat = "RETINA_PORTRAIT_3_2"
        case .icon:
            targetFormat = "ARTIST_PAGE_3_2"
        }

        let knownPatterns = [
            "TABLET_LANDSCAPE_LARGE_16_9",
            "TABLET_LANDSCAPE_16_9",
            "RETINA_LANDSCAPE_16_9",
            "RETINA_PORTRAIT_16_9",
            "RETINA_PORTRAIT_3_2",
            "ARTIST_PAGE_3_2",
            "CUSTOM"
        ]

        var result = rawURL
        for pattern in knownPatterns {
            if result.contains(pattern) {
                result = result.replacingOccurrences(of: pattern, with: targetFormat)
                break
            }
        }
        return result
    }

    /// Universal: auto-detect source and optimize
    static func optimizedURL(_ rawURL: String, tier: Tier) -> String {
        guard !rawURL.isEmpty else { return rawURL }

        if rawURL.contains("ticketm") || rawURL.contains("tmcdn") {
            return ticketmasterURL(rawURL, tier: tier)
        } else if rawURL.contains("supabase.co/storage") {
            // Supabase Storage: zaten optimize — dokunma
            return rawURL
        }

        // Other URLs: return as-is
        return rawURL
    }
}

// MARK: - Image Prefetcher Helper
/// Prefetches an array of image URLs for smoother scrolling.
@MainActor
final class ImagePrefetchCoordinator {
    private let prefetcher = ImagePrefetcher(
        pipeline: .shared,
        destination: .memoryCache,
        maxConcurrentRequestCount: 4
    )

    /// Prefetch destination images at the specified tier
    func prefetchDestinations(_ destinations: [any ImageURLProvider], tier: ImageURLBuilder.Tier) {
        let urls: [URL] = destinations.compactMap { item in
            let optimized = ImageURLBuilder.optimizedURL(item.imageURLString, tier: tier)
            return URL(string: optimized)
        }
        prefetcher.startPrefetching(with: urls)
    }

    /// Prefetch raw URL strings
    func prefetchURLs(_ urlStrings: [String], tier: ImageURLBuilder.Tier) {
        let urls: [URL] = urlStrings.compactMap { raw in
            let optimized = ImageURLBuilder.optimizedURL(raw, tier: tier)
            return URL(string: optimized)
        }
        prefetcher.startPrefetching(with: urls)
    }

    /// Cancel all ongoing prefetches
    func cancelAll() {
        prefetcher.stopPrefetching()
    }
}

// MARK: - Protocol for image-providing models
protocol ImageURLProvider {
    var imageURLString: String { get }
}
