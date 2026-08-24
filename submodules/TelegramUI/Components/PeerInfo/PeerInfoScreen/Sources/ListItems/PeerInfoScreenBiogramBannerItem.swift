import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramPresentationData
import Biogram

final class PeerInfoScreenBiogramBannerItem: PeerInfoScreenItem {
    let id: AnyHashable
    let image: UIImage?
   
    init(id: AnyHashable, image: UIImage?) {
        self.id = id
        self.image = image
    }
   
    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenBiogramBannerItemNode()
    }
}

private final class PeerInfoScreenBiogramBannerItemNode: PeerInfoScreenItemNode {
    private let imageNode = ASImageNode()
    private let maskNode = ASImageNode()
    private let bottomSeparatorNode = ASDisplayNode()
   
    private var item: PeerInfoScreenBiogramBannerItem?
   
    override init() {
        super.init()
       
        // scaleAspectFill + clipsToBounds = картинка как есть, обрезка по краям при необходимости
        imageNode.contentMode = .scaleAspectFill
        imageNode.clipsToBounds = true
        imageNode.cornerRadius = 12.0
        imageNode.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        addSubnode(imageNode)
       
        maskNode.isUserInteractionEnabled = false
        addSubnode(maskNode)
       
        bottomSeparatorNode.isLayerBacked = true
        addSubnode(bottomSeparatorNode)
    }
   
    override func update(
        context: AccountContext,
        width: CGFloat,
        safeInsets: UIEdgeInsets,
        presentationData: PresentationData,
        item: PeerInfoScreenItem,
        topItem: PeerInfoScreenItem?,
        bottomItem: PeerInfoScreenItem?,
        hasCorners: Bool,
        transition: ContainedViewLayoutTransition
    ) -> CGFloat {
        guard let item = item as? PeerInfoScreenBiogramBannerItem else {
            return 10.0
        }
        self.item = item
       
        let sideInset: CGFloat = 16.0 + safeInsets.left
        let rightInset: CGFloat = 16.0 + safeInsets.right
        let topInset: CGFloat = 8.0
        let bottomInset: CGFloat = 8.0
       
        let bannerWidth = width - sideInset - rightInset
        
        // Высота от aspect ratio картинки (free), clamp 80...300
        let bannerHeight: CGFloat
        if let image = item.image, image.size.width > 0 {
            let ratio = image.size.height / image.size.width
            bannerHeight = max(80.0, min(300.0, bannerWidth * ratio))
        } else {
            bannerHeight = BiogramManager.shared.bannerHeight(forWidth: bannerWidth)
        }
       
        imageNode.image = item.image
       
        transition.updateFrame(
            node: imageNode,
            frame: CGRect(x: sideInset, y: topInset, width: bannerWidth, height: bannerHeight)
        )
       
        let height = topInset + bannerHeight + bottomInset
       
        bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        transition.updateFrame(
            node: bottomSeparatorNode,
            frame: CGRect(
                x: sideInset,
                y: height - UIScreenPixel,
                width: width - sideInset - rightInset,
                height: UIScreenPixel
            )
        )
        transition.updateAlpha(node: bottomSeparatorNode, alpha: bottomItem == nil ? 0.0 : 1.0)
       
        let hasTopCorners = hasCorners && topItem == nil
        let hasBottomCorners = hasCorners && bottomItem == nil
       
        maskNode.image = hasCorners
            ? PresentationResourcesItemList.cornersImage(
                presentationData.theme,
                top: hasTopCorners,
                bottom: hasBottomCorners,
                glass: true
              )
            : nil
       
        maskNode.frame = CGRect(
            x: safeInsets.left,
            y: 0.0,
            width: width - safeInsets.left - safeInsets.right,
            height: height
        )
       
        bottomSeparatorNode.isHidden = hasBottomCorners
       
        return height
    }
}
