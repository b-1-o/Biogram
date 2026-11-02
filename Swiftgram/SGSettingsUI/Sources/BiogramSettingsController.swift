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
    case card = 6
    case info = 8
}

private final class BiogramControllerState: Equatable {
    let premiumEnabled: Bool
    let numbers: [BiogramVirtualNumber]
    let aliases: [String]
    let collectibles: [BiogramCollectible]
    let profileColorEnabled: Bool
    let profileColor: BiogramProfileColor?
    let hasBanner: Bool
    let profileCardStyle: BiogramProfileCardStyle
    let hasCardImage: Bool
   
    init(
        premiumEnabled: Bool,
        numbers: [BiogramVirtualNumber],
        aliases: [String],
        collectibles: [BiogramCollectible],
        profileColorEnabled: Bool,
        profileColor: BiogramProfileColor?,
        hasBanner: Bool,
        profileCardStyle: BiogramProfileCardStyle,
        hasCardImage: Bool,
    ) {
        self.premiumEnabled = premiumEnabled
        self.numbers = numbers
        self.aliases = aliases
        self.collectibles = collectibles
        self.profileColorEnabled = profileColorEnabled
        self.profileColor = profileColor
        self.hasBanner = hasBanner
        self.profileCardStyle = profileCardStyle
        self.hasCardImage = hasCardImage
    }
   
    static func == (lhs: BiogramControllerState, rhs: BiogramControllerState) -> Bool {
        return lhs.premiumEnabled == rhs.premiumEnabled
            && lhs.numbers == rhs.numbers
            && lhs.aliases == rhs.aliases
            && lhs.collectibles == rhs.collectibles
            && lhs.profileColorEnabled == rhs.profileColorEnabled
            && lhs.profileColor == rhs.profileColor
            && lhs.hasBanner == rhs.hasBanner
            && lhs.profileCardStyle == rhs.profileCardStyle
            && lhs.hasCardImage == rhs.hasCardImage
    }
   
    static func current() -> BiogramControllerState {
        return BiogramControllerState(
            premiumEnabled: BiogramManager.shared.localPremiumEnabled,
            numbers: BiogramManager.shared.virtualNumbers(),
            aliases: BiogramManager.shared.aliases(),
            collectibles: BiogramManager.shared.collectibles(),
            profileColorEnabled: BiogramManager.shared.profileColorEnabled,
            profileColor: BiogramManager.shared.profileColor,
            hasBanner: BiogramManager.shared.banner() != nil,
            profileCardStyle: BiogramManager.shared.profileCardStyle,
            hasCardImage: BiogramManager.shared.profileCardImage() != nil,
        )
    }
}

private enum BiogramEntryId: Hashable {
    case premiumHeader, premiumToggle
    case numbersHeader, number(String), addNumber
    case aliasesHeader, alias(String), addAlias
    case colorHeader, colorToggle, colorPreset(String), colorBrightness
    case colorPattern(String), colorPatternOpacity
    case collectiblesHeader, collectible(String), addGiftFromLink
    case bannerHeader, bannerPreview, chooseBanner, removeBanner
    case profileCardHeader, openProfileCard
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
    case colorPattern(String, String, Bool) // title, key, selected
    case colorPatternOpacity(Double)
    case collectiblesHeader
    case collectible(Int, BiogramCollectible)
    case addGiftFromLink
    case bannerHeader
    case bannerPreview(Bool)
    case chooseBanner
    case removeBanner
    case profileCardHeader
    case openProfileCard(BiogramProfileCardStyle, Bool)
    case info
   
    var section: ItemListSectionId {
        switch self {
        case .premiumHeader, .premiumToggle: return BiogramSection.premium.rawValue
        case .numbersHeader, .number, .addNumber: return BiogramSection.numbers.rawValue
        case .aliasesHeader, .alias, .addAlias: return BiogramSection.aliases.rawValue
        case .colorHeader, .colorToggle, .colorPreset, .colorBrightness, .colorPattern, .colorPatternOpacity:
            return BiogramSection.color.rawValue
        case .collectiblesHeader, .collectible, .addGiftFromLink: return BiogramSection.collectibles.rawValue
        case .bannerHeader, .bannerPreview, .chooseBanner, .removeBanner: return BiogramSection.banner.rawValue
        case .profileCardHeader, .openProfileCard: return BiogramSection.card.rawValue
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
        case let .colorPattern(_, key, _): return .colorPattern(key)
        case .colorPatternOpacity: return .colorPatternOpacity
        case .collectiblesHeader: return .collectiblesHeader
        case let .collectible(_, c): return .collectible(c.id)
        case .addGiftFromLink: return .addGiftFromLink
        case .bannerHeader: return .bannerHeader
        case .bannerPreview: return .bannerPreview
        case .chooseBanner: return .chooseBanner
        case .removeBanner: return .removeBanner
        case .profileCardHeader: return .profileCardHeader
        case .openProfileCard: return .openProfileCard
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
            let detail = number.label != nil ? number.number : "Tap to manage"
            let label = "\(detail)  ·  VISIBLE TO ALL BIOGRAM USERS"
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
        case let .colorPattern(title, key, selected):
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: selected ? "✓" : "", sectionId: self.section, style: .blocks, action: { arguments.selectPattern(key) })
        case let .colorPatternOpacity(value):
            return ItemListDisclosureItem(presentationData: presentationData, title: "Pattern opacity", label: "\(Int((value * 100).rounded()))%", sectionId: self.section, style: .blocks, action: { arguments.pickPatternOpacity() })
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
        case .chooseBanner:
            return ItemListActionItem(presentationData: presentationData, title: "Choose from Gallery", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: { arguments.chooseBanner() })
        case .removeBanner:
            return ItemListActionItem(presentationData: presentationData, title: "Remove Banner", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: { arguments.removeBanner() })
        case .profileCardHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "BIOGRAM PROFILE CARD", sectionId: self.section)
        case let .openProfileCard(style, hasImage):
            let imageLabel = hasImage ? "Custom artwork" : "Color material"
            return ItemListDisclosureItem(presentationData: presentationData, title: "Customize 3D card", label: "\(style.paletteName) · \(style.material.capitalized) · \(imageLabel)", sectionId: self.section, style: .blocks, action: { arguments.openProfileCard() })
        case .info:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Profile color symbols, Biogram aliases, card material, artwork and all decorative anonymous Biogram numbers are visible to other Biogram users. This does not change the privacy of your actual Telegram phone number. Tap the card to flip it; drag to tilt it in 3D."), sectionId: self.section)
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
    let selectPattern: (String) -> Void
    let pickPatternOpacity: () -> Void
    let removeCollectible: (String) -> Void
    let addGiftFromLink: () -> Void
    let chooseBanner: () -> Void
    let removeBanner: () -> Void
    let openProfileCard: () -> Void
   
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
        selectPattern: @escaping (String) -> Void,
        pickPatternOpacity: @escaping () -> Void,
        removeCollectible: @escaping (String) -> Void,
        addGiftFromLink: @escaping () -> Void,
        chooseBanner: @escaping () -> Void,
        removeBanner: @escaping () -> Void,
        openProfileCard: @escaping () -> Void
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
        self.selectPattern = selectPattern
        self.pickPatternOpacity = pickPatternOpacity
        self.removeCollectible = removeCollectible
        self.addGiftFromLink = addGiftFromLink
        self.chooseBanner = chooseBanner
        self.removeBanner = removeBanner
        self.openProfileCard = openProfileCard
    }
}

