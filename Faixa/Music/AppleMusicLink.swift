import Foundation

enum AppleMusicLink {
    private struct SearchResponse: Decodable {
        let results: [Result]
    }

    private struct Result: Decodable {
        let trackName: String
        let artistName: String
        let collectionName: String?
        let trackViewUrl: URL
    }

    static func url(for track: Track) async -> URL? {
        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: "\(track.artist) \(track.title)"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "country", value: Locale.current.region?.identifier.lowercased() ?? "us"),
        ]
        guard let searchURL = components?.url,
              let (data, _) = try? await URLSession.shared.data(from: searchURL),
              let response = try? JSONDecoder().decode(SearchResponse.self, from: data)
        else { return nil }

        let matchesTrack = { (result: Result) in
            result.trackName.localizedCaseInsensitiveCompare(track.title) == .orderedSame
                && result.artistName.localizedCaseInsensitiveContains(track.artist)
        }
        let best = response.results.first { matchesTrack($0) && $0.collectionName == track.album }
            ?? response.results.first(where: matchesTrack)
            ?? response.results.first

        return best.map { withoutTrackingParameter($0.trackViewUrl) }
    }

    private static func withoutTrackingParameter(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        components.queryItems = components.queryItems?.filter { $0.name != "uo" }
        return components.url ?? url
    }
}
