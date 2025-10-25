//
//  SignInView.swift
//  StepWorld
//
//  Created by Isai Soria on 10/2/25.
//

import SwiftUI
import Combine

struct SignInView: View {
    
    @StateObject private var viewModel = SignInEmailViewModel()
    @State private var isSignedIn = false
    
    var body: some View {
        NavigationStack {
            
            ZStack {
                
                // Attaching background image
                Image("SignInBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                
                VStack(spacing: 16) {
                    
                    // Title Text
                    Text("Welcome To ")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .font(.custom("Press Start 2P", size: 25))
                        .padding(.top, 60)
                        .padding(.bottom, 10)
                        .foregroundColor(Color(red: 0.180, green: 0.118, blue: 0.071))
                        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 2)
                    Text("StepWorld")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .font(.custom("Press Start 2P", size: 40))
                        .padding(.top, 5)
                        .padding(.bottom, 170)
                        .foregroundColor(Color(red: 0.180, green: 0.118, blue: 0.071))
                        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 2)
                    
                    // Make the space
                    Spacer()
                    
                    // Email input
                    TextField("Email...", text: $viewModel.email)
                        .padding()
                        .background(Color(red: 1.0, green: 0.9725, blue: 0.9059).opacity(0.75))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(red: 0.9216, green: 0.8431, blue: 0.6980), lineWidth: 1)
                        )
                        .foregroundColor(Color(red: 0.2353, green: 0.1647, blue: 0.1176))
                        .cornerRadius(10)
                        .frame(width: 300, height: 44)
                    
                    // Password input
                    SecureField("Password...", text: $viewModel.password)
                        .padding()
                        .background(Color(red: 1.0, green: 0.9725, blue: 0.9059).opacity(0.75))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(red: 0.9216, green: 0.8431, blue: 0.6980), lineWidth: 1)
                        )
                        .foregroundColor(Color(red: 0.2353, green: 0.1647, blue: 0.1176))
                        .cornerRadius(10)
                        .frame(width: 300, height: 44)
                    
                    // Space between text fields and button
                    Spacer()
                    
                    // Button to sign in user
                    Button{
                        Task {
                            do {
                                try await viewModel.signIn()
                                isSignedIn = true
                            } catch {
                                print(error)
                            }
                            
                        }
                    } label: {
                        Text("Sign In")
                            .font(.headline)
                            .foregroundColor(Color(red: 1.0, green: 0.9725, blue: 0.9059))
                            .frame(height: 55)
                            .frame(maxWidth: 350)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.89, green: 0.49, blue: 0.30))
                    .padding(.bottom, 50)
                    
                }
                .padding()
                
            }
            // When bool value is changed it sends the user to MapView
            .navigationDestination(isPresented: $isSignedIn) {
                InteractiveGIFMapView()
            }
        }
    }
}

#Preview {
    SignInView()
}