private func telegramProfileColor(for color: BiogramProfileColor) -> PeerNameColor {
    let r = color.r
    let g = color.g
    let b = color.b
    let candidates: [(Double, Double, Double, PeerNameColor)] = [
        (0.84, 0.20, 0.25, .red),
        (0.96, 0.52, 0.18, .orange),
        (0.57, 0.31, 0.86, .violet),
        (0.20, 0.65, 0.42, .green),
        (0.10, 0.68, 0.75, .cyan),
        (0.28, 0.49, 0.93, .blue),
        (0.91, 0.32, 0.60, .pink)
    ]
    guard let nearest = candidates.min(by: { lhs, rhs in
        let ld = pow(r - lhs.0, 2) + pow(g - lhs.1, 2) + pow(b - lhs.2, 2)
        let rd = pow(r - rhs.0, 2) + pow(g - rhs.1, 2) + pow(b - rhs.2, 2)
        return ld < rd
    }) else { return .blue }
    return nearest.3
}

/// Profile accents are written to Telegram's own profile-color API so other Telegram/Biogram users
/// see the chosen color on the profile. The local RGB value is retained for the richer self preview.
private func syncTelegramProfileColor(_ color: BiogramProfileColor?, context: AccountContext) {
    let mappedColor = color.map { telegramProfileColor(for: $0) }
    let peerSignal = context.engine.data.subscribe(
        TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)
    )
    |> take(1)
    |> deliverOnMainQueue

    let _ = peerSignal.start(next: { peer in
        guard let peer else { return }

        // Keep the user's existing name color and background emoji intact.
        let nameColor: UpdateNameColor
        switch peer.nameColor ?? .preset(.blue) {
        case let .preset(existingColor):
            nameColor = .preset(color: existingColor, backgroundEmojiId: peer.backgroundEmojiId)
        case let .collectible(collectibleColor):
            nameColor = .collectible(collectibleColor)
        }

        let update = context.engine.accountData.updateNameColorAndEmoji(
            nameColor: nameColor,
            profileColor: mappedColor,
            profileBackgroundEmojiId: nil
        )
        let _ = update.start(error: { _ in }, completed: {})
    })
}

private func biogramControllerEntries(state: BiogramControllerState) -> [BiogramEntry] {
    var entries: [BiogramEntry] = []

    // Keep the original Biogram tools visible. Their storage and editing actions
    // remain account-scoped; removing these rows must not remove the features.
    entries.append(.premiumHeader)
    entries.append(.premiumToggle(state.premiumEnabled))

    entries.append(.numbersHeader)
    for (index, number) in state.numbers.enumerated() {
        entries.append(.number(index, number))
    }
    entries.append(.addNumber)

    entries.append(.aliasesHeader)
    for (index, alias) in state.aliases.enumerated() {
        entries.append(.alias(index, alias))
    }
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
        let currentPattern = current?.pattern ?? "none"
        for (title, key) in BiogramProfileColor.patterns {
            entries.append(.colorPattern(title, key, currentPattern == key))
        }
        if currentPattern != "none" {
            entries.append(.colorPatternOpacity(current?.patternOpacity ?? 0.25))
        }
    }

    entries.append(.collectiblesHeader)
    for (index, collectible) in state.collectibles.enumerated() {
        entries.append(.collectible(index, collectible))
    }
    entries.append(.addGiftFromLink)

    entries.append(.bannerHeader)
    entries.append(.bannerPreview(state.hasBanner))
    entries.append(.chooseBanner)
    if state.hasBanner {
        entries.append(.removeBanner)
    }

    entries.append(.profileCardHeader)
    entries.append(.openProfileCard(state.profileCardStyle, state.hasCardImage))

    entries.append(.info)
    return entries
}

