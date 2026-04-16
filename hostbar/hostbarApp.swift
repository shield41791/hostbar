import SwiftUI

@main
struct HostBarApp: App {
    @State private var viewModel = HostsViewModel()

    var body: some Scene {
        MenuBarExtra("HostBar", systemImage: "server.rack") {
            MenuBarView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
