import Foundation
import Observation
import SwiftUI

enum AppColorway: String, CaseIterable, Identifiable, Codable {
    case verdant
    case vermilion
    case blueHour = "blue-hour"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .verdant: "Verdant"
        case .vermilion: "Vermilion"
        case .blueHour: "Blue Hour"
        }
    }

    var detail: String {
        switch self {
        case .verdant: "Sage, forest, chalk"
        case .vermilion: "Red, ivory, charcoal"
        case .blueHour: "Slate, ink, ice"
        }
    }

    /// The website's labeled swatches are intentionally lighting-independent.
    var swatches: [Color] {
        let values: [UInt]
        switch self {
        case .verdant: values = [0xD5E2CA, 0x294435, 0xF5F8EF]
        case .vermilion: values = [0xA22F29, 0xF8F1E3, 0x25211E]
        case .blueHour: values = [0xCFDCE8, 0x263E5C, 0xF4F8FC]
        }
        return values.map { value in
            Color(red: Double((value >> 16) & 255) / 255,
                  green: Double((value >> 8) & 255) / 255,
                  blue: Double(value & 255) / 255)
        }
    }
}

enum AppLighting: String, CaseIterable, Identifiable, Codable {
    case system, light, dark

    var id: String { rawValue }

    var name: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// One device preference shared by every scene, including account sheets.
/// Observation also tracks reads made through Palette's computed properties,
/// allowing existing views to recolor without rebuilding their navigation state.
@Observable
final class AppAppearance {
    static let shared = AppAppearance()
    static let colorwayStorageKey = "plurifold-colorway"
    static let lightingStorageKey = "plurifold-lighting"

    @ObservationIgnored private let defaults: UserDefaults

    var colorway: AppColorway {
        didSet {
            if colorway != oldValue { defaults.set(colorway.rawValue, forKey: Self.colorwayStorageKey) }
        }
    }

    var lighting: AppLighting {
        didSet {
            if lighting != oldValue { defaults.set(lighting.rawValue, forKey: Self.lightingStorageKey) }
        }
    }

    var preferredColorScheme: ColorScheme? { lighting.colorScheme }
    var revisionID: String { "\(colorway.rawValue):\(lighting.rawValue)" }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // No earlier native release stored a palette preference. Match the
        // website's Verdant default until a person explicitly chooses another.
        colorway = defaults.string(forKey: Self.colorwayStorageKey).flatMap(AppColorway.init(rawValue:)) ?? .verdant
        lighting = defaults.string(forKey: Self.lightingStorageKey).flatMap(AppLighting.init(rawValue:)) ?? .system
    }
}
