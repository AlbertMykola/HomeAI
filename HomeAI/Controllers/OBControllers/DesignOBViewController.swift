import UIKit

private struct Defaults {
    struct Text {
        static let headline = "INSPIRE.DESIGN.TRANSFORM".localized
        static let description = "Explore a world of stunning interior and exterior ideas, and bring them into your own designs.".localized
        static let next = "Next".localized
    }
    
    struct Color {
        static let shadow = UIColor(red: 168 / 255, green: 165 / 255, blue: 174 / 255, alpha: 0.75)
    }
}

class DesignOBViewController: UIViewController, OBPageChild  {

    weak var obDelegate: OBPageChildDelegate?

    @IBOutlet weak private var nextButton: UIButton!
    
    @IBOutlet weak private var descriptionLabel: UILabel!
    @IBOutlet weak private var headlineLabel: UILabel!
    
    @IBOutlet weak private var blurContainerView: FigmaLayerBlurView!
    @IBOutlet weak private var caruselContainerView: UIView!
    
    private let vignette = CAGradientLayer()

        
    private var engine: CarouselEngine<UIImage, PremiumCollectionCell>?

    override func viewDidLoad() {
        super.viewDidLoad()
        config()
        AmplitudeService.shared.logEvent(.showOBDesigns)
    }

    
    private func config() {
        headlineLabel.text = Defaults.Text.headline
        descriptionLabel.text = Defaults.Text.description
        nextButton.setTitle(Defaults.Text.next, for: .normal)
        
        configTopCarusel()
    }
    
    private func configTopCarusel() {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: .init())
        cv.translatesAutoresizingMaskIntoConstraints = false
        caruselContainerView.addSubview(cv)
        NSLayoutConstraint.activate([
            cv.topAnchor.constraint(equalTo: caruselContainerView.topAnchor),
            cv.leadingAnchor.constraint(equalTo: caruselContainerView.leadingAnchor),
            cv.trailingAnchor.constraint(equalTo: caruselContainerView.trailingAnchor),
            cv.bottomAnchor.constraint(equalTo: caruselContainerView.bottomAnchor)
        ])

        let reg = UICollectionView.CellRegistration<PremiumCollectionCell, UIImage>(
            cellNib: UINib(nibName: "PremiumCollectionCell", bundle: nil)
        ) { cell, _, image in
            cell.configure(image: image)
        }

        let layoutCfg = CarouselLayoutConfig(
            itemSize: CGSize(width: CGFloat(200).scaledByHeight(), height: CGFloat(130).scaledByHeight()),
            itemContentInsets: .init(top: 0, leading: 6, bottom: 0, trailing: 6),
            sectionInsets: .init(top: 0, leading: 16, bottom: 0, trailing: 16),
            interGroupSpacing: 0,
            groupHeight: CGFloat(130).scaledByHeight(),
            orthogonalBehavior: .continuous,
            repeatFactor: 7,
            pixelsPerSecond: 30
        )

        let rawRows: [[UIImage]] = [
            [UIImage(named:"carusel_1_image")!, UIImage(named:"carusel_2_image")!, UIImage(named:"carusel_3_image")!, UIImage(named:"carusel_4_image")!, UIImage(named:"carusel_5_image")!, UIImage(named:"carusel_6_image")!, UIImage(named:"carusel_7_image")!, UIImage(named:"carusel_8_image")!, UIImage(named:"carusel_9_image")!, UIImage(named:"carusel_10_image")!, UIImage(named:"carusel_11_image")!, UIImage(named:"carusel_12_image")!, UIImage(named:"carusel_13_image")!, UIImage(named:"carusel_14_image")!, UIImage(named:"carusel_15_image")!],
            [UIImage(named:"carusel_7_image")!, UIImage(named:"carusel_8_image")!, UIImage(named:"carusel_7_image")!, UIImage(named:"carusel_8_image")!, UIImage(named:"carusel_1_image")!, UIImage(named:"carusel_2_image")!, UIImage(named:"carusel_5_image")!, UIImage(named:"carusel_6_image")!, UIImage(named:"carusel_9_image")!, UIImage(named:"carusel_10_image")!, UIImage(named:"carusel_15_image")!, UIImage(named:"carusel_14_image")!, UIImage(named:"carusel_4_image")!, UIImage(named:"carusel_12_image")!, UIImage(named:"carusel_3_image")!],
            [UIImage(named:"carusel_15_image")!, UIImage(named:"carusel_14_image")!, UIImage(named:"carusel_13_image")!, UIImage(named:"carusel_12_image")!, UIImage(named:"carusel_11_image")!, UIImage(named:"carusel_10_image")!, UIImage(named:"carusel_9_image")!, UIImage(named:"carusel_8_image")!, UIImage(named:"carusel_7_image")!, UIImage(named:"carusel_6_image")!, UIImage(named:"carusel_5_image")!, UIImage(named:"carusel_4_image")!, UIImage(named:"carusel_3_image")!, UIImage(named:"carusel_2_image")!, UIImage(named:"carusel_1_image")!],
        ]

        predecodeRows(rawRows) { [weak self] decodedRows in
            guard let self else { return }
            let engine = CarouselEngine<UIImage, PremiumCollectionCell>(
                collectionView: cv,
                layoutConfig: layoutCfg,
                cellRegistration: reg
            )
            self.engine = engine
            engine.configure(rows: decodedRows)
        }
    }
    
    // DesignOBViewController.swift
    private func predecodeRows(_ rows: [[UIImage]], completion: @escaping ([[UIImage]]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let decoded: [[UIImage]] = rows.map { row in
                row.compactMap { img in
                    if #available(iOS 15.0, *) {
                        return img.preparingForDisplay() ?? img
                    } else {
                        let format = UIGraphicsImageRendererFormat.default()
                        format.opaque = false
                        let renderer = UIGraphicsImageRenderer(size: img.size, format: format)
                        return renderer.image { _ in img.draw(at: .zero) }
                    }
                }
            }
            DispatchQueue.main.async { completion(decoded) }
        }
    }
    
    @IBAction private func nextAction(_ sender: UIButton) {
        obDelegate?.obChildRequestsNext(self)
    }
}
