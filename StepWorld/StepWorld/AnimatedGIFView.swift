//
//  AnimatedGIFView.swift
//  StepWorld
//
//  Created by Anali Cardoza on 10/7/25.
//
import SwiftUI
import UIKit

struct AnimatedGIFView: UIViewRepresentable {
    let gifName: String

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = true

        if let path = Bundle.main.path(forResource: gifName, ofType: "gif"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            imageView.image = UIImage.animatedImageWithGIFData(data)
        }

        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        // No updates needed for now
    }
}
