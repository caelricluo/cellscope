import SwiftUI

@main struct cellscopeApp: App {
    @StateObject private var model = CounterModel()
    var body: some Scene {
        WindowGroup { ContentView().environmentObject(model).tint(Palette.green) }
    }
}
