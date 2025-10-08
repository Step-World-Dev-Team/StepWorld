//
//  ContentView.swift
//  StepWorld
//
//  Created by Isai soria on 10/2/25.
//

import SwiftUI
import UIKit
import ImageIO
import MobileCoreServices

struct ContentView: View {
    @State private var offset = CGSize.zero
    @State private var lastOffset = CGSize.zero
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            Color.green.ignoresSafeArea() // Optional background color behind GIF
            
            GeometryReader { geometry in
                // Draggable + Zoomable GIF
                AnimatedGIFView(gifName: "Sunnyworld")
                    .frame(width: geometry.size.width * 1.5, height: geometry.size.height * 1.5)
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
                                    scale = min(max(newScale, 0.5), 3.0) // Optional: clamp zoom between 0.5x and 3x
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                }
                        )
                    )
                    .ignoresSafeArea()
            }
            
            // Top-right button
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
            
            // Bottom bar with 4 buttons
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
                                .frame(maxWidth: .infinity) // Each button takes equal space
                        }
                    }
                }
                .padding(.vertical, 12)
                .background(Color.green.opacity(0.3))
                .ignoresSafeArea(edges: .bottom) // Extend fully under the bottom
            }
        }
    }
}
