//
//  GIFView.swift
//  StepWorld
//
//  Created by Anali Cardoza on 10/12/25.
//
import SwiftUI
import WebKit

struct GIFView: UIViewRepresentable {
    let gifName: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()//allows me to use GIF
        webView.scrollView.isScrollEnabled = false  //disables scrolling
        webView.contentMode = .scaleAspectFill  //scales gif to full view
        if let path = Bundle.main.path(forResource: gifName, ofType: "gif") {
            let url = URL(fileURLWithPath: path)
            webView.loadFileURL(url, allowingReadAccessTo: url)
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