public func biogramSettingsController(context: AccountContext) -> ViewController {
    // Preserve the existing Biogram account key for its local preferences.
    let accountId = String(context.account.peerId.toInt64())
    // Use Telegram's raw numeric account ID for the decorative card signature.
    let fogWalletAccountId = String(context.account.peerId.id._internalGetInt64Value())
    let initialState = BiogramControllerState.current()
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: (() -> Void) = {
        let newState = BiogramControllerState.current()
        _ = stateValue.swap(newState)
        statePromise.set(newState)
    }
    // === Biogram: загружаем настройки именно текущего Telegram-аккаунта ===
    BiogramManager.shared.switchToAccount(accountId: accountId) {
        updateState()
    }
    // =====================================================================
    var presentControllerImpl: ((ViewController, Any?) -> Void)?

    let arguments = BiogramArguments(
        togglePremium: { enabled in
            BiogramManager.shared.setLocalPremiumEnabled(enabled) {
                Queue.mainQueue().async { updateState() }
            }
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
                BiogramManager.shared.addVirtualNumber(BiogramVirtualNumber(number: trimmed, isPublic: true)) {
                    Queue.mainQueue().async { updateState() }
                }
                return true
            }
            presentControllerImpl?(controller, nil)
        },
        editOrRemoveNumber: { number in
            let alert = BiogramActionsAlertController(title: number.number, message: "This decorative Biogram number is visible to all Biogram users. Edit or remove it.", actions: [
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
                        return true
                    }
                    presentControllerImpl?(editCtrl, nil)
                }),
                (title: "Delete", destructive: true, action: {
                    BiogramManager.shared.removeVirtualNumber(id: number.id) {
                        Queue.mainQueue().async { updateState() }
                    }
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
                BiogramManager.shared.addAlias(trimmed) {
                    Queue.mainQueue().async { updateState() }
                }
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
                        BiogramManager.shared.replaceAlias(old: alias, new: trimmed) {
                            Queue.mainQueue().async { updateState() }
                        }
                        return true
                    }
                    presentControllerImpl?(editCtrl, nil)
                }),
                (title: "Delete", destructive: true, action: {
                    BiogramManager.shared.removeAlias(alias) {
                        Queue.mainQueue().async { updateState() }
                    }
                })
            ])
            presentControllerImpl?(alert, nil)
        },
        toggleColor: { enabled in
            let current = BiogramManager.shared.profileColor ?? BiogramProfileColor.presets[0].1
            BiogramManager.shared.setProfileColor(current, enabled: enabled) {
                Queue.mainQueue().async { updateState() }
            }
            syncTelegramProfileColor(enabled ? current : nil, context: context)
        },
        selectPreset: { color in
            let existing = BiogramManager.shared.profileColor
            let newColor = BiogramProfileColor(
                r: color.r,
                g: color.g,
                b: color.b,
                brightness: existing?.brightness ?? 1.0,
                pattern: existing?.pattern ?? "none",
                patternOpacity: existing?.patternOpacity ?? 0.25
            )
            BiogramManager.shared.setProfileColor(newColor, enabled: true) {
                Queue.mainQueue().async { updateState() }
            }
            syncTelegramProfileColor(newColor, context: context)
        },
        setBrightness: { value in
            guard var color = BiogramManager.shared.profileColor else { return }
            color.brightness = value
            BiogramManager.shared.setProfileColor(color, enabled: true) {
                Queue.mainQueue().async { updateState() }
            }
        },
        pickBrightness: {
            let alert = BiogramActionsAlertController(title: "Brightness", message: "Choose shade intensity", actions: [0.3, 0.5, 0.7, 0.85, 1.0, 1.15, 1.2].map { value in
                (title: "\(Int(value * 100))%", destructive: false, action: {
                    guard var color = BiogramManager.shared.profileColor else { return }
                    color.brightness = value
                    BiogramManager.shared.setProfileColor(color, enabled: true) {
                        Queue.mainQueue().async { updateState() }
                    }
                })
            })
            presentControllerImpl?(alert, nil)
        },
        selectPattern: { key in
            guard var color = BiogramManager.shared.profileColor else {
                var c = BiogramProfileColor.presets[0].1
                c.pattern = key
                BiogramManager.shared.setProfileColor(c, enabled: true) {
                    Queue.mainQueue().async { updateState() }
                }
                return
            }
            color.pattern = key
            BiogramManager.shared.setProfileColor(color, enabled: true) {
                Queue.mainQueue().async { updateState() }
            }
        },
        pickPatternOpacity: {
            let alert = BiogramActionsAlertController(title: "Pattern opacity", message: "How visible the pattern is", actions: [0.1, 0.15, 0.25, 0.35, 0.5, 0.7].map { value in
                (title: "\(Int(value * 100))%", destructive: false, action: {
                    guard var color = BiogramManager.shared.profileColor else { return }
                    color.patternOpacity = value
                    BiogramManager.shared.setProfileColor(color, enabled: true) {
                        Queue.mainQueue().async { updateState() }
                    }
                })
            })
            presentControllerImpl?(alert, nil)
        },
        removeCollectible: { id in
            BiogramManager.shared.removeCollectible(id: id) {
                Queue.mainQueue().async { updateState() }
            }
        },
        addGiftFromLink: {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let controller = biogramPrompt(
                title: "Gift link", text: "Paste https://t.me/nft/... or slug", value: "",
                placeholder: "https://t.me/nft/VoodooDoll-319", actionTitle: presentationData.strings.Common_Done,
                cancelTitle: presentationData.strings.Common_Cancel, keyboardType: .URL
            ) { value in
                _ = BiogramManager.shared.addCollectibleFromGiftLink(value) {
                    Queue.mainQueue().async { updateState() }
                }
                return true
            }
            presentControllerImpl?(controller, nil)
        },
        chooseBanner: {
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.allowsEditing = false  // false = не режет квадратом, сохраняет исходный aspect
            picker.delegate = BannerPickerDelegate.shared
           
            BannerPickerDelegate.shared.onPicked = { image in
                guard let image = image else { return }
                BiogramManager.shared.setBannerImage(image, aspectRatio: "free") {
                    Queue.mainQueue().async { updateState() }
                }
            }
            presentControllerImpl?(PickerWrapper(picker: picker), nil)
        },
        removeBanner: {
            BiogramManager.shared.setBannerImage(nil) {
                Queue.mainQueue().async { updateState() }
            }
        },
        openProfileCard: {
            presentControllerImpl?(BiogramProfileCardDesignerController(
                context: context,
                accountId: accountId,
                userId: fogWalletAccountId
            ), nil)
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
// MARK: - Fog Wallet cards

private func fogWalletColor(_ hex: String) -> UIColor {
    var value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    if value.count != 6 { value = "171719" }
    var rgb: UInt64 = 0
    Scanner(string: value).scanHexInt64(&rgb)
    return UIColor(
        red: CGFloat((rgb >> 16) & 0xff) / 255.0,
        green: CGFloat((rgb >> 8) & 0xff) / 255.0,
        blue: CGFloat(rgb & 0xff) / 255.0,
        alpha: 1.0
    )
}

private func biogramCardColor(_ hex: String) -> UIColor {
    var value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    if value.count != 6 { value = "171719" }
    var rgb: UInt64 = 0
    Scanner(string: value).scanHexInt64(&rgb)
    return UIColor(
        red: CGFloat((rgb >> 16) & 0xff) / 255.0,
        green: CGFloat((rgb >> 8) & 0xff) / 255.0,
        blue: CGFloat(rgb & 0xff) / 255.0,
        alpha: 1.0
    )
}

private func biogramCardPalette(_ name: String) -> (UIColor, UIColor) {
    let preset = BiogramProfileColor.presets.first(where: { $0.0 == name })?.1
        ?? BiogramProfileColor.presets.first(where: { $0.0 == "Dark Red" })!.1
    let main = UIColor(
        red: CGFloat(preset.r),
        green: CGFloat(preset.g),
        blue: CGFloat(preset.b),
        alpha: 1.0
    )
    let shade = UIColor(
        red: CGFloat(preset.r * 0.52),
        green: CGFloat(preset.g * 0.52),
        blue: CGFloat(preset.b * 0.58),
        alpha: 1.0
    )
    return (main, shade)
}

private func biogramCardSignature(_ userId: String) -> String {
    var hash: UInt64 = 1469598103934665603
    for byte in userId.utf8 {
        hash = (hash ^ UInt64(byte)) &* 1099511628211
    }
    return String(format: "B1O  ·  %04X  ·  %04X  ·  %04X", (hash >> 32) & 0xffff, (hash >> 16) & 0xffff, hash & 0xffff)
}

private func biogramCardVisualHash(_ userId: String) -> String {
    let bytes = Array(userId.utf8)
    return (0..<4).map { lane in
        var hash = UInt32(2166136261) ^ (UInt32(lane) &* 0x9E3779B9)
        for byte in bytes {
            hash = (hash ^ UInt32(byte)) &* 16777619
        }
        return String(format: "%08X", hash)
    }.joined(separator: " ")
}

private final class BiogramCardHashPatternView: UIView {
    var seed: String = "" {
        didSet { self.setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.black.withAlphaComponent(0.22)
        self.layer.cornerRadius = 8
        self.layer.borderWidth = 1
        self.layer.borderColor = UIColor.white.withAlphaComponent(0.38).cgColor
        self.clipsToBounds = true
        self.isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        let count = 17
        let padding: CGFloat = 5
        let cell = min((self.bounds.width - padding * 2) / CGFloat(count), (self.bounds.height - padding * 2) / CGFloat(count))
        guard cell > 0 else { return }
        let origin = CGPoint(x: (self.bounds.width - cell * CGFloat(count)) / 2, y: (self.bounds.height - cell * CGFloat(count)) / 2)

        for row in 0..<count {
            for column in 0..<count {
                var value: UInt64 = 1469598103934665603
                for byte in "\(self.seed):\(row):\(column)".utf8 {
                    value = (value ^ UInt64(byte)) &* 1099511628211
                }
                let isFinder = (row < 5 && column < 5) || (row < 5 && column >= count - 5) || (row >= count - 5 && column < 5)
                let active = isFinder
                    ? ((row % 4 == 0 || column % 4 == 0) || (row % 4 >= 1 && row % 4 <= 2 && column % 4 >= 1 && column % 4 <= 2))
                    : ((value & 3) != 0)
                guard active else { continue }
                let frame = CGRect(
                    x: origin.x + CGFloat(column) * cell + 0.6,
                    y: origin.y + CGFloat(row) * cell + 0.6,
                    width: max(1, cell - 1.2),
                    height: max(1, cell - 1.2)
                )
                UIColor.white.withAlphaComponent(0.84).setFill()
                UIBezierPath(roundedRect: frame, cornerRadius: 0.8).fill()
            }
        }
    }
}

private final class Biogram3DProfileCardView: UIView {
    private let cardContainer = UIView()
    private let front = UIView()
    private let back = UIView()
    private let frontGradient = CAGradientLayer()
    private let frontArtwork = UIImageView()
    private let frontFrost = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let frontSheen = CAGradientLayer()
    private let backGradient = CAGradientLayer()
    private let backFrost = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let backSheen = CAGradientLayer()
    private let backCipherLabel = UILabel()
    private let backMagneticStrip = UIView()
    private let backHashPatternView = BiogramCardHashPatternView()
    private let backHashLabel = UILabel()
    private let brandLabel = UILabel()
    private let editionLabel = UILabel()
    private let chipView = UIView()
    private let nameLabel = UILabel()
    private let handleLabel = UILabel()
    private let frontSignatureLabel = UILabel()
    private let backTitleLabel = UILabel()
    private let backHandleLabel = UILabel()
    private let backIdLabel = UILabel()
    private let backSignatureLabel = UILabel()
    private let backFooterLabel = UILabel()
    private var style = BiogramProfileCardStyle()
    private var userName = "BIOGRAM MEMBER"
    private var userHandle = "@biogram"
    private var userId = "—"
    private var showingBack = false
    private var tiltX: CGFloat = 0.0
    private var tiltY: CGFloat = 0.0
    private var panOrigin = CGPoint.zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = true
        self.cardContainer.layer.cornerRadius = 25
        self.cardContainer.layer.masksToBounds = false
        self.cardContainer.layer.shadowColor = UIColor.black.cgColor
        self.cardContainer.layer.shadowOpacity = 0.42
        self.cardContainer.layer.shadowRadius = 24
        self.cardContainer.layer.shadowOffset = CGSize(width: 0, height: 14)
        self.addSubview(self.cardContainer)

        for face in [self.front, self.back] {
            face.layer.cornerRadius = 25
            face.layer.masksToBounds = true
            face.layer.borderWidth = 1
            face.layer.borderColor = UIColor.white.withAlphaComponent(0.30).cgColor
            face.layer.isDoubleSided = false
            self.cardContainer.addSubview(face)
        }
        self.back.layer.transform = CATransform3DIdentity
        self.back.isHidden = true

        self.frontGradient.startPoint = CGPoint(x: 0.0, y: 0.0)
        self.frontGradient.endPoint = CGPoint(x: 1.0, y: 1.0)
        self.front.layer.insertSublayer(self.frontGradient, at: 0)

        self.frontArtwork.contentMode = .scaleAspectFill
        self.frontArtwork.clipsToBounds = true
        self.frontArtwork.isUserInteractionEnabled = false
        self.front.addSubview(self.frontArtwork)

        self.frontFrost.isUserInteractionEnabled = false
        self.frontFrost.alpha = 0.46
        self.front.addSubview(self.frontFrost)

        self.frontSheen.startPoint = CGPoint(x: 0.0, y: 0.0)
        self.frontSheen.endPoint = CGPoint(x: 1.0, y: 1.0)
        self.frontSheen.locations = [0.0, 0.42, 0.6, 1.0]
        let frontSheenHost = UIView()
        frontSheenHost.isUserInteractionEnabled = false
        frontSheenHost.layer.addSublayer(self.frontSheen)
        self.front.addSubview(frontSheenHost)
        frontSheenHost.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            frontSheenHost.topAnchor.constraint(equalTo: self.front.topAnchor),
            frontSheenHost.leadingAnchor.constraint(equalTo: self.front.leadingAnchor),
            frontSheenHost.trailingAnchor.constraint(equalTo: self.front.trailingAnchor),
            frontSheenHost.bottomAnchor.constraint(equalTo: self.front.bottomAnchor)
        ])

        self.brandLabel.text = "BIOGRAM"
        self.brandLabel.font = UIFont.systemFont(ofSize: 12, weight: .heavy)
        self.brandLabel.textColor = UIColor.white.withAlphaComponent(0.96)
        self.front.addSubview(self.brandLabel)

        self.editionLabel.text = "PRIVATE PROFILE"
        self.editionLabel.font = UIFont.monospacedSystemFont(ofSize: 8, weight: .semibold)
        self.editionLabel.textColor = UIColor.white.withAlphaComponent(0.76)
        self.editionLabel.textAlignment = .right
        self.front.addSubview(self.editionLabel)

        self.chipView.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        self.chipView.layer.cornerRadius = 7
        self.chipView.layer.borderWidth = 1
        self.chipView.layer.borderColor = UIColor.white.withAlphaComponent(0.58).cgColor
        self.chipView.isUserInteractionEnabled = false
        self.front.addSubview(self.chipView)
        for fraction in [CGFloat(0.33), CGFloat(0.66)] {
            let line = UIView()
            line.backgroundColor = UIColor.white.withAlphaComponent(0.34)
            self.chipView.addSubview(line)
            line.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                line.topAnchor.constraint(equalTo: self.chipView.topAnchor, constant: 4),
                line.bottomAnchor.constraint(equalTo: self.chipView.bottomAnchor, constant: -4),
                line.widthAnchor.constraint(equalToConstant: 1),
                line.leadingAnchor.constraint(equalTo: self.chipView.leadingAnchor, constant: 44 * fraction)
            ])
        }

        self.nameLabel.font = UIFont.systemFont(ofSize: 21, weight: .semibold)
        self.nameLabel.textColor = .white
        self.nameLabel.adjustsFontSizeToFitWidth = true
        self.nameLabel.minimumScaleFactor = 0.72
        self.front.addSubview(self.nameLabel)

        self.handleLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        self.handleLabel.textColor = UIColor.white.withAlphaComponent(0.75)
        self.front.addSubview(self.handleLabel)

        self.frontSignatureLabel.font = UIFont.monospacedSystemFont(ofSize: 9, weight: .medium)
        self.frontSignatureLabel.textColor = UIColor.white.withAlphaComponent(0.75)
        self.front.addSubview(self.frontSignatureLabel)

        self.backGradient.startPoint = CGPoint(x: 0, y: 0)
        self.backGradient.endPoint = CGPoint(x: 1, y: 1)
        self.back.layer.insertSublayer(self.backGradient, at: 0)
        self.backFrost.isUserInteractionEnabled = false
        self.backFrost.alpha = 0.40
        self.back.addSubview(self.backFrost)
        self.backSheen.startPoint = CGPoint(x: 0.0, y: 0.2)
        self.backSheen.endPoint = CGPoint(x: 1.0, y: 0.8)
        self.back.layer.addSublayer(self.backSheen)

        self.backTitleLabel.text = "BIOGRAM  /  PROFILE"
        self.backTitleLabel.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .bold)
        self.backTitleLabel.textColor = UIColor.white.withAlphaComponent(0.74)
        self.back.addSubview(self.backTitleLabel)

        self.backMagneticStrip.backgroundColor = UIColor.black.withAlphaComponent(0.38)
        self.backMagneticStrip.layer.borderWidth = 0.5
        self.backMagneticStrip.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        self.backMagneticStrip.translatesAutoresizingMaskIntoConstraints = false
        self.back.addSubview(self.backMagneticStrip)

        self.backHandleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        self.backHandleLabel.textColor = .white
        self.backHandleLabel.adjustsFontSizeToFitWidth = true
        self.backHandleLabel.minimumScaleFactor = 0.75
        self.back.addSubview(self.backHandleLabel)

        self.backIdLabel.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        self.backIdLabel.textColor = UIColor.white.withAlphaComponent(0.78)
        self.back.addSubview(self.backIdLabel)

        self.backCipherLabel.font = UIFont.monospacedSystemFont(ofSize: 8.5, weight: .medium)
        self.backCipherLabel.textColor = UIColor.white.withAlphaComponent(0.55)
        self.backCipherLabel.adjustsFontSizeToFitWidth = true
        self.backCipherLabel.minimumScaleFactor = 0.7
        self.back.addSubview(self.backCipherLabel)

        self.backHashPatternView.translatesAutoresizingMaskIntoConstraints = false
        self.back.addSubview(self.backHashPatternView)

        self.backHashLabel.font = UIFont.monospacedSystemFont(ofSize: 6.5, weight: .semibold)
        self.backHashLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        self.backHashLabel.textAlignment = .center
        self.backHashLabel.adjustsFontSizeToFitWidth = true
        self.backHashLabel.minimumScaleFactor = 0.7
        self.back.addSubview(self.backHashLabel)

        self.backSignatureLabel.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
        self.backSignatureLabel.textColor = biogramCardColor("#E8D9C4")
        self.back.addSubview(self.backSignatureLabel)

        self.backFooterLabel.text = "PROFILE SIGNATURE  ·  NOT A PAYMENT CARD"
        self.backFooterLabel.font = UIFont.monospacedSystemFont(ofSize: 7.5, weight: .medium)
        self.backFooterLabel.textColor = UIColor.white.withAlphaComponent(0.55)
        self.backFooterLabel.adjustsFontSizeToFitWidth = true
        self.backFooterLabel.minimumScaleFactor = 0.7
        self.back.addSubview(self.backFooterLabel)

        for view in [
            self.brandLabel, self.editionLabel, self.chipView, self.nameLabel,
            self.handleLabel, self.frontSignatureLabel, self.backTitleLabel,
            self.backHandleLabel, self.backIdLabel, self.backCipherLabel, self.backHashLabel,
            self.backSignatureLabel, self.backFooterLabel
        ] {
            view.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            self.brandLabel.topAnchor.constraint(equalTo: self.front.topAnchor, constant: 20),
            self.brandLabel.leadingAnchor.constraint(equalTo: self.front.leadingAnchor, constant: 22),
            self.editionLabel.centerYAnchor.constraint(equalTo: self.brandLabel.centerYAnchor),
            self.editionLabel.trailingAnchor.constraint(equalTo: self.front.trailingAnchor, constant: -22),
            self.editionLabel.leadingAnchor.constraint(greaterThanOrEqualTo: self.brandLabel.trailingAnchor, constant: 8),

            self.chipView.topAnchor.constraint(equalTo: self.brandLabel.bottomAnchor, constant: 22),
            self.chipView.leadingAnchor.constraint(equalTo: self.front.leadingAnchor, constant: 22),
            self.chipView.widthAnchor.constraint(equalToConstant: 44),
            self.chipView.heightAnchor.constraint(equalToConstant: 32),

            self.nameLabel.leadingAnchor.constraint(equalTo: self.front.leadingAnchor, constant: 22),
            self.nameLabel.trailingAnchor.constraint(equalTo: self.front.trailingAnchor, constant: -22),
            self.nameLabel.bottomAnchor.constraint(equalTo: self.handleLabel.topAnchor, constant: -2),
            self.handleLabel.leadingAnchor.constraint(equalTo: self.front.leadingAnchor, constant: 22),
            self.handleLabel.trailingAnchor.constraint(equalTo: self.front.trailingAnchor, constant: -22),
            self.handleLabel.bottomAnchor.constraint(equalTo: self.frontSignatureLabel.topAnchor, constant: -13),
            self.frontSignatureLabel.leadingAnchor.constraint(equalTo: self.front.leadingAnchor, constant: 22),
            self.frontSignatureLabel.trailingAnchor.constraint(equalTo: self.front.trailingAnchor, constant: -22),
            self.frontSignatureLabel.bottomAnchor.constraint(equalTo: self.front.bottomAnchor, constant: -18),

            self.backTitleLabel.topAnchor.constraint(equalTo: self.back.topAnchor, constant: 20),
            self.backTitleLabel.leadingAnchor.constraint(equalTo: self.back.leadingAnchor, constant: 22),
            self.backTitleLabel.trailingAnchor.constraint(equalTo: self.back.trailingAnchor, constant: -22),
            self.backMagneticStrip.topAnchor.constraint(equalTo: self.backTitleLabel.bottomAnchor, constant: 13),
            self.backMagneticStrip.leadingAnchor.constraint(equalTo: self.back.leadingAnchor),
            self.backMagneticStrip.trailingAnchor.constraint(equalTo: self.back.trailingAnchor),
            self.backMagneticStrip.heightAnchor.constraint(equalToConstant: 22),

            self.backHandleLabel.topAnchor.constraint(equalTo: self.backMagneticStrip.bottomAnchor, constant: 10),
            self.backHandleLabel.leadingAnchor.constraint(equalTo: self.back.leadingAnchor, constant: 22),
            self.backHandleLabel.trailingAnchor.constraint(equalTo: self.backHashPatternView.leadingAnchor, constant: -10),
            self.backIdLabel.topAnchor.constraint(equalTo: self.backHandleLabel.bottomAnchor, constant: 6),
            self.backIdLabel.leadingAnchor.constraint(equalTo: self.back.leadingAnchor, constant: 22),
            self.backIdLabel.trailingAnchor.constraint(equalTo: self.backHashPatternView.leadingAnchor, constant: -10),
            self.backCipherLabel.topAnchor.constraint(equalTo: self.backIdLabel.bottomAnchor, constant: 10),
            self.backCipherLabel.leadingAnchor.constraint(equalTo: self.back.leadingAnchor, constant: 22),
            self.backCipherLabel.trailingAnchor.constraint(equalTo: self.backHashPatternView.leadingAnchor, constant: -10),
            self.backHashPatternView.topAnchor.constraint(equalTo: self.backMagneticStrip.bottomAnchor, constant: 10),
            self.backHashPatternView.trailingAnchor.constraint(equalTo: self.back.trailingAnchor, constant: -22),
            self.backHashPatternView.widthAnchor.constraint(equalToConstant: 64),
            self.backHashPatternView.heightAnchor.constraint(equalToConstant: 64),
            self.backHashLabel.topAnchor.constraint(equalTo: self.backHashPatternView.bottomAnchor, constant: 3),
            self.backHashLabel.centerXAnchor.constraint(equalTo: self.backHashPatternView.centerXAnchor),
            self.backHashLabel.widthAnchor.constraint(equalTo: self.backHashPatternView.widthAnchor),
            self.backHashLabel.heightAnchor.constraint(equalToConstant: 10),

            self.backSignatureLabel.leadingAnchor.constraint(equalTo: self.back.leadingAnchor, constant: 22),
            self.backSignatureLabel.trailingAnchor.constraint(equalTo: self.backHashPatternView.leadingAnchor, constant: -10),
            self.backSignatureLabel.bottomAnchor.constraint(equalTo: self.backFooterLabel.topAnchor, constant: -17),
            self.backFooterLabel.leadingAnchor.constraint(equalTo: self.back.leadingAnchor, constant: 22),
            self.backFooterLabel.trailingAnchor.constraint(equalTo: self.back.trailingAnchor, constant: -22),
            self.backFooterLabel.bottomAnchor.constraint(equalTo: self.back.bottomAnchor, constant: -19)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(flip))
        self.addGestureRecognizer(tap)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        self.addGestureRecognizer(pan)
        tap.require(toFail: pan)
        self.configure(style: self.style, image: nil, displayName: self.userName, username: self.userHandle, userId: self.userId)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.cardContainer.frame = self.bounds
        self.front.frame = self.cardContainer.bounds
        self.back.frame = self.cardContainer.bounds
        self.frontGradient.frame = self.front.bounds
        self.frontArtwork.frame = self.front.bounds
        self.frontFrost.frame = self.front.bounds
        self.frontSheen.frame = self.front.bounds
        self.backGradient.frame = self.back.bounds
        self.backFrost.frame = self.back.bounds
        self.backSheen.frame = self.back.bounds
        self.cardContainer.layer.shadowPath = UIBezierPath(roundedRect: self.cardContainer.bounds, cornerRadius: 25).cgPath
        self.applyTransform(animated: false)
    }

    func configure(
        style: BiogramProfileCardStyle,
        image: UIImage?,
        displayName: String,
        username: String,
        userId: String,
        aliases: [String] = [],
        publicNumbers: [BiogramCloudPublicNumber] = []
    ) {
        self.style = style
        self.userName = displayName.isEmpty ? "BIOGRAM MEMBER" : displayName.uppercased()
        self.userHandle = username.isEmpty ? "@BIOGRAM" : username
        self.userId = userId

        let (main, shade) = biogramCardPalette(style.paletteName)
        self.frontGradient.colors = [main.cgColor, shade.cgColor, biogramCardColor("#101014").cgColor]
        self.frontArtwork.image = image
        self.frontArtwork.isHidden = image == nil
        self.brandLabel.text = "BIOGRAM"
        self.nameLabel.text = self.userName
        self.handleLabel.text = self.userHandle.hasPrefix("@") ? self.userHandle : "@\(self.userHandle)"
        let signature = biogramCardSignature(userId)
        self.frontSignatureLabel.text = signature

        let normalizedHandle = self.userHandle.replacingOccurrences(of: "@", with: "")
        let additionalAliases = aliases.filter {
            $0.replacingOccurrences(of: "@", with: "") != normalizedHandle
        }
        let visibleAliases = additionalAliases.prefix(2).map {
            $0.hasPrefix("@") ? $0 : "@\($0)"
        }
        let remainingAliasCount = max(0, additionalAliases.count - visibleAliases.count)
        let aliasSuffix = remainingAliasCount > 0 ? "  +\(remainingAliasCount)" : ""
        self.backHashPatternView.seed = userId
        self.backHashLabel.text = "HASH / " + String(biogramCardVisualHash(userId).replacingOccurrences(of: " ", with: "").prefix(12))
        self.backTitleLabel.text = "BIOGRAM / PROFILE DETAILS"
        self.backHandleLabel.text = visibleAliases.isEmpty
            ? (self.handleLabel.text ?? self.userHandle)
            : "ALIASES  " + visibleAliases.joined(separator: "  · ") + aliasSuffix
        self.backIdLabel.text = "TELEGRAM ID  /  \(userId)"

        let visibleNumbers = publicNumbers.filter { $0.isPublic }.prefix(2)
        let numberSummary = visibleNumbers.map { number -> String in
            let label = number.label?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let label, !label.isEmpty {
                return "\(label) · \(number.number)"
            }
            return number.number
        }
        let remainingNumberCount = max(0, publicNumbers.filter { $0.isPublic }.count - numberSummary.count)
        let numberSuffix = remainingNumberCount > 0 ? "  +\(remainingNumberCount)" : ""
        self.backCipherLabel.numberOfLines = 2
        self.backCipherLabel.text = numberSummary.isEmpty
            ? "NO PUBLIC ANONYMOUS NUMBERS"
            : "PUBLIC NUMBERS  /  " + numberSummary.joined(separator: "  ·  ") + numberSuffix
        self.backSignatureLabel.text = signature
        self.backGradient.colors = [shade.cgColor, biogramCardColor("#111114").cgColor, main.withAlphaComponent(0.40).cgColor]

        switch style.material {
        case "matte":
            self.frontFrost.alpha = 0.66
            self.backFrost.alpha = 0.62
            self.frontSheen.colors = [UIColor.white.withAlphaComponent(0.14).cgColor, UIColor.white.withAlphaComponent(0.035).cgColor, UIColor.clear.cgColor, UIColor.white.withAlphaComponent(0.025).cgColor]
            self.frontSheen.opacity = 0.48
            self.backSheen.colors = [UIColor.white.withAlphaComponent(0.10).cgColor, UIColor.clear.cgColor, UIColor.white.withAlphaComponent(0.025).cgColor]
            self.backSheen.opacity = 0.42
        case "metallic":
            self.frontFrost.alpha = 0.24
            self.backFrost.alpha = 0.20
            self.frontSheen.colors = [UIColor.white.withAlphaComponent(0.45).cgColor, UIColor.white.withAlphaComponent(0.05).cgColor, UIColor.black.withAlphaComponent(0.15).cgColor, UIColor.white.withAlphaComponent(0.28).cgColor, UIColor.clear.cgColor]
            self.frontSheen.locations = [0.0, 0.22, 0.42, 0.66, 1.0]
            self.frontSheen.opacity = 0.8
            self.backSheen.colors = [UIColor.white.withAlphaComponent(0.28).cgColor, UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.12).cgColor, UIColor.white.withAlphaComponent(0.18).cgColor]
            self.backSheen.opacity = 0.72
        default:
            self.frontFrost.alpha = 0.44
            self.backFrost.alpha = 0.40
            self.frontSheen.colors = [UIColor.white.withAlphaComponent(0.44).cgColor, UIColor.white.withAlphaComponent(0.08).cgColor, UIColor.clear.cgColor, UIColor.white.withAlphaComponent(0.12).cgColor]
            self.frontSheen.locations = [0.0, 0.24, 0.56, 1.0]
            self.frontSheen.opacity = 0.76
            self.backSheen.colors = [UIColor.white.withAlphaComponent(0.24).cgColor, UIColor.clear.cgColor, UIColor.white.withAlphaComponent(0.08).cgColor]
            self.backSheen.opacity = 0.64
        }
        self.setNeedsLayout()
    }

    @objc private func flip() {
        let showBack = !self.showingBack
        self.showingBack = showBack
        self.tiltX = 0
        self.tiltY = 0
        self.applyTransform(animated: true)

        UIView.transition(
            with: self.cardContainer,
            duration: 0.58,
            options: [.transitionFlipFromRight, .showHideTransitionViews, .allowUserInteraction, .beginFromCurrentState],
            animations: {
                self.front.isHidden = showBack
                self.back.isHidden = !showBack
            }
        )
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let point = gesture.translation(in: self)
        switch gesture.state {
        case .began:
            self.panOrigin = CGPoint(x: self.tiltX, y: self.tiltY)
        case .changed:
            self.tiltY = max(-0.42, min(0.42, self.panOrigin.y + point.x / max(1.0, self.bounds.width) * 0.9))
            self.tiltX = max(-0.24, min(0.24, self.panOrigin.x - point.y / max(1.0, self.bounds.height) * 0.55))
            self.applyTransform(animated: false)
        case .ended, .cancelled, .failed:
            self.tiltX = 0
            self.tiltY = 0
            self.applyTransform(animated: true)
        default:
            break
        }
    }

    private func applyTransform(animated: Bool) {
        var transform = CATransform3DIdentity
        transform.m34 = -1.0 / 720.0
        transform = CATransform3DRotate(transform, self.tiltY, 0.0, 1.0, 0.0)
        transform = CATransform3DRotate(transform, self.tiltX, 1.0, 0.0, 0.0)
        let changes = {
            self.cardContainer.layer.transform = transform
        }
        if animated {
            UIView.animate(withDuration: 0.48, delay: 0, usingSpringWithDamping: 0.78, initialSpringVelocity: 0.3, options: [.beginFromCurrentState, .allowUserInteraction], animations: changes)
        } else {
            changes()
        }
    }
}

