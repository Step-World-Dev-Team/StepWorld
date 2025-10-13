//
//  ContentView.swift
//  StepWorld
//
//  Created by Isai Soria on 10/2/25.
//

import SwiftUI
import Combine

struct ContentView: View {

    @StateObject private var viewModel = SignInEmailViewModel()
    @State private var isSignedIn = false
    
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("StepWorld is Live!")
                
                Spacer()
                
                // following two buttons are for testing
                // assign the email and password that will be used
                Button("Set Email") {
                    viewModel.email = "fakeUser@testing.com"
                }
                
                Button("Set Password") {
                    viewModel.password = "password"
                }
                
                Spacer()
                
                // button to sign in user
                Button{
                    Task {
                        do {
                            try await viewModel.SignIn()
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
        }
        .padding()
        
        
    }
    

}

#Preview {
    ContentView()
}
