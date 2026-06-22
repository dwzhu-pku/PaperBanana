import Foundation

final class NativeProviderProgressRelay<Store: AnyObject>: @unchecked Sendable {
    private weak var store: Store?
    private let applyProgress: @MainActor (Store, ProviderProgressEvent) -> Void

    init(
        store: Store,
        applyProgress: @escaping @MainActor (Store, ProviderProgressEvent) -> Void
    ) {
        self.store = store
        self.applyProgress = applyProgress
    }

    func handle(_ event: ProviderProgressEvent) {
        Task { @MainActor in
            guard let store else { return }
            applyProgress(store, event)
        }
    }
}
