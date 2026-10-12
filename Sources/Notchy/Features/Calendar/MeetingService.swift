import Foundation

enum MeetingService {
    case zoom, meet, teams, webex, whereby, slack, other

    init(url: URL) {
        let host = (url.host ?? "").lowercased()
        let full = url.absoluteString.lowercased()
        if host.contains("zoom.us") { self = .zoom }
        else if host.contains("meet.google.com") { self = .meet }
        else if host.contains("teams.microsoft.com") || host.contains("teams.live.com") { self = .teams }
        else if host.contains("webex.com") { self = .webex }
        else if host.contains("whereby.com") { self = .whereby }
        else if full.contains("slack.com/huddle") { self = .slack }
        else { self = .other }
    }

    var label: String {
        switch self {
        case .zoom: "Zoom"
        case .meet: "Meet"
        case .teams: "Teams"
        case .webex: "Webex"
        case .whereby: "Whereby"
        case .slack: "Huddle"
        case .other: "Join"
        }
    }
}
