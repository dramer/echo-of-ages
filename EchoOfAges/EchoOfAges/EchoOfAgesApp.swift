//
//  EchoOfAgesApp.swift
//  EchoOfAges
//
//  Created by David Ramer on 4/2/26.
//

import SwiftUI

@main
struct EchoOfAgesApp: App {
    @State private var splashDone = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()

                if !splashDone {
                    SplashView {
                        withAnimation(.easeOut(duration: 0.5)) {
                            splashDone = true
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
    }
}
