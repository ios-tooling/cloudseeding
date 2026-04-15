//
//  CloudKitNotAvailableView.swift
//  CloudSeeding
//
//  Created by Ben Gottlieb on 9/12/25.
//

import Suite

@available(iOS 17.0, macOS 14, *)
extension View {
	@ViewBuilder public func showingCloudKitAvailability() -> some View {
		self
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.overlay {
				CloudKitNotAvailableView()
			}
	}
}

@available(iOS 17.0, macOS 14, *)
public struct CloudKitNotAvailableView: View {
	var cloudKit = CloudKitInterface.instance
	public init() { }
	
	public var body: some View {
		let status = cloudKit.status
		
		if status != .signedIn {
			notSignedInView
		}
	}
	
	var notSignedInView: some View {
		ZStack {
			Color.black.opacity(0.35)
				.ignoresSafeArea(edges: .all)

			LinearGradient([1.0, 0.7, 0.25, 0.25, 0.7, 1.0].map { Color.black.opacity($0) }, from: .top, to: .bottom)
				.ignoresSafeArea(edges: .all)
				.blur(radius: 20)
			
			VStack {
				Text("You must sign in to iCloud to proceed.")
					.multilineTextAlignment(.center)
					.font(.largeTitle)
					.fontDesign(.rounded)
					.fontWeight(.bold)
					.foregroundColor(.white)
					.padding()
				
				#if os(iOS)
					Button("Open Settings") {
						UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
					}
					.safeGlassButton(prominent: false)
				#endif
			}
		}
	}
}
