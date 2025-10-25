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
            VStack {
                
                Text("StepWorld is Live!")
                
                Spacer()
                
                /*
                // following two buttons are for testing
                // assign the email and password that will be used
                Button("Set Email") {
                    viewModel.email = "fakeUser@testing.com"
                }
                
                Button("Set Password") {
                    viewModel.password = "password"
                }
                */
                TextField("Email...", text: $viewModel.email)
                    .padding()
                    .background(Color.gray.opacity(0.4))
                    .cornerRadius(10)
                
                SecureField("Password...", text: $viewModel.password)
                    .padding()
                    .background(Color.gray.opacity(0.4))
                    .cornerRadius(10)
                                
                                
                
                Spacer()
                
                // button to sign in user
                Button{
                    Task {
                        do {
                            try await viewModel.signIn()
                            // typically you should be sending them to another view here
                            isSignedIn = true
                        } catch {
                            print(error)
                        }
                       
                    }
                } label: {
                    Text("Sign In")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(height: 55)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .navigationDestination(isPresented: $isSignedIn) {
                    InteractiveGIFMapView()
                }
            }
            
            
            // link to profileView for debugging
            NavigationLink(destination: ProfileView()) {
                Text("Go To Profile")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(height: 55)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            
            NavigationLink(destination: MapView()) {
                Text("Go To Map")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(height: 55)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            
            
        }
            }
    }

    
    #Preview {
        SignInView()
    }

