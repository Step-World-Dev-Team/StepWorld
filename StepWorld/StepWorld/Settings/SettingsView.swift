//
//  SettingsView.swift
//  StepWorld
//
//  Created by Andre Bortoloto Lebeis on 11/1/25.
//

import SwiftUI

struct SettingsView: View {
    var onClose: (() -> Void)? = nil
    var onSignOut: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss  // for closing the view
    
    @StateObject private var authVM = SignInEmailViewModel()
    
    @AppStorage("remember_me") private var rememberMe: Bool = true
    
    var body: some View {
        ZStack {
            
            Image("ProfileViewBackground")
                .interpolation(.none)
                .antialiased(false)
                .resizable()
                .frame(width: 350, height: 700) // set desired size
                .scaledToFit()
                .padding()
                .padding(.bottom, 50)
            
            VStack {
                
                HStack {
                    Spacer()
                    
                    Button {
                        onClose?()  // closes the view and goes back
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
                
                Text("SETTINGS")
                    .font(.custom("Press Start 2P", size: 25))
                    .foregroundColor(.black)
                    .padding(.top, 10)
                
                Button(role: .destructive) {
                                    do {
                                        try authVM.signOut()
                                        onSignOut?()  // tell parent to route back to SignIn
                                    } catch {
                                        print("Sign out failed: \(error)")
                                    }
                                } label: {
                                    Text("Sign Out")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 48)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                                .padding(.horizontal, 24)
                                .padding(.top, 12)
            
                Spacer()
            }
            
            
        }
    }
}


#Preview {
    SettingsView()
}
