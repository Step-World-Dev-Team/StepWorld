//
//  SignInView.swift
//  StepWorld
//
//  Created by Isai Soria on 10/2/25.
//

import SwiftUI
import Combine
import FirebaseFirestore

struct SignInView: View {
    
    @StateObject private var viewModel = AuthenticationViewModel()
    @EnvironmentObject var stepManager: StepManager
    @EnvironmentObject var mapManager: MapManager
    
    @AppStorage("remember_me") private var rememberMe: Bool = true
    @AppStorage("saved_email") private var savedEmail: String = ""
    
    //@State private var isSignedIn = false
    
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
                    
                    if viewModel.mode == .signUp {
                        TextField("Display name (optional)", text: $viewModel.displayName)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .padding()
                            .background(Color(red: 1.0, green: 0.9725, blue: 0.9059).opacity(0.75))
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(red: 0.9216, green: 0.8431, blue: 0.6980), lineWidth: 1)
                            )
                            .foregroundColor(Color(red: 0.2353, green: 0.1647, blue: 0.1176))
                            .cornerRadius(10)
                            .frame(width: 300, height: 44)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // Space between text fields and button
                    Spacer()
                    
                    // Button to sign in user
                    Button{
                        Task {
                            do {
                                let auth = try await viewModel.performPrimaryAction()
                                
                                // Set IDs for managers
                                stepManager.userId = auth.uid
                                mapManager.userId  = auth.uid
                                
                                // Kick off data loads
                                async let stepsTask: Void = stepManager.syncToday()
                                async let mapTask:   Void = try mapManager.loadFromFirestoreIfAvailable()
                                _ = try await (stepsTask, mapTask)
                                
                                // Save email if desired
                                if rememberMe { savedEmail = viewModel.email } else { savedEmail = "" }
                                
                                //isSignedIn = true
                            } catch {
                                viewModel.errorText = (error as NSError).localizedDescription
                                print("Auth failed: \(error)")
                            }
                            
                        }
                    } label: {
                        Text(viewModel.mode == .signIn ? "Sign In" : "Sign Up")
                            .font(.headline)
                            .foregroundColor(Color(red: 1.0, green: 0.9725, blue: 0.9059))
                            .frame(height: 55)
                            .frame(maxWidth: 350)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.89, green: 0.49, blue: 0.30))
                    .padding(.bottom, 5)
                    
                    // Toggle for Remember Me
                    Toggle("Remember me", isOn: $rememberMe)
                        .frame(width: 300, alignment: .leading)
                        .tint(Color(red: 0.14, green: 0.25, blue: 0.37))
                        .padding(.top, 4)
                        .font(.custom("Press Start 2P", size: 15))
                        .foregroundColor(Color(red: 1.0, green: 0.9725, blue: 0.9059))
                    
                    // Mode switch
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.mode = (viewModel.mode == .signIn) ? .signUp : .signIn
                            viewModel.errorText = nil
                            viewModel.confirmPassword = ""
                            viewModel.displayName = ""
                        }
                    } label: {
                        Text(viewModel.mode == .signIn
                             ? "New here? Create an account"
                             : "Already have an account? Sign in")
                        .font(.custom("Press Start 2P", size: 10))
                        .foregroundColor(Color(red: 0.90, green: 0.93, blue: 0.97))
                    }
                    .padding(.bottom, 20)
                    
                    // Error text
                    if let err = viewModel.errorText {
                        Text(err)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .frame(width: 300)
                    }
                    
                }
                .padding()
                
            }
        }
        .task {
            Task {
                // Pre-fill previously saved email
                if !savedEmail.isEmpty {
                    viewModel.email = savedEmail
                }
            }
        }
    }
}

#Preview {
    SignInView()
}

