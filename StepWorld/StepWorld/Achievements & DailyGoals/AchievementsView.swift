//
//  AchievementsView.swift
//  StepWorld
//
//  Created by Isai soria on 11/24/25.
//
import SwiftUI

struct AchievementsView: View {
    var onClose: (() -> Void)? = nil   
    
    //@EnvironmentObject private var map: MapManager
    @StateObject private var viewModel = AchievementsViewModel()
    
    
    private let border: CGFloat = 20
    private let cornerSafeMargin: CGFloat = 2
    
    var body: some View {
        ZStack {
            Image("ProfileViewBackground")
                .interpolation(.none)
                .antialiased(false)
                .resizable()
                .frame(width: 350, height: 700)
                .scaledToFit()
                .padding()
                .padding(.bottom, 50)
            
            VStack(spacing: 0) {
             
                HStack {
                    Spacer()
                    Button {
                        onClose?()
                    } label: {
                        Image("close_button")
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                            .padding(.trailing, 10)
                            .padding(.top, 10)
                    }
                    .buttonStyle(.plain)
                }
                
                // Title
                Text("ACHIEVEMENTS")
                    .font(.custom("Press Start 2P", size: 20))
                    .foregroundColor(.black)
                    .padding(.top, 8)
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.custom("Press Start 2P", size: 10))
                        .foregroundColor(.red)
                        .padding(.top, 4)
                }
                
                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 12)
                }
                

                
                ScrollView {
                    VStack(spacing: 10) {
                        if viewModel.rows.isEmpty && !viewModel.isLoading {
                            Text("No achievements yet.")
                                .font(.custom("Press Start 2P", size: 10))
                                .foregroundColor(.gray)
                                .padding(.top, 16)
                        } else {
                            ForEach(viewModel.rows) { row in
                                AchievementRowView(row: row) {
                                    await handleClaim(for: row)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                    }
                    .padding(.horizontal, 60)
                    .padding(.top, 16)
                    .padding(.bottom, 30)
                }
                .frame(maxHeight: 580)
                .clipped()
                
                Spacer()
            }
        }
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
    
    // MARK: - Claim wrapper
    private func handleClaim(for row: AchievementsViewModel.Row) async {
        do {
            try await viewModel.claim(row)
        } catch {
            print("❌ Claim failed for \(row.id): \(error)")
        }
    }
}
