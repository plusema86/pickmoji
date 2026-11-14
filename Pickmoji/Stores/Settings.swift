import Foundation
import OSLog
import ServiceManagement

final class Settings: ObservableObject {
    static let skinToneKey = "defaultSkinTone"

    @Published var defaultSkinTone: SkinTone {
        didSet { defaults.set(defaultSkinTone.rawValue, forKey: Self.skinToneKey) }
    }

    @Published private(set) var launchAtLogin: Bool
    @Published var launchAtLoginError: String?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaultSkinTone = SkinTone(rawValue: defaults.integer(forKey: Self.skinToneKey)) ?? .none
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            launchAtLoginError = nil
        } catch {
            Logger().error("Impossibile modificare l’apertura al login. \(error.localizedDescription)")
            launchAtLoginError = enabled
                ? "Impossibile attivare l’apertura al login. Controlla gli elementi login nelle Impostazioni di Sistema."
                : "Impossibile disattivare l’apertura al login. Controlla gli elementi login nelle Impostazioni di Sistema."
        }
        launchAtLogin = service.status == .enabled
    }
}
