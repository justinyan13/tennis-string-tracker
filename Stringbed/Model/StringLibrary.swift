import Foundation

/// The starter string library. Prices are ballpark US street prices for a set and
/// are meant to be edited — cost-per-hour in the Lab is only as good as these.
enum StringLibrary {
    static func defaults() -> [StringSpec] {
        [
            StringSpec(brand: "Luxilon", model: "ALU Power", material: .polyester,
                       gauge: 1.25, colorHex: "B7BDC6", pricePerSet: 19, isFavorite: true),
            StringSpec(brand: "Babolat", model: "RPM Blast", material: .polyester,
                       gauge: 1.25, colorHex: "23262B", pricePerSet: 17),
            StringSpec(brand: "Solinco", model: "Hyper-G", material: .polyester,
                       gauge: 1.20, colorHex: "3EA34C", pricePerSet: 14, isFavorite: true),
            StringSpec(brand: "Solinco", model: "Tour Bite", material: .polyester,
                       gauge: 1.25, colorHex: "8C9299", pricePerSet: 14),
            StringSpec(brand: "Head", model: "Lynx Tour", material: .polyester,
                       gauge: 1.25, colorHex: "C7A96A", pricePerSet: 13),
            StringSpec(brand: "Yonex", model: "Poly Tour Pro", material: .polyester,
                       gauge: 1.25, colorHex: "2E5FD1", pricePerSet: 13),
            StringSpec(brand: "Wilson", model: "NXT", material: .multifilament,
                       gauge: 1.30, colorHex: "EDE4D2", pricePerSet: 18),
            StringSpec(brand: "Tecnifibre", model: "X-One Biphase", material: .multifilament,
                       gauge: 1.24, colorHex: "C0392B", pricePerSet: 22),
            StringSpec(brand: "Babolat", model: "VS Touch", material: .naturalGut,
                       gauge: 1.30, colorHex: "F1DFBB", pricePerSet: 45),
            StringSpec(brand: "Wilson", model: "Natural Gut", material: .naturalGut,
                       gauge: 1.30, colorHex: "EEDBB2", pricePerSet: 42),
            StringSpec(brand: "Prince", model: "Synthetic Gut Duraflex", material: .syntheticGut,
                       gauge: 1.30, colorHex: "E7EAEF", pricePerSet: 8),
            StringSpec(brand: "Ashaway", model: "Kevlar 17", material: .kevlar,
                       gauge: 1.20, colorHex: "D8C46A", pricePerSet: 12),
        ]
    }

    /// Colours offered when adding a string by hand.
    static let swatches = [
        "B7BDC6", "23262B", "3EA34C", "C7A96A", "2E5FD1", "C0392B",
        "F1DFBB", "E7EAEF", "D4FF3E", "E2703A", "9B59B6", "16A6A6",
    ]
}
