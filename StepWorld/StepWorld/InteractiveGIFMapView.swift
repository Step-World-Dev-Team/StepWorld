//
//  InteractiveGIFMapView.swift
//  StepWorld
//
//  Created by Anali Cardoza on 10/12/25.
//
import SwiftUI

struct InteractiveGIFMapView: View {
    // MARK: - Gesture state
    @State private var showProfile = false
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
                    .frame(width: 200, height: 200)
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
                .contentShape(Rectangle())
                .allowsHitTesting(!showProfile)
                
            }
            .overlay(alignment: .topTrailing) {
                StatsDisplay()
                    .padding(.top, 4)
                    .padding(.trailing, 6)
            }
            .zIndex(0)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            
            
            //Bottom bar with 4 buttons, need to app icons, decide what we would like
            VStack {
                Spacer()
                HStack(spacing: 0) {
                    ForEach(1...4, id: \.self) { index in
                        if index == 3 {
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                    showProfile = true
                                }
                            } label: {
                                Image("profile_icon")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 100)
                                    .offset(x: 0, y: 46)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                            }
                            
                        } else {
                            Button(action: {
                                print("Bottom button \(index) tapped")
                            }) {
                                switch index {
                                case 1:
                                    Image("home_icon") // your shop icon
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 100, height: 100)
                                        .offset(x: 0, y: 46)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                case 2:
                                    Image("money_icon 1")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 100, height: 100)
                                        .offset(x: 0, y: 46)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                case 4:
                                    Image("gear_icon")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 100, height: 100)
                                        .offset(x: 0, y: 46)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                default:
                                    EmptyView()
                                }
                            }
                            //  }
                            /*Image("money_icon 1")
                             .resizable()
                             .scaledToFit()
                             .frame(width: 100, height: 100)
                             .offset(x: 0, y: 46)
                             .foregroundColor(.white)
                             .frame(maxWidth: .infinity)
                             */
                            //.font(.system(size: 24))
                            //.foregroundColor(.white)
                            //.frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.vertical, 12)
                .background(Color.green.opacity(0.3))
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(!showProfile) //block when modal is up
                .zIndex(1)
                
                
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
            if showProfile {
                ZStack { // container ensures popup is above the dim
                        // 1) Dim layer
                        Color.black.opacity(0.5)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                    showProfile = false
                                }
                            }

                        // 2) Popup
                        GeometryReader { g in
                            ProfileView(onClose: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                    showProfile = false
                                }
                            })
                            .background(Color.clear)
                            .frame(
                                width: min(g.size.width * 0.92, 500),
                                height: min(g.size.height * 0.90, 800)
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity) // center it
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(100) // definitely above everything else
            }
        }
    }
}

#Preview {
    NavigationStack {
        InteractiveGIFMapView()
            .environmentObject(StepManager())
    }
}
