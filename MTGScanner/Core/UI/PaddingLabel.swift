//
//  PaddingLabel.swift
//  TcgScanner
//
//  Created by Joel James on 04/07/2026.
//

import Foundation
import UIKit

final class PaddingLabel: UILabel {

    var contentInsets = UIEdgeInsets(
        top: 3,
        left: 8,
        bottom: 3,
        right: 8
    )

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInsets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize

        return CGSize(
            width: size.width + contentInsets.left + contentInsets.right,
            height: size.height + contentInsets.top + contentInsets.bottom
        )
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let fitted = super.sizeThatFits(size)

        return CGSize(
            width: fitted.width + contentInsets.left + contentInsets.right,
            height: fitted.height + contentInsets.top + contentInsets.bottom
        )
    }
}
