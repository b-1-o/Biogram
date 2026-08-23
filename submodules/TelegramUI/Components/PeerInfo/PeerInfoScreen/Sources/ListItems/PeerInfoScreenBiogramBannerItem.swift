import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramPresentationData

final class PeerInfoScreenBiogramBannerItem: PeerInfoScreenItem {
    let id: AnyHashable
    let image: UIImage?
    let height: CGFloat
    
    init(id: AnyHashable, image: UIImage?, height: CGFloat = 140.0) {
        self.id = id
        self.image = image
        self.height = height
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
        
        // scaleAspectFill + clipsToBounds = простой center-crop
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
        let bannerHeight = item.height
        
        imageNode.image = item.image
        
        transition.updateFrame(
            node: imageNode,
            frame: CGRect(x: sideInset, y: topInset, width: bannerWidth, height: bannerHeight)
        )
        
        let height = topInset + bannerHeight + bottomInset
        
        // разделитель
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
        
        // скругления как у остальных блоков
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
