#if DEBUG && targetEnvironment(simulator)
import XCTest
import SwiftUI
import UIKit
@testable import Forward

@MainActor
final class StableHeaderLayoutTests: EventListTestCase {
    func testTitleAndLayoutStayStableOnBothSidesOfFittingBoundary() async throws {
        // Title 100 + leading 48 + trailing 140 + spacing 12 * 2 = 312.
        for (width, titleCenter): (CGFloat, CGFloat) in [(199, 99.5), (200, 100), (311, 155.5),
                                                         (312, 110), (403, 201), (404, 202), (600, 300)] {
            var baseline: CGRect?
            var baselineHeight: CGFloat?
            for actionWidth: CGFloat in [0, 80, 140] {
                let frames = try await render(width: width, actionWidth: actionWidth)
                let title = try XCTUnwrap(frames["title"])
                let leading = try XCTUnwrap(frames["leading"])
                let trailing = try XCTUnwrap(frames["trailing"])
                let header = try XCTUnwrap(frames["header"])
                XCTAssertEqual(title.midX, titleCenter, accuracy: 0.5)
                XCTAssertFalse(title.intersects(leading))
                XCTAssertFalse(title.intersects(trailing))
                XCTAssertFalse(leading.intersects(trailing))
                for frame in [title, leading, trailing] where !frame.isEmpty {
                    XCTAssertTrue(header.insetBy(dx: -0.5, dy: -0.5).contains(frame))
                }
                if let baseline, let baselineHeight {
                    XCTAssertEqual(title.minY, baseline.minY, accuracy: 0.5)
                    XCTAssertEqual(title.minX, baseline.minX, accuracy: 0.5)
                    XCTAssertEqual(header.height, baselineHeight, accuracy: 0.5)
                } else {
                    baseline = title
                    baselineHeight = header.height
                }
                if width >= 312 {
                    XCTAssertEqual(title.midY, leading.midY, accuracy: 0.5, "Must exercise inline placement")
                } else {
                    XCTAssertGreaterThanOrEqual(leading.minY, title.maxY + 12 - 0.5)
                }
                if width < 200 && actionWidth > 0 {
                    XCTAssertGreaterThanOrEqual(trailing.minY, leading.maxY + 12 - 0.5)
                }
            }
        }
    }

    func testRightToLeftMirrorsActionsWithoutMovingTitle() async throws {
        for (width, titleCenter): (CGFloat, CGFloat) in [(199, 99.5), (311, 155.5), (312, 202),
                                                         (403, 202), (404, 202), (600, 300)] {
            let frames = try await render(width: width, actionWidth: 140, direction: .rightToLeft)
            let title = try XCTUnwrap(frames["title"])
            let leading = try XCTUnwrap(frames["leading"])
            let trailing = try XCTUnwrap(frames["trailing"])
            XCTAssertEqual(title.midX, titleCenter, accuracy: 0.5)
            XCTAssertEqual(leading.maxX, width, accuracy: 0.5)
            XCTAssertEqual(trailing.minX, 0, accuracy: 0.5)
        }
    }

    func testChangingLeadingActionKeepsFallbackChoiceStable() async throws {
        for width: CGFloat in [283, 284] {
            for leadingWidth: CGFloat in [48, 132] {
                let frames = try await render(width: width, actionWidth: 80,
                                              leadingWidth: leadingWidth, leadingReservation: 132)
                let header = try XCTUnwrap(frames["header"])
                let title = try XCTUnwrap(frames["title"])
                let leading = try XCTUnwrap(frames["leading"])
                let trailing = try XCTUnwrap(frames["trailing"])
                XCTAssertEqual(header.height, width < 284 ? 150 : 90, accuracy: 0.5)
                XCTAssertEqual(title.midX, width / 2, accuracy: 0.5)
                XCTAssertFalse(leading.intersects(trailing))
            }
        }
    }

    private func render(width: CGFloat, actionWidth: CGFloat,
                        leadingWidth: CGFloat = 48, leadingReservation: CGFloat = 48,
                        direction: LayoutDirection = .leftToRight) async throws -> [String: CGRect] {
        let capture = FrameCapture()
        let content = StableHeaderLayout {
            Color.red.frame(width: 100, height: 30).captureFrame("title")
            Color.blue.frame(width: leadingWidth, height: 48).captureFrame("leading")
            Color.green.frame(width: actionWidth, height: actionWidth == 0 ? 0 : 44).captureFrame("trailing")
            Color.clear.frame(width: leadingReservation, height: 48).hidden()
            Color.clear.frame(width: 140, height: 48).hidden()
        }
        .captureFrame("header")
        .coordinateSpace(name: "header-test")
        .environment(\.layoutDirection, direction)
        .frame(width: width)
        .onPreferenceChange(HeaderFrames.self) { capture.frames = $0 }
        let host = UIHostingController(rootView: content)
        let window = makeWindow()
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        host.view.frame = CGRect(x: 0, y: 0, width: width, height: 500)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        for _ in 0..<50 {
            if capture.frames.count == 4 { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(capture.frames.count, 4)
        return capture.frames
    }
}

private final class FrameCapture {
    var frames: [String: CGRect] = [:]
}

private struct HeaderFrames: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private extension View {
    func captureFrame(_ name: String) -> some View {
        background(GeometryReader { proxy in
            Color.clear.preference(key: HeaderFrames.self,
                                   value: [name: proxy.frame(in: .named("header-test"))])
        })
    }
}
#endif
