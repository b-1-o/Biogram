import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import PresentationDataUtils
import Biogram

// MARK: - Helpers

private final class BiogramActionsAlertController: ViewController {
    private let titleText: String
    private let messageText: String?
    private let actions: [(title: String, destructive: Bool, action: () -> Void)]
    
    init(title: String, message: String?, actions: [(title: String, destructive: Bool, action: () -> Void)]) {
        self.titleText = title
        self.messageText = message
        self.actions = actions
        super.init(navigationBarPresentationData: nil)
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required init(coder aDecoder: NSCoder) { fatalError() }
    
    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNode.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        
        let alert = UIAlertController(title: titleText, message: messageText, preferredStyle: .actionSheet)
        for item in actions {
            alert.addAction(UIAlertAction(title: item.title, style: item.destructive ? .destructive : .default, handler: { [weak self] _ in
                item.action()
                self?.close()
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { [weak self] _ in
            self?.close()
        }))
        
        Queue.mainQueue().after(0.05) { [weak self] in
            guard let self = self else { return }
            guard let root = self.view.window?.rootViewController else { return }
            var top: UIViewController = root
            while let presented = top.presentedViewController { top = presented }
            if let pop = alert.popoverPresentationController {
                pop.sourceView = top.view
                pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 1, height: 1)
                pop.permittedArrowDirections = []
            }
            top.present(alert, animated: true)
        }
    }
    
    private func close() { self.dismiss(animated: false) }
}

private final class BiogramTextInputController: ViewController {
    private let titleText: String
    private let messageText: String
    private let initialValue: String
    private let placeholder: String
    private let actionTitle: String
    private let cancelTitle: String
    private let keyboardType: UIKeyboardType
    private let onAction: (String) -> Bool
    private var textField: UITextField?
    
    init(title: String, text: String, value: String, placeholder: String, actionTitle: String, cancelTitle: String, keyboardType: UIKeyboardType = .default, action: @escaping (String) -> Bool) {
        self.titleText = title
        self.messageText = text
        self.initialValue = value
        self.placeholder = placeholder
        self.actionTitle = actionTitle
        self.cancelTitle = cancelTitle
        self.keyboardType = keyboardType
        self.onAction = action
        super.init(navigationBarPresentationData: nil)
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required init(coder aDecoder: NSCoder) { fatalError() }
    
    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNode.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        
        let alert = UIAlertController(title: titleText, message: messageText, preferredStyle: .alert)
        alert.addTextField { [weak self] tf in
            guard let self = self else { return }
            tf.text = self.initialValue
            tf.placeholder = self.placeholder
            tf.keyboardType = self.keyboardType
            tf.autocapitalizationType = .none
            tf.autocorrectionType = .no
            self.textField = tf
        }
        alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel, handler: { [weak self] _ in self?.close() }))
        alert.addAction(UIAlertAction(title: actionTitle, style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            if self.onAction(self.textField?.text ?? "") { self.close() }
        }))
        
        Queue.mainQueue().after(0.05) { [weak self] in
            guard let self = self else { return }
            guard let root = self.view.window?.rootViewController else { return }
            var top: UIViewController = root
            while let presented = top.presentedViewController { top = presented }
            top.present(alert, animated: true)
        }
    }
    
    private func close() { self.dismiss(animated: false) }
}

private func biogramPrompt(
    title: String, text: String, value: String, placeholder: String,
    actionTitle: String, cancelTitle: String, keyboardType: UIKeyboardType = .default,
    action: @escaping (String) -> Bool
) -> ViewController {
    return BiogramTextInputController(
        title: title, text: text, value: value, placeholder: placeholder,
        actionTitle: actionTitle, cancelTitle: cancelTitle, keyboardType: keyboardType, action: action
    )
}

// MARK: - Gallery picker

private final class BannerPickerDelegate: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    static let shared = BannerPickerDelegate()
    var onPicked: ((UIImage?) -> Void)?
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
        onPicked?(image)
        picker.dismiss(animated: true)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

private final class PickerWrapper: ViewController {
    private let picker: UIImagePickerController
    
    init(picker: UIImagePickerController) {
        self.picker = picker
        super.init(navigationBarPresentationData: nil)
        statusBar.statusBarStyle = .Ignore
    }
    
