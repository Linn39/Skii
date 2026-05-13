//
//  ContentView.swift
//  Skii
//
//  Placeholder content. Replace this with the Skii game implementation.
//

import SwiftUI
import SpriteKit

struct ContentView: View {
    @State private var scene = SkiScene(size: CGSize(width: 844, height: 390))

    var body: some View {
        GeometryReader { proxy in
            SpriteView(scene: scene)
                .ignoresSafeArea()
                .onAppear {
                    scene.size = proxy.size
                }
                .onChange(of: proxy.size) { _, newSize in
                    scene.size = newSize
                }
        }
    }
}

#Preview {
    ContentView()
}
