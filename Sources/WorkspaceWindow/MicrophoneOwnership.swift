import Foundation
import WebKit

// One physical microphone owner per native app, across saved stack origins.
// This object exchanges lifecycle acknowledgements only, never speech or credentials.
final class MicrophoneOwnership {
    private(set) weak var owner: WorkspaceWebView?
    private var transfer: UUID?
    // The shared recorder owns a 150-second queue drain; leave room for WebKit's hardware acknowledgement.
    var deadline: TimeInterval = 165
    var isTransferring: Bool { transfer != nil }

    func admitPermission(_ view: WorkspaceWebView) -> Bool {
        guard transfer == nil, owner == nil || owner === view else { return false }
        owner = view
        return true
    }

    // Composer focus may move an existing recording, never turn on an idle Mac.
    // Server preferences cannot answer this across different stack origins.
    func claimIfActive(_ view: WorkspaceWebView, completion: @escaping (Bool, String?) -> Void) {
        guard let previous = owner, previous !== view, previous.microphoneCaptureState != .none else {
            completion(false, nil); return
        }
        claim(view) { error in completion(error == nil, error) }
    }

    func claim(_ view: WorkspaceWebView, completion: @escaping (String?) -> Void) {
        guard transfer == nil else { completion("Another microphone transfer is finishing. Try again when it completes."); return }
        guard let previous = owner, previous !== view else { owner = view; completion(nil); return }
        let id = UUID(), origin = view.workspaceOrigin
        transfer = id
        let finish: (String?) -> Void = { [weak self, weak view] error in
            guard let self, self.transfer == id else { return }
            self.transfer = nil
            guard error == nil else { completion(error); return }
            guard let view, let origin, view.workspaceOrigin == origin,
                  let url = view.url, WorkspaceAddress.sameOrigin(url, origin) else {
                completion("The requesting window navigated or closed during microphone transfer."); return
            }
            self.owner = view
            completion(nil)
        }
        let timeout = DispatchWorkItem { finish("Microphone transfer timed out while finishing the other window’s recording. No new recording was started. Retry from the microphone.") }
        DispatchQueue.main.asyncAfter(deadline: .now() + deadline, execute: timeout)
        previous.callAsyncJavaScript("""
            if (typeof window.VoiceFeedClient?.releaseForNativeTransfer !== 'function')
                throw new Error('Reload the other FairyStack window before transferring its microphone.');
            await window.VoiceFeedClient.releaseForNativeTransfer();
            return true;
            """, arguments: [:], in: nil, in: .page) { [weak self, weak previous] result in
            guard let self, self.transfer == id else { return }
            switch result {
            case .failure(let error):
                timeout.cancel(); finish("Could not finish the other window’s microphone: \(error.localizedDescription)")
            case .success(let value):
                guard value as? Bool == true, let previous else {
                    timeout.cancel(); finish("The previous microphone window disappeared before acknowledging its recording stopped."); return
                }
                // WebKit's stop acknowledgement is the hardware barrier. Never
                // use .active to override WebKit/system privacy muting.
                previous.setMicrophoneCaptureState(.none) {
                    timeout.cancel(); finish(nil)
                }
            }
        }
    }
}