/// Renders a compact profile-row thumbnail using the selected card palette, artwork and material.
public func biogramProfileCardThumbnail(
    style: BiogramProfileCardStyle,
    image: UIImage?,
    displayName: String,
    username: String,
    userId: String
) -> UIImage {
    // This image is used in a standard disclosure row, so keep its point size
    // within the row's height while rendering at the device's native scale.
    let size = CGSize(width: 82, height: 52)
    let bounds = CGRect(origin: .zero, size: size)
    let cornerRadius: CGFloat = 7
    let (main, shade) = biogramCardPalette(style.paletteName)
    let renderer = UIGraphicsImageRenderer(size: size)

    return renderer.image { rendererContext in
        let cgContext = rendererContext.cgContext
        let cardPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius)
        cgContext.saveGState()
        cardPath.addClip()

        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [main.cgColor, shade.cgColor, biogramCardColor("#101014").cgColor] as CFArray,
            locations: [0.0, 0.62, 1.0]
        ) {
            cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        }

        if let image, image.size.width > 0, image.size.height > 0 {
            let scale = max(size.width / image.size.width, size.height / image.size.height)
            let imageSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let imageRect = CGRect(
                x: (size.width - imageSize.width) * 0.5,
                y: (size.height - imageSize.height) * 0.5,
                width: imageSize.width,
                height: imageSize.height
            )
            image.draw(in: imageRect, blendMode: .screen, alpha: 0.28)
        }

        let sheenColors = style.material == "matte"
            ? [UIColor.white.withAlphaComponent(0.12).cgColor, UIColor.clear.cgColor] as CFArray
            : [UIColor.white.withAlphaComponent(0.30).cgColor, UIColor.clear.cgColor, UIColor.white.withAlphaComponent(0.08).cgColor] as CFArray
        if let sheen = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: sheenColors,
            locations: style.material == "matte" ? [0.0, 1.0] : [0.0, 0.58, 1.0]
        ) {
            cgContext.drawLinearGradient(
                sheen,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        }
        cgContext.restoreGState()

        cardPath.lineWidth = 0.8
        UIColor.white.withAlphaComponent(0.52).setStroke()
        cardPath.stroke()

        let brandAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 6.2, weight: .heavy),
            .foregroundColor: UIColor.white.withAlphaComponent(0.96)
        ]
        ("BIOGRAM" as NSString).draw(at: CGPoint(x: 7, y: 6), withAttributes: brandAttributes)

        let editionAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 3.8, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.74)
        ]
        ("PRIVATE PROFILE" as NSString).draw(at: CGPoint(x: 48, y: 7), withAttributes: editionAttributes)

        let chip = UIBezierPath(roundedRect: CGRect(x: 7, y: 18, width: 13, height: 9), cornerRadius: 2)
        UIColor.white.withAlphaComponent(0.14).setFill()
        chip.fill()
        UIColor.white.withAlphaComponent(0.60).setStroke()
        chip.lineWidth = 0.55
        chip.stroke()
        let chipLine = UIBezierPath()
        chipLine.move(to: CGPoint(x: 13.5, y: 19))
        chipLine.addLine(to: CGPoint(x: 13.5, y: 26))
        UIColor.white.withAlphaComponent(0.42).setStroke()
        chipLine.lineWidth = 0.45
        chipLine.stroke()

        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7.2, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        let nameParagraph = NSMutableParagraphStyle()
        nameParagraph.lineBreakMode = .byTruncatingTail
        var nameTextAttributes = nameAttributes
        nameTextAttributes[.paragraphStyle] = nameParagraph
        let safeName = displayName.isEmpty ? "BIOGRAM MEMBER" : displayName.uppercased()
        (safeName as NSString).draw(
            in: CGRect(x: 7, y: 30, width: 68, height: 9),
            withAttributes: nameTextAttributes
        )

        let handle = username.hasPrefix("@") ? username : "@\(username)"
        let handleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 5.0, weight: .medium),
            .foregroundColor: UIColor.white.withAlphaComponent(0.80)
        ]
        (handle as NSString).draw(at: CGPoint(x: 7, y: 39), withAttributes: handleAttributes)

        let signatureAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 3.8, weight: .medium),
            .foregroundColor: UIColor.white.withAlphaComponent(0.70)
        ]
        (biogramCardSignature(userId) as NSString).draw(at: CGPoint(x: 7, y: 46), withAttributes: signatureAttributes)
    }
}

