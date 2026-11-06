//
//  NativeAdView.swift
//  FutureJoy
//
//  Created by Hoang Nguyen on 12/5/25.
//

import SwiftUI
import GoogleMobileAds

/// SwiftUI wrapper for Google AdMob Native Ads
struct NativeAdView: UIViewRepresentable {
    let nativeAd: GoogleMobileAds.NativeAd
    
    func makeUIView(context: Context) -> GoogleMobileAds.NativeAdView {
        let nativeAdView = GoogleMobileAds.NativeAdView()
        
        // Configure the native ad view to match EventRowView style
        nativeAdView.nativeAd = nativeAd
        
        // Create a container view that matches EventRowView dimensions
        let containerView = UIView()
        containerView.backgroundColor = .white
        containerView.layer.cornerRadius = 20
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.04
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 8
        
        // Add border
        containerView.layer.borderWidth = 1.25
        containerView.layer.borderColor = UIColor(
            red: 0.65,
            green: 0.60,
            blue: 0.95,
            alpha: 0.6
        ).cgColor
        
        // Create layout similar to EventRowView
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 16
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        
        // Left side - Ad icon (similar to days counter badge)
        let iconImageView = UIImageView()
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.clipsToBounds = true
        iconImageView.layer.cornerRadius = 16
        iconImageView.backgroundColor = UIColor(
            red: 0.45,
            green: 0.40,
            blue: 0.95,
            alpha: 1.0
        )
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set icon image if available
        if let icon = nativeAd.icon {
            iconImageView.image = icon.image
        } else {
            // Fallback: show "Ad" label
            let adLabel = UILabel()
            adLabel.text = "Ad"
            adLabel.font = .systemFont(ofSize: 14, weight: .semibold)
            adLabel.textColor = .white
            adLabel.textAlignment = .center
            iconImageView.addSubview(adLabel)
            adLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                adLabel.centerXAnchor.constraint(equalTo: iconImageView.centerXAnchor),
                adLabel.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor)
            ])
        }
        
        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 100),
            iconImageView.heightAnchor.constraint(equalToConstant: 100)
        ])
        
        // Right side - Ad content
        let rightStackView = UIStackView()
        rightStackView.axis = .vertical
        rightStackView.spacing = 8
        rightStackView.alignment = .leading
        
        // Headline
        if let headline = nativeAd.headline {
            let headlineLabel = UILabel()
            headlineLabel.text = headline
            headlineLabel.font = .systemFont(ofSize: 20, weight: .semibold)
            headlineLabel.textColor = UIColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 1.0)
            headlineLabel.numberOfLines = 2
            rightStackView.addArrangedSubview(headlineLabel)
        }
        
        // Body
        if let body = nativeAd.body {
            let bodyLabel = UILabel()
            bodyLabel.text = body
            bodyLabel.font = .systemFont(ofSize: 15, weight: .medium)
            bodyLabel.textColor = UIColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 1.0)
            bodyLabel.numberOfLines = 2
            rightStackView.addArrangedSubview(bodyLabel)
        }
        
        // Advertiser
        if let advertiser = nativeAd.advertiser {
            let advertiserLabel = UILabel()
            advertiserLabel.text = advertiser
            advertiserLabel.font = .systemFont(ofSize: 14)
            advertiserLabel.textColor = UIColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 1.0)
            rightStackView.addArrangedSubview(advertiserLabel)
        }
        
        // Add views to stack
        stackView.addArrangedSubview(iconImageView)
        stackView.addArrangedSubview(rightStackView)
        
        containerView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        nativeAdView.addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: nativeAdView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor)
        ])
        
        // Register views for click tracking (required for proper ad interaction)
        nativeAdView.iconView = iconImageView
        if let headlineLabel = rightStackView.arrangedSubviews.first as? UILabel {
            nativeAdView.headlineView = headlineLabel
        }
        if rightStackView.arrangedSubviews.count > 1,
           let bodyLabel = rightStackView.arrangedSubviews[1] as? UILabel {
            nativeAdView.bodyView = bodyLabel
        }
        if let advertiserLabel = rightStackView.arrangedSubviews.last as? UILabel {
            nativeAdView.advertiserView = advertiserLabel
        }
        
        // Register the call to action button if available
        if let callToAction = nativeAd.callToAction {
            let ctaButton = UIButton(type: .system)
            ctaButton.setTitle(callToAction, for: .normal)
            ctaButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
            ctaButton.setTitleColor(.white, for: .normal)
            ctaButton.backgroundColor = UIColor(red: 0.45, green: 0.40, blue: 0.95, alpha: 1.0)
            ctaButton.layer.cornerRadius = 8
            ctaButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
            rightStackView.addArrangedSubview(ctaButton)
            nativeAdView.callToActionView = ctaButton
        }
        
        return nativeAdView
    }
    
    func updateUIView(_ uiView: GoogleMobileAds.NativeAdView, context: Context) {
        // Update if needed
    }
}

/// SwiftUI view that loads and displays a native ad
struct NativeAdContainerView: View {
    @StateObject private var adManager = AdManager.shared
    @State private var nativeAd: GoogleMobileAds.NativeAd?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                // Loading placeholder that matches EventRowView style
                HStack(alignment: .center, spacing: 16) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.45, green: 0.40, blue: 0.95),
                                    Color(red: 0.55, green: 0.45, blue: 0.92)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.9, green: 0.9, blue: 0.92))
                            .frame(height: 20)
                            .frame(maxWidth: 200)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.9, green: 0.9, blue: 0.92))
                            .frame(height: 16)
                            .frame(maxWidth: 150)
                    }
                    
                    Spacer()
                }
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            Color(red: 0.65, green: 0.60, blue: 0.95).opacity(0.6),
                            lineWidth: 1.25
                        )
                )
            } else if let ad = nativeAd {
                NativeAdView(nativeAd: ad)
                    .frame(height: 120)
            } else {
                // Failed to load ad - show empty space or hide
                EmptyView()
            }
        }
        .task {
            await loadAd()
        }
    }
    
    private func loadAd() async {
        isLoading = true
        let ad = await adManager.getNativeAd()
        await MainActor.run {
            self.nativeAd = ad
            self.isLoading = false
        }
    }
}
