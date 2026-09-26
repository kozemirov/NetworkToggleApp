import AppIntents
import WidgetKit

// A "network service" entity the user picks when configuring the Control.

struct ServiceEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Network Service"
    static var defaultQuery = ServiceQuery()

    var id: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id)")
    }
}

struct ServiceQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ServiceEntity] {
        identifiers.map { ServiceEntity(id: $0) }
    }
    func suggestedEntities() async throws -> [ServiceEntity] {
        SnapshotStore.load().map { ServiceEntity(id: $0.name) }
    }
    func defaultResult() async -> ServiceEntity? {
        SnapshotStore.load().first.map { ServiceEntity(id: $0.name) }
    }
}

// Control configuration (which service to show)
struct ServiceConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "Network Service"

    @Parameter(title: "Service")
    var service: ServiceEntity?
}

// Toggle action
struct ToggleServiceIntent: SetValueIntent {
    static var title: LocalizedStringResource = "Turn a network service on or off"

    @Parameter(title: "Service")
    var service: ServiceEntity

    @Parameter(title: "Enabled")
    var value: Bool

    init() {}
    init(service: ServiceEntity) { self.service = service }

    func perform() async throws -> some IntentResult {
        try await HelperClient.setEnabled(service.id, enabled: value)
        SnapshotStore.patchEnabled(name: service.id, enabled: value)
        return .result()
    }
}