    required init(coder: NSCoder) { fatalError() }
    
    override func loadDisplayNode() {
        displayNode = ASDisplayNode()
        displayNode.backgroundColor = .clear
        Queue.mainQueue().after(0.05) { [weak self] in
            guard let self, let root = self.view.window?.rootViewController else { return }
            var top = root
            while let p = top.presentedViewController { top = p }
            top.present(self.picker, animated: true)
        }
    }
}

// MARK: - Sections / State / Entries

private enum BiogramSection: Int32 {
    case premium = 0
    case numbers = 1
    case aliases = 2
    case color = 3
    case collectibles = 4
    case banner = 5
    case info = 6
}

private final class BiogramControllerState: Equatable {
    let premiumEnabled: Bool
    let numbers: [BiogramVirtualNumber]
    let aliases: [String]
    let collectibles: [BiogramCollectible]
    let profileColorEnabled: Bool
    let profileColor: BiogramProfileColor?
    let hasBanner: Bool
    let bannerHeight: CGFloat
    
    init(
        premiumEnabled: Bool,
        numbers: [BiogramVirtualNumber],
        aliases: [String],
        collectibles: [BiogramCollectible],
        profileColorEnabled: Bool,
        profileColor: BiogramProfileColor?,
        hasBanner: Bool,
        bannerHeight: CGFloat
    ) {
        self.premiumEnabled = premiumEnabled
        self.numbers = numbers
        self.aliases = aliases
        self.collectibles = collectibles
        self.profileColorEnabled = profileColorEnabled
        self.profileColor = profileColor
        self.hasBanner = hasBanner
        self.bannerHeight = bannerHeight
    }
    
    static func == (lhs: BiogramControllerState, rhs: BiogramControllerState) -> Bool {
        return lhs.premiumEnabled == rhs.premiumEnabled
            && lhs.numbers == rhs.numbers
            && lhs.aliases == rhs.aliases
            && lhs.collectibles == rhs.collectibles
            && lhs.profileColorEnabled == rhs.profileColorEnabled
            && lhs.profileColor == rhs.profileColor
            && lhs.hasBanner == rhs.hasBanner
            && lhs.bannerHeight == rhs.bannerHeight
    }
    
    static func current() -> BiogramControllerState {
        return BiogramControllerState(
            premiumEnabled: BiogramManager.shared.localPremiumEnabled,
            numbers: BiogramManager.shared.virtualNumbers(),
            aliases: BiogramManager.shared.aliases(),
            collectibles: BiogramManager.shared.collectibles(),
            profileColorEnabled: BiogramManager.shared.profileColorEnabled,
            profileColor: BiogramManager.shared.profileColor,
            hasBanner: BiogramManager.shared.bannerImage() != nil,
            bannerHeight: BiogramManager.shared.bannerHeight
        )
    }
}

private enum BiogramEntryId: Hashable {
    case premiumHeader, premiumToggle
    case numbersHeader, number(String), addNumber
    case aliasesHeader, alias(String), addAlias
    case colorHeader, colorToggle, colorPreset(String), colorBrightness
    case collectiblesHeader, collectible(String), addGiftFromLink
    case bannerHeader, bannerPreview, bannerHeight, chooseBanner, removeBanner
    case info
}

private enum BiogramEntry: ItemListNodeEntry {
    case premiumHeader
    case premiumToggle(Bool)
    case numbersHeader
    case number(Int, BiogramVirtualNumber)
    case addNumber
    case aliasesHeader
    case alias(Int, String)
    case addAlias
    case colorHeader
    case colorToggle(Bool)
    case colorPreset(String, BiogramProfileColor, Bool)
    case colorBrightness(Double)
    case collectiblesHeader
    case collectible(Int, BiogramCollectible)
    case addGiftFromLink
    case bannerHeader
    case bannerPreview(Bool)
    case bannerHeight(CGFloat)
    case chooseBanner
    case removeBanner
    case info
    
