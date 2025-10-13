//
//  InteractiveGIFMapView.swift
//  StepWorld
//
//  Created by Anali Cardoza on 10/12/25.
//
import SwiftUI

struct InteractiveGIFMapView: View {
    // MARK: - Gesture state
    @State private var offset = CGSize.zero
    @State private var lastOffset = CGSize.zero
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    // MARK: - Tap feedback
    @State private var message: String? = nil

    var body: some View {
        ZStack {
            Color.green.ignoresSafeArea() // optional background behind GIF used green for now

            GeometryReader { geometry in
                // ZStack so GIF and buttons move/scale together
                ZStack {
                    // MARK: - GIF background
                    AnimatedGIFView(gifName: "Mainmap")
                        .frame(width: geometry.size.width * 1.5,
                               height: geometry.size.height * 1.5)

                    // MARK: - Interactive buildings
                    Button {
                        message = "🏠 Home tapped!"
                    } label: {
                        Color.red.opacity(0.3) // set to clear when happy with position
                    }
                    .frame(width: 300, height: 200)
                    .position(x: geometry.size.width * 0.3 - 0.50 * geometry.size.width, // move left % of screen width
                              y: geometry.size.height * 0.6 - 0.20 * geometry.size.height) // move up % of screen height

                    // Example building 2
                    Button {
                        message = "🌳 Forest tapped!"
                    } label: {
                        //Color.clear
                        Color.blue.opacity(0.3) // temporary for placement debugging, change to clear when done
                    }
                    .frame(width: 200, height: 300)
                    .position(x: geometry.size.width * 0.95 + 0.75 * geometry.size.width,
                              y: geometry.size.height * 0.9 - 0.75 * geometry.size.height)
                    Button {
                        message = "🐮 Barn tapped!"
                    } label: {
                        //Color.clear
                        Color.pink.opacity(0.3) // temporary for placement debugging, change to clear when done
                    }
                    .frame(width: 150, height: 150)
                    .position(x: geometry.size.width * 0.3 + 0.10 * geometry.size.width,
                              y: geometry.size.height * 0.6 + 0.40 * geometry.size.height)
                }
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    SimultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            },
                        MagnificationGesture()
                            .onChanged { value in
                                let newScale = lastScale * value
                                scale = min(max(newScale, 0.5), 3.0)
                            }
                            .onEnded { _ in
                                lastScale = scale
                            }
                    )
                )
            }

            // MARK: - Top-right Gear button, for Andre to edit?
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        print("Top-right button tapped")
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 24))
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
            }

            // MARK: - Bottom bar with 4 buttons, need to app icons, decide what we would like
            VStack {
                Spacer()
                HStack(spacing: 0) {
                    ForEach(1...4, id: \.self) { index in
                        Button(action: {
                            print("Bottom button \(index) tapped")
                        }) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.vertical, 12)
                .background(Color.green.opacity(0.3))
                .ignoresSafeArea(edges: .bottom)
            }

            // MARK: - Tap message(Barn, House, Forest)
            if let msg = message {
                Text(msg)
                    .font(.headline)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    .foregroundColor(.white)
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            message = nil
                        }
                    }
            }
        }
    }
}

#Preview {
    InteractiveGIFMapView()
}
