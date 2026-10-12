import AppKit
import SwiftUI

struct ShelfShareTarget: Identifiable {
    let id: String
    let title: String
    let image: NSImage
    let service: NSSharingService
}

extension ShelfStore {
    func airDrop(_ targets: [ShelfItem]) { airDrop(targets.map(\.url)) }

    func airDrop(_ urls: [URL]) {
        guard let service = NSSharingService(named: .sendViaAirDrop) else { return }
        let items = urls as [Any]
        guard service.canPerform(withItems: items) else { return }
        service.perform(withItems: items)
    }

    func shareTargets(for targets: [ShelfItem]) -> [ShelfShareTarget] {
        let urls = targets.map(\.url) as [Any]
        return NSSharingService.sharingServices(forItems: urls)
            .filter { $0.title != NSSharingService(named: .sendViaAirDrop)?.title }
            .map { ShelfShareTarget(id: $0.title, title: $0.title, image: $0.image, service: $0) }
    }

    func share(_ targets: [ShelfItem], with target: ShelfShareTarget) {
        target.service.perform(withItems: targets.map(\.url) as [Any])
    }
}

struct ShelfShareMenuItems: View {
    @ObservedObject var shelf: ShelfStore
    let targets: [ShelfItem]

    var body: some View {
        Button("AirDrop…") { shelf.airDrop(targets) }
        Divider()
        ForEach(shelf.shareTargets(for: targets)) { target in
            Button { shelf.share(targets, with: target) } label: {
                Label { Text(target.title) } icon: { Image(nsImage: target.image) }
            }
        }
    }
}