    var section: ItemListSectionId {
        switch self {
        case .premiumHeader, .premiumToggle: return BiogramSection.premium.rawValue
        case .numbersHeader, .number, .addNumber: return BiogramSection.numbers.rawValue
        case .aliasesHeader, .alias, .addAlias: return BiogramSection.aliases.rawValue
        case .colorHeader, .colorToggle, .colorPreset, .colorBrightness: return BiogramSection.color.rawValue
        case .collectiblesHeader, .collectible, .addGiftFromLink: return BiogramSection.collectibles.rawValue
        case .bannerHeader, .bannerPreview, .bannerHeight, .chooseBanner, .removeBanner: return BiogramSection.banner.rawValue
        case .info: return BiogramSection.info.rawValue
        }
    }
    
    var stableId: BiogramEntryId {
        switch self {
        case .premiumHeader: return .premiumHeader
        case .premiumToggle: return .premiumToggle
        case .numbersHeader: return .numbersHeader
        case let .number(_, n): return .number(n.id)
        case .addNumber: return .addNumber
        case .aliasesHeader: return .aliasesHeader
        case let .alias(_, a): return .alias(a)
        case .addAlias: return .addAlias
        case .colorHeader: return .colorHeader
        case .colorToggle: return .colorToggle
        case let .colorPreset(name, _, _): return .colorPreset(name)
        case .colorBrightness: return .colorBrightness
        case .collectiblesHeader: return .collectiblesHeader
        case let .collectible(_, c): return .collectible(c.id)
        case .addGiftFromLink: return .addGiftFromLink
        case .bannerHeader: return .bannerHeader
        case .bannerPreview: return .bannerPreview
        case .bannerHeight: return .bannerHeight
        case .chooseBanner: return .chooseBanner
        case .removeBanner: return .removeBanner
        case .info: return .info
        }
    }
    
    static func < (lhs: BiogramEntry, rhs: BiogramEntry) -> Bool {
        if lhs.section != rhs.section { return lhs.section < rhs.section }
        return false
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! BiogramArguments
        switch self {
        case .premiumHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "LOCAL PREMIUM", sectionId: self.section)
        case let .premiumToggle(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Local Premium", value: value, sectionId: self.section, style: .blocks, updated: { arguments.togglePremium($0) })
        case .numbersHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "VIRTUAL / ANONYMOUS NUMBERS", sectionId: self.section)
        case let .number(_, number):
            let title = number.label ?? number.number
            let label = number.label != nil ? number.number : "Tap to edit / remove"
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: label, sectionId: self.section, style: .blocks, action: { arguments.editOrRemoveNumber(number) })
        case .addNumber:
            return ItemListActionItem(presentationData: presentationData, title: "Add Number", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: { arguments.addNumber() })
        case .aliasesHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ALIASES / USERNAMES", sectionId: self.section)
        case let .alias(_, alias):
            return ItemListDisclosureItem(presentationData: presentationData, title: "@\(alias)", label: "Tap to edit / remove", sectionId: self.section, style: .blocks, action: { arguments.editOrRemoveAlias(alias) })
        case .addAlias:
            return ItemListActionItem(presentationData: presentationData, title: "Add Alias", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: { arguments.addAlias() })
        case .colorHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "PROFILE COLOR", sectionId: self.section)
        case let .colorToggle(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Custom profile color", value: value, sectionId: self.section, style: .blocks, updated: { arguments.toggleColor($0) })
        case let .colorPreset(name, color, selected):
            return ItemListDisclosureItem(presentationData: presentationData, title: name, label: selected ? "✓" : "", sectionId: self.section, style: .blocks, action: { arguments.selectPreset(color) })
        case let .colorBrightness(value):
            return ItemListDisclosureItem(presentationData: presentationData, title: "Brightness", label: "\(Int((value * 100).rounded()))%", sectionId: self.section, style: .blocks, action: { arguments.pickBrightness() })
        case .collectiblesHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "COLLECTIBLES / GIFTS", sectionId: self.section)
        case let .collectible(_, item):
            let title = item.title ?? item.giftSlug ?? item.id
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: "Tap to remove", sectionId: self.section, style: .blocks, action: { arguments.removeCollectible(item.id) })
        case .addGiftFromLink:
            return ItemListActionItem(presentationData: presentationData, title: "Add Gift by Link", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: { arguments.addGiftFromLink() })
        case .bannerHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "PROFILE BANNER", sectionId: self.section)
        case let .bannerPreview(hasImage):
            return ItemListDisclosureItem(presentationData: presentationData, title: "Current banner", label: hasImage ? "Set" : "Not set", sectionId: self.section, style: .blocks, action: nil)
        case let .bannerHeight(value):
            return ItemListDisclosureItem(presentationData: presentationData, title: "Height", label: "\(Int(value)) pt", sectionId: self.section, style: .blocks, action: { arguments.pickBannerHeight() })
        case .chooseBanner:
            return ItemListActionItem(presentationData: presentationData, title: "Choose from Gallery", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: { arguments.chooseBanner() })
        case .removeBanner:
            return ItemListActionItem(presentationData: presentationData, title: "Remove Banner", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: { arguments.removeBanner() })
        case .info:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Local-only. Visible only in this client. Not sent to Telegram servers."), sectionId: self.section)
        }
    }
}

