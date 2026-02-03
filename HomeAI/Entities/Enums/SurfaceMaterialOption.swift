import Foundation

/// Options shown in `SurfaceMaterialPickerViewController` for `.newFlooring` / `.newWalls`.
///
/// NOTE: `imageName` should match an asset name (e.g. in `Assets.xcassets`).
enum SurfaceMaterialOption: CaseIterable, Hashable {
    
    enum Placement: Hashable {
        case floor
        case wall
    }
    
    // MARK: - Floor
    case naturalOak
    case bleachedOak
    case smokedOak
    case parquet
    case chevron
    case americanWalnut
    case greyOak
    case widePlank
    case quartzVinyl
    case ash
    case matteAnthracite
    case modularParquet
    case whiteMarble
    case cementTile
    case hexagonTile
    case terrazzo
    case moroccanTile
    case anthraciteSlate
    case loopPile
    case plush
    case sisal
    
    // MARK: - Wall
    case mattePaint
    case decorativePlaster
    case exposedBrick
    case rawConcrete
    case woodSlats
    case wallMolding
    case patternedWallpaper
    case microcement
    case marbleSlab
    case fabricWallpaper
    case stoneVeneer
    case glassPanels
    case livingWall
    case corkWall
    case woodShiplap
    
    var placement: Placement {
        switch self {
        case .naturalOak, .bleachedOak, .smokedOak, .parquet, .chevron, .americanWalnut, .greyOak, .widePlank, .quartzVinyl, .ash, .matteAnthracite, .modularParquet, .whiteMarble, .cementTile, .hexagonTile, .terrazzo, .moroccanTile, .anthraciteSlate, .loopPile, .plush, .sisal:
            return .floor
        default:
            return .wall
        }
    }
    
    var title: String {
        switch self {
        // Floor
        case .naturalOak: return "Natural Oak"
        case .bleachedOak: return "Bleached Oak"
        case .smokedOak: return "Smoked Oak"
        case .parquet: return "Parquet"
        case .chevron: return "Chevron"
        case .americanWalnut: return "American Walnut"
        case .greyOak: return "Grey Oak"
        case .widePlank: return "Wide Plank"
        case .quartzVinyl: return "Quartz Vinyl"
        case .ash: return "Ash"
        case .matteAnthracite: return "Matte Anthracite"
        case .modularParquet: return "Modular Parquet"
        case .whiteMarble: return "White Marble"
        case .cementTile: return "Cement Tile"
        case .hexagonTile: return "Hexagon Tile"
        case .terrazzo: return "Terrazzo"
        case .moroccanTile: return "Moroccan Tile"
        case .anthraciteSlate: return "Anthracite Slate"
        case .loopPile: return "Loop Pile"
        case .plush: return "Plush"
        case .sisal: return "Sisal"
            
        // Wall
        case .mattePaint: return "Matte Paint"
        case .decorativePlaster: return "Decorative Plaster"
        case .exposedBrick: return "Exposed Brick"
        case .rawConcrete: return "Raw Concrete"
        case .woodSlats: return "Wood Slats"
        case .wallMolding: return "Wall Molding"
        case .patternedWallpaper: return "Patterned Wallpaper"
        case .microcement: return "Microcement"
        case .marbleSlab: return "Marble Slab"
        case .fabricWallpaper: return "Fabric Wallpaper"
        case .stoneVeneer: return "Stone Veneer"
        case .glassPanels: return "Glass Panels"
        case .livingWall: return "Living Wall"
        case .corkWall: return "Cork Wall"
        case .woodShiplap: return "Wood Shiplap"
        }
    }
    
