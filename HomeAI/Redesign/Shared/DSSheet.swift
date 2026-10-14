import UIKit

/// Bottom sheets of the redesign: system sheet, grabber, 38 pt corners, height fitted to the XIB content.
enum DSSheet {

    static func present(_ vc: UIViewController, from presenter: UIViewController, height: CGFloat? = nil,
                        large: Bool = false) {
        vc.modalPresentationStyle = .pageSheet
        if let sheet = vc.sheetPresentationController {
            if large {
                sheet.detents = [.large()]
            } else if #available(iOS 16.0, *), let height {
                sheet.detents = [.custom { _ in height }]
            } else {
                sheet.detents = [.medium(), .large()]
            }
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 38
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        presenter.present(vc, animated: true)
    }

    /// Height the XIB content needs at the presenter's width.
    static func fittingHeight(of vc: UIViewController, width: CGFloat) -> CGFloat {
        vc.loadViewIfNeeded()
        let size = vc.view.systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
                                                   withHorizontalFittingPriority: .required,
                                                   verticalFittingPriority: .fittingSizeLevel)
        return size.height
    }
}
