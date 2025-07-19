import ComposableArchitecture
import SwiftUI

struct ContentView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        VStack(spacing: 0) {
            headerView
                .background(Color.canvasBackground)

            Divider()

            sessionContentView
                .overlay(alignment: .bottom) {
                    if store.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.7)
                            .padding(.bottom)
                    }
                }
        }
        .frame(minWidth: 360, idealWidth: 360, maxWidth: 360, minHeight: 400, maxHeight: 700)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.canvasBackground)
        .onKeyPress(.escape) {
            if store.isLoading {
                store.send(.cancelCurrentOperation)
                return .handled
            }
            return .ignored
        }
        .onAppear {
            store.send(.onAppear)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var headerView: some View {
        HStack {
            Text("Momentum")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.secondary)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .help("Quit Momentum")
        }
        .padding(.horizontal, .momentumContainerPaddingHorizontal)
        .padding(.top, 20)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private var sessionContentView: some View {
        switch store.destination {
        case .preparation:
            if let store = store.scope(state: \.destination?.preparation, action: \.destination.preparation) {
                PreparationView(store: store)
                    .transition(.opacity)
            }

        case .activeSession:
            if let store = store.scope(state: \.destination?.activeSession, action: \.destination.activeSession) {
                ActiveSessionView(store: store)
                    .transition(.opacity)
            }

        case .reflection:
            if let store = store.scope(state: \.destination?.reflection, action: \.destination.reflection) {
                AwaitingAnalysisView(store: store)
                    .transition(.opacity)
            }

        case .analysis:
            if let store = store.scope(state: \.destination?.analysis, action: \.destination.analysis) {
                AnalysisResultView(store: store)
                    .transition(.opacity)
            }

        case nil:
            EmptyView()
        }
    }
}