    /// Stable, English descriptor used to build the generation prompt.
    /// Keep it short and unambiguous (independent from UI localization).
    var promptDescriptor: String {
        switch self {
        // Floor
        case .naturalOak: return "natural oak wood flooring (light oak planks)"
        case .bleachedOak: return "bleached oak wood flooring (very light oak)"
        case .smokedOak: return "smoked oak wood flooring (dark oak)"
        case .parquet: return "parquet wood flooring (classic parquet pattern)"
        case .chevron: return "chevron parquet wood flooring"
        case .americanWalnut: return "american walnut wood flooring (rich brown tone)"
        case .greyOak: return "grey oak wood flooring"
        case .widePlank: return "wide plank wood flooring"
        case .quartzVinyl: return "light grey vinyl plank flooring (quartz vinyl look)"
        case .ash: return "ash wood flooring (light, warm tone)"
        case .matteAnthracite: return "matte anthracite flooring (dark, concrete-like)"
        case .modularParquet: return "modular parquet flooring (square parquet blocks)"
        case .whiteMarble: return "white marble tile flooring"
        case .cementTile: return "cement tile flooring (smooth concrete tile)"
        case .hexagonTile: return "white hexagon tile flooring"
        case .terrazzo: return "terrazzo tile flooring"
        case .moroccanTile: return "patchwork patterned tile flooring (moroccan-style)"
        case .anthraciteSlate: return "anthracite slate tile flooring (dark stone)"
        case .loopPile: return "loop pile carpet flooring"
        case .plush: return "plush carpet flooring (soft, dense pile)"
        case .sisal: return "sisal carpet flooring (woven natural fiber)"
            
        // Wall
        case .mattePaint: return "matte painted walls (neutral solid color)"
        case .decorativePlaster: return "decorative plaster wall finish (subtle texture)"
        case .exposedBrick: return "exposed brick wall finish (red brick)"
        case .rawConcrete: return "raw concrete wall finish (industrial concrete)"
        case .woodSlats: return "vertical wood slat wall panels (dark slats)"
        case .wallMolding: return "wall molding / wainscoting panels (classic trim)"
        case .patternedWallpaper: return "patterned wallpapered walls (geometric arches pattern)"
        case .microcement: return "microcement wall finish (smooth minimal texture)"
        case .marbleSlab: return "white marble slab wall finish (large marble panels)"
        case .fabricWallpaper: return "fabric wallpapered walls (textile texture)"
        case .stoneVeneer: return "stacked stone veneer wall finish (light stone)"
        case .glassPanels: return "ribbed glass wall panels (vertical fluted glass)"
        case .livingWall: return "living green wall (vertical garden plants)"
        case .corkWall: return "cork wall panels (natural cork texture)"
        case .woodShiplap: return "wood shiplap wall panels (natural wood boards)"
        }
    }
    
    var imageName: String {
        switch self {
        // Supabase public bucket: Images/walls_image/*.webp
        case .mattePaint: return "walls_image/wall_matte_paint_image.webp"
        case .decorativePlaster: return "walls_image/wall_decorative_plaster_image.webp"
        case .exposedBrick: return "walls_image/wall_exposed_brick_image.webp"
        case .rawConcrete: return "walls_image/wall_raw_concrete_image.webp"
        case .woodSlats: return "walls_image/wall_wood_slats_image.webp"
        case .wallMolding: return "walls_image/wall_wall_molding_image.webp"
        case .patternedWallpaper: return "walls_image/wall_patterned_wallpaper_image.webp"
        case .microcement: return "walls_image/wall_microcement_image.webp"
        case .marbleSlab: return "walls_image/wall_marble_slabs_image.webp"
        case .fabricWallpaper: return "walls_image/wall_fabric_wallpaper_image.webp"
        case .stoneVeneer: return "walls_image/wall_stone_veneer_image.webp"
        case .glassPanels: return "walls_image/wall_glass_panels_image.webp"
        case .livingWall: return "walls_image/wall_living_wall_image.webp"
        case .corkWall: return "walls_image/wall_cork_wall_image.webp"
        case .woodShiplap: return "walls_image/wall_wood_shiplap_image.webp"
            
        // Supabase public bucket: Images/floor_images/*.webp
        case .naturalOak: return "floor_images/flooring_natural_oak_image.webp"
        case .bleachedOak: return "floor_images/flooring_bleached__oak_image.webp"
        case .smokedOak: return "floor_images/flooring_smoked_oak_image.webp"
        case .parquet: return "floor_images/flooring_parquet_image.webp"
        case .chevron: return "floor_images/flooring_chevron_image.webp"
        case .americanWalnut: return "floor_images/flooring_american_walnut_image.webp"
        case .greyOak: return "floor_images/flooring_grey_oak_image.webp"
        case .widePlank: return "floor_images/flooring_wide_plank_image.webp"
        case .quartzVinyl: return "floor_images/flooring_quartz_vinyl_image.webp"
        case .ash: return "floor_images/flooring_ash_image.webp"
        case .matteAnthracite: return "floor_images/flooring_matte_anthracite_image.webp"
        case .modularParquet: return "floor_images/flooring_modular_parquet_image.webp"
        case .whiteMarble: return "floor_images/flooring_white_marble_image.webp"
        case .cementTile: return "floor_images/flooring_cement_tile_image.webp"
        case .hexagonTile: return "floor_images/flooring_hexagon_tile_image.webp"
        case .terrazzo: return "floor_images/flooring_terrazzo_image.webp"
        case .moroccanTile: return "floor_images/flooring_patchwork_image.webp"
        case .anthraciteSlate: return "floor_images/flooring_anthracite_slate_image.webp"
        case .loopPile: return "floor_images/flooring_loop_pile_image.webp"
        case .plush: return "floor_images/floor_plush_image.webp"
        case .sisal: return "floor_images/floor_sisal_image.webp"
        }
    }
    
    static func options(for placement: Placement) -> [SurfaceMaterialOption] {
        allCases.filter { $0.placement == placement }
    }
}

