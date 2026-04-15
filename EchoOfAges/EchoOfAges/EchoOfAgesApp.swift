// EchoOfAgesApp.swift
// EchoOfAges
//
// App entry point — bootstraps the SwiftUI lifecycle.
// ContentView is the single root view; all in-game navigation is driven by
// GameState.currentScreen rather than SwiftUI's NavigationStack.

import SwiftUI

@main
struct EchoOfAgesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