private final class BiogramArguments {
    let togglePremium: (Bool) -> Void
    let addNumber: () -> Void
    let editOrRemoveNumber: (BiogramVirtualNumber) -> Void
    let addAlias: () -> Void
    let editOrRemoveAlias: (String) -> Void
    let toggleColor: (Bool) -> Void
    let selectPreset: (BiogramProfileColor) -> Void
    let setBrightness: (Double) -> Void
    let pickBrightness: () -> Void
    let removeCollectible: (String) -> Void
    let addGiftFromLink: () -> Void
    let chooseBanner: () -> Void
    let removeBanner: () -> Void
    let pickBannerHeight: () -> Void
    
    init(
        togglePremium: @escaping (Bool) -> Void,
        addNumber: @escaping () -> Void,
        editOrRemoveNumber: @escaping (BiogramVirtualNumber) -> Void,
        addAlias: @escaping () -> Void,
        editOrRemoveAlias: @escaping (String) -> Void,
        toggleColor: @escaping (Bool) -> Void,
        selectPreset: @escaping (BiogramProfileColor) -> Void,
        setBrightness: @escaping (Double) -> Void,
        pickBrightness: @escaping () -> Void,
        removeCollectible: @escaping (String) -> Void,
        addGiftFromLink: @escaping () -> Void,
        chooseBanner: @escaping () -> Void,
        removeBanner: @escaping () -> Void,
        pickBannerHeight: @escaping () -> Void
    ) {
        self.togglePremium = togglePremium
        self.addNumber = addNumber
        self.editOrRemoveNumber = editOrRemoveNumber
        self.addAlias = addAlias
        self.editOrRemoveAlias = editOrRemoveAlias
        self.toggleColor = toggleColor
        self.selectPreset = selectPreset
        self.setBrightness = setBrightness
        self.pickBrightness = pickBrightness
        self.removeCollectible = removeCollectible
        self.addGiftFromLink = addGiftFromLink
        self.chooseBanner = chooseBanner
        self.removeBanner = removeBanner
        self.pickBannerHeight = pickBannerHeight
    }
}

private func biogramControllerEntries(state: BiogramControllerState) -> [BiogramEntry] {
    var entries: [BiogramEntry] = []
    
    entries.append(.premiumHeader)
    entries.append(.premiumToggle(state.premiumEnabled))
    
    entries.append(.numbersHeader)
    for (i, n) in state.numbers.enumerated() { entries.append(.number(i, n)) }
    entries.append(.addNumber)
    
    entries.append(.aliasesHeader)
    for (i, a) in state.aliases.enumerated() { entries.append(.alias(i, a)) }
    entries.append(.addAlias)
    
    entries.append(.colorHeader)
    entries.append(.colorToggle(state.profileColorEnabled))
    if state.profileColorEnabled {
        let current = state.profileColor
        for (name, preset) in BiogramProfileColor.presets {
            let selected = current != nil
                && abs(current!.r - preset.r) < 0.01
                && abs(current!.g - preset.g) < 0.01
                && abs(current!.b - preset.b) < 0.01
            entries.append(.colorPreset(name, preset, selected))
        }
        entries.append(.colorBrightness(current?.brightness ?? 1.0))
    }
    
    entries.append(.collectiblesHeader)
    for (i, c) in state.collectibles.enumerated() { entries.append(.collectible(i, c)) }
    entries.append(.addGiftFromLink)
    
    // Banner
    entries.append(.bannerHeader)
    entries.append(.bannerPreview(state.hasBanner))
    entries.append(.bannerHeight(state.bannerHeight))
    entries.append(.chooseBanner)
    if state.hasBanner {
        entries.append(.removeBanner)
    }
    
    entries.append(.info)
    return entries
}

