import SwiftUI
import WidgetKit

// Balsm Emergency lock-screen / home-screen widget (T127).
//
// Reads a minimal, non-sensitive projection of the patient's emergency card
// from the shared App Group UserDefaults (written by the Flutter host app) and
// renders blood type + up to two allergies. No PHI is fetched over the network
// here; the widget is a passive read of locally-stored data.

private let kAppGroup = "group.health.balsm.emergency"
private let kDefaultsKey = "balsm_emergency"

struct EmergencyData {
    var bloodType: String?
    var topAllergies: [String]
    var primaryContactName: String?

    static let placeholder = EmergencyData(
        bloodType: "O+",
        topAllergies: ["Penicillin", "Peanuts"],
        primaryContactName: nil
    )

    static func load() -> EmergencyData {
        guard
            let defaults = UserDefaults(suiteName: kAppGroup),
            let raw = defaults.string(forKey: kDefaultsKey),
            let data = raw.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return EmergencyData(bloodType: nil, topAllergies: [], primaryContactName: nil)
        }
        let allergies = (json["topAllergies"] as? [String]) ?? []
        return EmergencyData(
            bloodType: json["bloodType"] as? String,
            topAllergies: Array(allergies.prefix(2)),
            primaryContactName: json["primaryContactName"] as? String
        )
    }
}

struct EmergencyEntry: TimelineEntry {
    let date: Date
    let data: EmergencyData
}

struct EmergencyProvider: TimelineProvider {
    func placeholder(in context: Context) -> EmergencyEntry {
        EmergencyEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (EmergencyEntry) -> Void) {
        completion(EmergencyEntry(date: Date(), data: EmergencyData.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EmergencyEntry>) -> Void) {
        let entry = EmergencyEntry(date: Date(), data: EmergencyData.load())
        // Refresh hourly; the host app also reloads timelines on profile change.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct EmergencyWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: EmergencyProvider.Entry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Emergency")
                    .font(.caption2).bold()
                Text(entry.data.bloodType ?? "—")
                    .font(.headline)
                if let first = entry.data.topAllergies.first {
                    Text(first).font(.caption2).lineLimit(1)
                }
            }
        default: // systemSmall
            VStack(alignment: .leading, spacing: 6) {
                Label("Emergency", systemImage: "cross.case.fill")
                    .font(.caption).bold()
                    .foregroundColor(.red)
                Text(entry.data.bloodType ?? "—")
                    .font(.system(size: 28, weight: .bold))
                ForEach(entry.data.topAllergies.prefix(2), id: \.self) { allergy in
                    Text("• \(allergy)")
                        .font(.caption2)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

struct EmergencyWidget: Widget {
    let kind = "EmergencyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EmergencyProvider()) { entry in
            EmergencyWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Emergency Card")
        .description("Blood type and key allergies for first responders.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

@main
struct EmergencyWidgetBundle: WidgetBundle {
    var body: some Widget {
        EmergencyWidget()
    }
}