private final class BiogramCardArtworkPickerDelegate: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    static let shared = BiogramCardArtworkPickerDelegate()
    var onPicked: ((UIImage?) -> Void)?

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let image = (info[.originalImage] as? UIImage) ?? (info[.editedImage] as? UIImage)
        self.onPicked?(image)
        picker.dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

private final class BiogramActionButton: UIButton {
    var handler: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addTarget(self, action: #selector(runHandler), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func runHandler() {
        self.handler?()
    }
}

private final class BiogramProfileCardDesignerController: ViewController {
    private let context: AccountContext
    private let accountId: String
    private let userId: String
    private var username = "@BIOGRAM"
    private var displayName = "BIOGRAM MEMBER"
    private var style: BiogramProfileCardStyle
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let cardView = Biogram3DProfileCardView()

    init(context: AccountContext, accountId: String, userId: String) {
        self.context = context
        self.accountId = accountId
        self.userId = userId
        self.style = BiogramManager.shared.profileCardStyle
        super.init(navigationBarPresentationData: nil)
    }

    required init(coder: NSCoder) { fatalError() }

    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNode.backgroundColor = biogramCardColor("#09090B")
        let root = self.displayNode.view
        root.backgroundColor = biogramCardColor("#09090B")

        self.scrollView.alwaysBounceVertical = true
        self.scrollView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(self.scrollView)
        self.contentStack.axis = .vertical
        self.contentStack.alignment = .fill
        self.contentStack.spacing = 17
        self.contentStack.translatesAutoresizingMaskIntoConstraints = false
        self.scrollView.addSubview(self.contentStack)
        NSLayoutConstraint.activate([
            self.scrollView.topAnchor.constraint(equalTo: root.safeAreaLayoutGuide.topAnchor),
            self.scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            self.scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            self.scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            self.contentStack.topAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.topAnchor, constant: 18),
            self.contentStack.leadingAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.leadingAnchor, constant: 18),
            self.contentStack.trailingAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.trailingAnchor, constant: -18),
            self.contentStack.bottomAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.bottomAnchor, constant: -28),
            self.contentStack.widthAnchor.constraint(equalTo: self.scrollView.frameLayoutGuide.widthAnchor, constant: -36)
        ])

        self.addTopBar()
        self.addCardPreview()
        self.addArtworkControls()
        self.addPaletteControls()
        self.addMaterialControls()
        self.addFooter()
        self.refreshCard()
        self.loadCurrentTelegramIdentity()
    }

    private func label(_ text: String, size: CGFloat, weight: UIFont.Weight = .regular, color: UIColor = .white, lines: Int = 0) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.numberOfLines = lines
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.78
        return label
    }

    private func button(_ title: String, selected: Bool = false, handler: @escaping () -> Void) -> UIButton {
        let button = BiogramActionButton(frame: .zero)
        button.handler = handler
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        button.setTitleColor(selected ? biogramCardColor("#121214") : .white, for: .normal)
        button.backgroundColor = selected ? biogramCardColor("#E7D7C0") : biogramCardColor("#202024")
        button.layer.cornerRadius = 12
        button.layer.borderWidth = selected ? 0 : 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
        button.contentEdgeInsets = UIEdgeInsets(top: 11, left: 12, bottom: 11, right: 12)
        return button
    }

    private func addTopBar() {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.distribution = .equalSpacing
        row.addArrangedSubview(self.button("‹  Biogram") { [weak self] in self?.dismiss(animated: true) })
        row.addArrangedSubview(self.label("CARD STUDIO", size: 10, weight: .bold, color: biogramCardColor("#E7D7C0")))
        self.contentStack.addArrangedSubview(row)
        self.contentStack.addArrangedSubview(self.label("Your profile. Your signature.", size: 25, weight: .semibold, color: .white, lines: 2))
        self.contentStack.addArrangedSubview(self.label("A two-sided profile card with real perspective, touch tilt and separate front/back layers.", size: 13, color: UIColor.white.withAlphaComponent(0.57), lines: 0))
    }

    private func addCardPreview() {
        self.cardView.translatesAutoresizingMaskIntoConstraints = false
        self.contentStack.addArrangedSubview(self.cardView)
        self.cardView.heightAnchor.constraint(equalTo: self.cardView.widthAnchor, multiplier: 0.63).isActive = true
        self.contentStack.addArrangedSubview(self.label("TAP TO FLIP  ·  DRAG TO TILT", size: 9, weight: .semibold, color: UIColor.white.withAlphaComponent(0.48)))
    }

    private func addArtworkControls() {
        self.contentStack.addArrangedSubview(self.label("FRONT ARTWORK", size: 10, weight: .bold, color: biogramCardColor("#E7D7C0")))
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 8
        row.addArrangedSubview(self.button("Choose image") { [weak self] in self?.chooseArtwork() })
        row.addArrangedSubview(self.button("Use color only") { [weak self] in
            guard let self else { return }
            BiogramManager.shared.setProfileCardImage(nil) { [weak self] in
                guard let self else { return }
                self.refreshCard()
            }
        })
        self.contentStack.addArrangedSubview(row)
    }

    private func addPaletteControls() {
        self.contentStack.addArrangedSubview(self.label("COLOR MATERIAL", size: 10, weight: .bold, color: biogramCardColor("#E7D7C0")))
        let paletteNames = BiogramProfileColor.presets.map { $0.0 }
        for start in stride(from: 0, to: paletteNames.count, by: 2) {
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = 8
            for name in paletteNames[start..<min(start + 2, paletteNames.count)] {
                let (main, _) = biogramCardPalette(name)
                let selected = self.style.paletteName == name
                let choice = self.button("●   \(name)", selected: selected) { [weak self] in
                    guard let self else { return }
                    self.style.paletteName = name
                    self.saveStyle()
                }
                choice.setTitleColor(selected ? biogramCardColor("#111114") : main, for: .normal)
                row.addArrangedSubview(choice)
            }
            if row.arrangedSubviews.count == 1 {
                row.addArrangedSubview(UIView())
            }
            self.contentStack.addArrangedSubview(row)
        }
    }

    private func addMaterialControls() {
        self.contentStack.addArrangedSubview(self.label("SURFACE FINISH", size: 10, weight: .bold, color: biogramCardColor("#E7D7C0")))
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 8
        for (title, value) in BiogramProfileCardStyle.materials {
            row.addArrangedSubview(self.button(title, selected: self.style.material == value) { [weak self] in
                guard let self else { return }
                self.style.material = value
                self.saveStyle()
            })
        }
        self.contentStack.addArrangedSubview(row)
    }

    private func addFooter() {
        self.contentStack.addArrangedSubview(self.label("The member serial and profile signature are decorative identity details, not credentials. Your card artwork and material synchronize with your Biogram profile.", size: 11, color: UIColor.white.withAlphaComponent(0.43), lines: 0))
    }

    private func chooseArtwork() {
        guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else { return }
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        picker.delegate = BiogramCardArtworkPickerDelegate.shared
        BiogramCardArtworkPickerDelegate.shared.onPicked = { [weak self] image in
            guard let self, let image else { return }
            BiogramManager.shared.setProfileCardImage(image) { [weak self] in
                guard let self else { return }
                self.refreshCard()
            }
        }
        self.present(PickerWrapper(picker: picker), in: .window(.root), with: nil)
    }

    private func saveStyle() {
        BiogramManager.shared.setProfileCardStyle(self.style) { [weak self] in
            guard let self else { return }
            self.refreshCard()
        }
    }

    private func refreshCard() {
        self.style = BiogramManager.shared.profileCardStyle
        self.cardView.configure(
            style: self.style,
            image: BiogramManager.shared.profileCardImage(),
            displayName: self.displayName,
            username: self.username,
            userId: self.userId,
            aliases: BiogramManager.shared.aliases(),
            publicNumbers: BiogramManager.shared.cloudProfilePayload().publicNumbers
        )
        self.view.setNeedsLayout()
    }

    private func loadCurrentTelegramIdentity() {
        let signal = self.context.engine.data.subscribe(
            TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId)
        )
        |> take(1)
        |> deliverOnMainQueue
        let _ = signal.start(next: { [weak self] peer in
            guard let self, let peer else { return }
            self.displayName = peer.compactDisplayTitle
            if let username = peer.usernames.first(where: { $0.flags.contains(.isActive) })?.username, !username.isEmpty {
                self.username = "@\(username)"
            } else {
                self.username = "@biogram"
            }
            self.refreshCard()
        })
    }
}