public func biogramSettingsController(context: AccountContext) -> ViewController {
    
    // === Biogram: подгружаем настройки текущего аккаунта ===
    let accountId = String(context.account.peerId.id)
    BiogramManager.shared.switchToAccount(accountId: accountId)
    // ========================================================
    
    let statePromise = ValuePromise(BiogramControllerState.current(), ignoreRepeated: true)
    let stateValue = Atomic(value: BiogramControllerState.current())
    
    let updateState: (() -> Void) = {
        let newState = BiogramControllerState.current()
        _ = stateValue.swap(newState)
        statePromise.set(newState)
    }
    
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    
    let arguments = BiogramArguments(
        togglePremium: { enabled in
            BiogramManager.shared.setLocalPremiumEnabled(enabled) { Queue.mainQueue().async { updateState() } }
            updateState()
        },
        addNumber: {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let controller = biogramPrompt(
                title: "Enter number", text: "Virtual / anonymous number", value: "+888 ",
                placeholder: "+888 00001212", actionTitle: presentationData.strings.Common_Done,
                cancelTitle: presentationData.strings.Common_Cancel, keyboardType: .default
            ) { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return false }
                BiogramManager.shared.addVirtualNumber(BiogramVirtualNumber(number: trimmed)) {
                    Queue.mainQueue().async { updateState() }
                }
                updateState()
                return true
            }
            presentControllerImpl?(controller, nil)
        },
        editOrRemoveNumber: { number in
            let alert = BiogramActionsAlertController(title: number.number, message: "Edit or remove this number", actions: [
                (title: "Edit", destructive: false, action: {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    let editCtrl = biogramPrompt(
                        title: "Number", text: "Edit number", value: number.number, placeholder: "+888 ...",
                        actionTitle: presentationData.strings.Common_Done, cancelTitle: presentationData.strings.Common_Cancel
                    ) { value in
                        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return false }
                        BiogramManager.shared.updateVirtualNumber(id: number.id, number: trimmed, label: number.label) {
                            Queue.mainQueue().async { updateState() }
                        }
                        updateState()
                        return true
                    }
                    presentControllerImpl?(editCtrl, nil)
                }),
                (title: "Delete", destructive: true, action: {
                    BiogramManager.shared.removeVirtualNumber(id: number.id) { Queue.mainQueue().async { updateState() } }
                    updateState()
                })
            ])
            presentControllerImpl?(alert, nil)
        },
        addAlias: {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let controller = biogramPrompt(
                title: "Enter username", text: "Alias / username (without @)", value: "",
                placeholder: "username", actionTitle: presentationData.strings.Common_Done,
                cancelTitle: presentationData.strings.Common_Cancel
            ) { value in
                var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("@") { trimmed = String(trimmed.dropFirst()) }
                guard !trimmed.isEmpty else { return false }
                BiogramManager.shared.addAlias(trimmed) { Queue.mainQueue().async { updateState() } }
                updateState()
                return true
            }
            presentControllerImpl?(controller, nil)
        },
        editOrRemoveAlias: { alias in
            let alert = BiogramActionsAlertController(title: "@\(alias)", message: "Edit or remove this username", actions: [
                (title: "Edit", destructive: false, action: {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    let editCtrl = biogramPrompt(
                        title: "Username", text: "Edit username", value: alias, placeholder: "username",
                        actionTitle: presentationData.strings.Common_Done, cancelTitle: presentationData.strings.Common_Cancel
                    ) { value in
                        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.hasPrefix("@") { trimmed = String(trimmed.dropFirst()) }
                        guard !trimmed.isEmpty else { return false }
                        BiogramManager.shared.replaceAlias(old: alias, new: trimmed) { Queue.mainQueue().async { updateState() } }
                        updateState()
                        return true
                    }
                    presentControllerImpl?(editCtrl, nil)
                }),
                (title: "Delete", destructive: true, action: {
                    BiogramManager.shared.removeAlias(alias) { Queue.mainQueue().async { updateState() } }
                    updateState()
                })
            ])
            presentControllerImpl?(alert, nil)
        },
        toggleColor: { enabled in
            let current = BiogramManager.shared.profileColor ?? BiogramProfileColor.presets[0].1
            BiogramManager.shared.setProfileColor(current, enabled: enabled) { Queue.mainQueue().async { updateState() } }
            updateState()
        },
        selectPreset: { color in
            let brightness = BiogramManager.shared.profileColor?.brightness ?? 1.0
            let newColor = BiogramProfileColor(r: color.r, g: color.g, b: color.b, brightness: brightness)
            BiogramManager.shared.setProfileColor(newColor, enabled: true) { Queue.mainQueue().async { updateState() } }
            updateState()
        },
        setBrightness: { value in
            guard var color = BiogramManager.shared.profileColor else { return }
            color.brightness = value
            BiogramManager.shared.setProfileColor(color, enabled: true) { Queue.mainQueue().async { updateState() } }
            updateState()
        },
        pickBrightness: {
            let alert = BiogramActionsAlertController(title: "Brightness", message: "Choose shade intensity", actions: [0.3, 0.5, 0.7, 0.85, 1.0, 1.15, 1.2].map { value in
                (title: "\(Int(value * 100))%", destructive: false, action: {
                    guard var color = BiogramManager.shared.profileColor else { return }
                    color.brightness = value
                    BiogramManager.shared.setProfileColor(color, enabled: true) { Queue.mainQueue().async { updateState() } }
                    updateState()
                })
            })
            presentControllerImpl?(alert, nil)
        },
        removeCollectible: { id in
            BiogramManager.shared.removeCollectible(id: id) { Queue.mainQueue().async { updateState() } }
            updateState()
        },
        addGiftFromLink: {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let controller = biogramPrompt(
                title: "Gift link", text: "Paste https://t.me/nft/... or slug", value: "",
                placeholder: "https://t.me/nft/VoodooDoll-319", actionTitle: presentationData.strings.Common_Done,
                cancelTitle: presentationData.strings.Common_Cancel, keyboardType: .URL
            ) { value in
                let ok = BiogramManager.shared.addCollectibleFromGiftLink(value) { Queue.mainQueue().async { updateState() } }
                if ok { updateState() }
                return ok
            }
            presentControllerImpl?(controller, nil)
        },
        chooseBanner: {
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.allowsEditing = true
            picker.delegate = BannerPickerDelegate.shared
            BannerPickerDelegate.shared.onPicked = { image in
                BiogramManager.shared.setBannerImage(image) {
                    Queue.mainQueue().async { updateState() }
                }
                updateState()
            }
            presentControllerImpl?(PickerWrapper(picker: picker), nil)
        },
        removeBanner: {
            BiogramManager.shared.setBannerImage(nil) {
                Queue.mainQueue().async { updateState() }
            }
            updateState()
        },
        pickBannerHeight: {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let controller = biogramPrompt(
                title: "Banner height",
                text: "Enter height in points (60–400)",
                value: "\(Int(BiogramManager.shared.bannerHeight))",
                placeholder: "140",
                actionTitle: presentationData.strings.Common_Done,
                cancelTitle: presentationData.strings.Common_Cancel,
                keyboardType: .numberPad
            ) { value in
                guard let h = Double(value.trimmingCharacters(in: .whitespaces)), h >= 60, h <= 400 else { return false }
                BiogramManager.shared.setBannerHeight(CGFloat(h)) {
                    Queue.mainQueue().async { updateState() }
                }
                updateState()
                return true
            }
            presentControllerImpl?(controller, nil)
        }
    )
    
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, statePromise.get())
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let entries = biogramControllerEntries(state: state)
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Biogram"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: true
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            emptyStateItem: nil,
            animateChanges: true
        )
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    return controller
}