private final class BiogramProfileCardViewerController: ViewController {
    private let profile: BiogramCloudPublicProfile
    private let cardView = Biogram3DProfileCardView()
    private let dimView = UIView()
    private let backgroundBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let stack = UIStackView()
    private var isClosing = false

    init(profile: BiogramCloudPublicProfile) {
        self.profile = profile
        super.init(navigationBarPresentationData: nil)
    }

    required init(coder: NSCoder) { fatalError() }

    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNode.backgroundColor = .clear

        let root = self.displayNode.view
        root.backgroundColor = .clear
        root.isOpaque = false

        self.dimView.backgroundColor = UIColor.black.withAlphaComponent(0.62)
        self.dimView.alpha = 0.0
        self.dimView.translatesAutoresizingMaskIntoConstraints = false
        self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(closeViewer)))
        root.addSubview(self.dimView)

        self.backgroundBlur.alpha = 0.0
        self.backgroundBlur.isUserInteractionEnabled = false
        self.backgroundBlur.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(self.backgroundBlur)

        self.stack.axis = .vertical
        self.stack.alignment = .fill
        self.stack.spacing = 18
        self.stack.alpha = 0.0
        self.stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(self.stack)

        let top = UIStackView()
        top.axis = .horizontal
        top.alignment = .center
        top.distribution = .equalSpacing

        let title = UILabel()
        title.text = "BIOGRAM CARD"
        title.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .bold)
        title.textColor = biogramCardColor("#E6D7C5")

        top.addArrangedSubview(title)
        self.stack.addArrangedSubview(top)

        let heading = UILabel()
        heading.text = "Your Biogram card"
        heading.font = UIFont.systemFont(ofSize: 25, weight: .semibold)
        heading.textColor = .white
        heading.numberOfLines = 2
        self.stack.addArrangedSubview(heading)

        let subtitle = UILabel()
        subtitle.text = "A custom two-sided identity card. Tap to reveal its profile details and visual hash."
        subtitle.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        subtitle.textColor = UIColor.white.withAlphaComponent(0.58)
        subtitle.numberOfLines = 0
        self.stack.addArrangedSubview(subtitle)

        self.cardView.translatesAutoresizingMaskIntoConstraints = false
        self.stack.addArrangedSubview(self.cardView)
        self.cardView.alpha = 0.0
        self.cardView.transform = CGAffineTransform(scaleX: 0.68, y: 0.68).translatedBy(x: 0, y: 28)
        self.cardView.heightAnchor.constraint(equalTo: self.cardView.widthAnchor, multiplier: 0.63).isActive = true

        let hint = UILabel()
        hint.text = "FRONT / BACK  ·  PROFILE DETAILS  ·  VISUAL HASH"
        hint.font = UIFont.monospacedSystemFont(ofSize: 8, weight: .medium)
        hint.textColor = UIColor.white.withAlphaComponent(0.42)
        hint.numberOfLines = 0
        hint.textAlignment = .center
        self.stack.addArrangedSubview(hint)

        NSLayoutConstraint.activate([
            self.dimView.topAnchor.constraint(equalTo: root.topAnchor),
            self.dimView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            self.dimView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            self.dimView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            self.backgroundBlur.topAnchor.constraint(equalTo: root.topAnchor),
            self.backgroundBlur.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            self.backgroundBlur.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            self.backgroundBlur.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            self.stack.centerYAnchor.constraint(equalTo: root.centerYAnchor),
            self.stack.topAnchor.constraint(greaterThanOrEqualTo: root.safeAreaLayoutGuide.topAnchor, constant: 16),
            self.stack.bottomAnchor.constraint(lessThanOrEqualTo: root.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            self.stack.leadingAnchor.constraint(equalTo: root.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            self.stack.trailingAnchor.constraint(equalTo: root.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            self.cardView.widthAnchor.constraint(lessThanOrEqualToConstant: 560)
        ])

        self.cardView.configure(
            style: self.profile.cardStyle,
            image: self.profile.cardImage,
            displayName: self.profile.displayName,
            username: self.profile.username.map { "@\($0)" } ?? "@biogram",
            userId: self.profile.telegramId,
            aliases: self.profile.aliases,
            publicNumbers: self.profile.publicNumbers
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.cardView.layer.removeAllAnimations()
        UIView.animate(
            withDuration: 0.58,
            delay: 0.04,
            usingSpringWithDamping: 0.78,
            initialSpringVelocity: 0.55,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: {
                self.dimView.alpha = 1.0
                self.backgroundBlur.alpha = 0.62
                self.stack.alpha = 1.0
                self.cardView.alpha = 1.0
                self.cardView.transform = .identity
            }
        )
    }

    @objc private func closeViewer() {
        guard !self.isClosing, self.viewIfLoaded?.window != nil else { return }
        self.isClosing = true
        UIView.animate(
            withDuration: 0.24,
            delay: 0.0,
            options: [.curveEaseIn, .beginFromCurrentState],
            animations: {
                self.dimView.alpha = 0.0
                self.backgroundBlur.alpha = 0.0
                self.stack.alpha = 0.0
                self.cardView.alpha = 0.0
                self.cardView.transform = CGAffineTransform(scaleX: 0.72, y: 0.72).translatedBy(x: 0, y: 20)
            },
            completion: { _ in
                self.dismiss(animated: false)
            }
        )
    }
}

public func biogramProfileCardViewerController(
    context: AccountContext,
    profile: BiogramCloudPublicProfile
) -> ViewController {
    return BiogramProfileCardViewerController(profile: profile)
}
