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

private final class BiogramTextInputController: ViewController {
    private let titleText: String
    private let messageText: String
    private let initialValue: String
    private let placeholder: String
    private let actionTitle: String
    private let cancelTitle: String
    private let onAction: (String) -> Bool
    
    private var textField: UITextField?
    
    init(
        title: String,
        text: String,
        value: String,
        placeholder: String,
        actionTitle: String,
        cancelTitle: String,
        action: @escaping (String) -> Bool
    ) {
        self.titleText = title
        self.messageText = text
        self.initialValue = value
        self.placeholder = placeholder
        self.actionTitle = actionTitle
        self.cancelTitle = cancelTitle
        self.onAction = action
        super.init(navigationBarPresentationData: nil)
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNode.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        
        let alert = UIAlertController(title: titleText, message: messageText, preferredStyle: .alert)
        alert.addTextField { [weak self] tf in
            guard let self = self else { return }
            tf.text = self.initialValue
            tf.placeholder = self.placeholder
            tf.keyboardType = .default
            tf.autocapitalizationType = .none
            tf.autocorrectionType = .no
            self.textField = tf
        }
        alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel, handler: { [weak self] _ in
            self?.close()
        }))
        alert.addAction(UIAlertAction(title: actionTitle, style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            let value = self.textField?.text ?? ""
            if self.onAction(value) {
                self.close()
            }
        }))
        
            Queue.mainQueue().after(0.05) { [weak self] in
        guard let self = self else {
            return
        }

        guard let root = self.view.window?.rootViewController else {
            return
        }

        var top: UIViewController = root

        while let presented = top.presentedViewController {
            top = presented
        }

        top.present(alert, animated: true)
    }

    private func close() {
        self.dismiss(animated: false)
    }
}

private func biogramPrompt(
    title: String,
    text: String,
    value: String,
    placeholder: String,
    actionTitle: String,
    cancelTitle: String,
    action: @escaping (String) -> Bool
) -> ViewController {
    return BiogramTextInputController(
        title: title,
        text: text,
        value: value,
        placeholder: placeholder,
        actionTitle: actionTitle,
        cancelTitle: cancelTitle,
        action: action
    )
}

private enum BiogramSection: Int32 {
    case premium = 0
    case numbers = 1
    case aliases = 2
    case color = 3
    case collectibles = 4
    case info = 5
}

private final class BiogramControllerState: Equatable {
    let premiumEnabled: Bool
    let numbers: [BiogramVirtualNumber]
    let aliases: [String]
    let collectibles: [BiogramCollectible]
    let profileColorEnabled: Bool
    let profileColor: BiogramProfileColor?
    
    init(
        premiumEnabled: Bool,
        numbers: [BiogramVirtualNumber],
        aliases: [String],
        collectibles: [BiogramCollectible],
        profileColorEnabled: Bool,
        profileColor: BiogramProfileColor?
    ) {
        self.premiumEnabled = premiumEnabled
        self.numbers = numbers
        self.aliases = aliases
        self.collectibles = collectibles
        self.profileColorEnabled = profileColorEnabled
        self.profileColor = profileColor
    }
    
    static func ==(lhs: BiogramControllerState, rhs: BiogramControllerState) -> Bool {
        return lhs.premiumEnabled == rhs.premiumEnabled
            && lhs.numbers == rhs.numbers
            && lhs.aliases == rhs.aliases
            && lhs.collectibles == rhs.collectibles
            && lhs.profileColorEnabled == rhs.profileColorEnabled
            && lhs.profileColor == rhs.profileColor
    }
    
    static func current() -> BiogramControllerState {
        return BiogramControllerState(
            premiumEnabled: BiogramManager.shared.localPremiumEnabled,
            numbers: BiogramManager.shared.virtualNumbers(),
            aliases: BiogramManager.shared.aliases(),
            collectibles: BiogramManager.shared.collectibles(),
            profileColorEnabled: BiogramManager.shared.profileColorEnabled,
            profileColor: BiogramManager.shared.profileColor
        )
    }
}

private enum BiogramEntryId: Hashable {
    case premiumHeader
    case premiumToggle
    case numbersHeader
    case number(String)
    case addNumber
    case aliasesHeader
    case alias(String)
    case addAlias
    case colorHeader
    case colorToggle
    case colorPreset(String)
    case colorBrightness
    case collectiblesHeader
    case collectible(String)
    case browseCatalog
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
    case browseCatalog
    case info
    
    var section: ItemListSectionId {
        switch self {
        case .premiumHeader, .premiumToggle: return BiogramSection.premium.rawValue
        case .numbersHeader, .number, .addNumber: return BiogramSection.numbers.rawValue
        case .aliasesHeader, .alias, .addAlias: return BiogramSection.aliases.rawValue
        case .colorHeader, .colorToggle, .colorPreset, .colorBrightness: return BiogramSection.color.rawValue
        case .collectiblesHeader, .collectible, .browseCatalog: return BiogramSection.collectibles.rawValue
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
        case .browseCatalog: return .browseCatalog
        case .info: return .info
        }
    }
    
    static func <(lhs: BiogramEntry, rhs: BiogramEntry) -> Bool {
        if lhs.section != rhs.section { return lhs.section < rhs.section }
        switch (lhs, rhs) {
        case (.premiumHeader, _): return true
        case (_, .premiumHeader): return false
        case (.premiumToggle, _): return true
        case (_, .premiumToggle): return false
        case (.numbersHeader, _): return true
        case (_, .numbersHeader): return false
        case let (.number(li, _), .number(ri, _)): return li < ri
        case (.number, _): return true
        case (_, .number): return false
        case (.addNumber, _): return true
        case (_, .addNumber): return false
        case (.aliasesHeader, _): return true
        case (_, .aliasesHeader): return false
        case let (.alias(li, _), .alias(ri, _)): return li < ri
        case (.alias, _): return true
        case (_, .alias): return false
        case (.addAlias, _): return true
        case (_, .addAlias): return false
        case (.colorHeader, _): return true
        case (_, .colorHeader): return false
        case (.colorToggle, _): return true
        case (_, .colorToggle): return false
        case let (.colorPreset(ln, _, _), .colorPreset(rn, _, _)): return ln < rn
        case (.colorPreset, _): return true
        case (_, .colorPreset): return false
        case (.colorBrightness, _): return true
        case (_, .colorBrightness): return false
        case (.collectiblesHeader, _): return true
        case (_, .collectiblesHeader): return false
        case let (.collectible(li, _), .collectible(ri, _)): return li < ri
        case (.collectible, _): return true
        case (_, .collectible): return false
        case (.browseCatalog, _): return true
        case (_, .browseCatalog): return false
        case (.info, .info): return false
        default: return false
        }
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! BiogramArguments
        switch self {
        case .premiumHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "LOCAL PREMIUM", sectionId: self.section)
        case let .premiumToggle(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Local Premium", value: value, sectionId: self.section, style: .blocks, updated: { newValue in
                arguments.togglePremium(newValue)
            })
        case .numbersHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "VIRTUAL / ANONYMOUS NUMBERS", sectionId: self.section)
        case let .number(_, number):
            let title = number.label ?? number.number
            let label = number.label != nil ? number.number : "Tap to edit / remove"
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.editOrRemoveNumber(number)
            })
        case .addNumber:
            return ItemListActionItem(presentationData: presentationData, title: "Add Number", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.addNumber()
            })
        case .aliasesHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ALIASES / USERNAMES", sectionId: self.section)
        case let .alias(_, alias):
            return ItemListDisclosureItem(presentationData: presentationData, title: "@\(alias)", label: "Tap to edit / remove", sectionId: self.section, style: .blocks, action: {
                arguments.editOrRemoveAlias(alias)
            })
        case .addAlias:
            return ItemListActionItem(presentationData: presentationData, title: "Add Alias", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.addAlias()
            })
        case .colorHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "PROFILE COLOR", sectionId: self.section)
        case let .colorToggle(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Custom profile color", value: value, sectionId: self.section, style: .blocks, updated: { newValue in
                arguments.toggleColor(newValue)
            })
        case let .colorPreset(name, color, selected):
            return ItemListDisclosureItem(presentationData: presentationData, title: name, label: selected ? "✓" : "", sectionId: self.section, style: .blocks, action: {
                arguments.selectPreset(color)
            })
        case let .colorBrightness(value):
            let percent = Int((value * 100.0).rounded())
            return ItemListDisclosureItem(presentationData: presentationData, title: "Brightness", label: "\(percent)%", sectionId: self.section, style: .blocks, action: {
                arguments.pickBrightness()
            })
        case .collectiblesHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "COLLECTIBLES / GIFTS", sectionId: self.section)
        case let .collectible(_, item):
            return ItemListDisclosureItem(presentationData: presentationData, title: item.title ?? item.id, label: "Tap to remove", sectionId: self.section, style: .blocks, action: {
                arguments.removeCollectible(item.id)
            })
        case .browseCatalog:
            return ItemListActionItem(presentationData: presentationData, title: "Browse Gift Catalog", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.browseCatalog()
            })
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
    let browseCatalog: () -> Void
    
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
        browseCatalog: @escaping () -> Void
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
        self.browseCatalog = browseCatalog
    }
}

private func biogramControllerEntries(state: BiogramControllerState) -> [BiogramEntry] {
    var entries: [BiogramEntry] = []
    
    entries.append(.premiumHeader)
    entries.append(.premiumToggle(state.premiumEnabled))
    
    entries.append(.numbersHeader)
    for (i, n) in state.numbers.enumerated() {
        entries.append(.number(i, n))
    }
    entries.append(.addNumber)
    
    entries.append(.aliasesHeader)
    for (i, a) in state.aliases.enumerated() {
        entries.append(.alias(i, a))
    }
    entries.append(.addAlias)
    
    entries.append(.colorHeader)
    entries.append(.colorToggle(state.profileColorEnabled))
    if state.profileColorEnabled {
        let current = state.profileColor
        for (name, preset) in BiogramProfileColor.presets {
            let selected = current != nil &&
                abs(current!.r - preset.r) < 0.01 &&
                abs(current!.g - preset.g) < 0.01 &&
                abs(current!.b - preset.b) < 0.01
            entries.append(.colorPreset(name, preset, selected))
        }
        entries.append(.colorBrightness(current?.brightness ?? 1.0))
    }
    
    entries.append(.collectiblesHeader)
    for (i, c) in state.collectibles.enumerated() {
        entries.append(.collectible(i, c))
    }
    entries.append(.browseCatalog)
    
    entries.append(.info)
    
    return entries
}

public func biogramSettingsController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise(BiogramControllerState.current(), ignoreRepeated: true)
    let stateValue = Atomic(value: BiogramControllerState.current())
    
    let updateState: (() -> Void) = {
        let newState = BiogramControllerState.current()
        let _ = stateValue.swap(newState)
        statePromise.set(newState)
    }
    
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    
        let arguments = BiogramArguments(
        togglePremium: { enabled in
            BiogramManager.shared.setLocalPremiumEnabled(enabled) {
                Queue.mainQueue().async { updateState() }
            }
            updateState()
        },
        addNumber: {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let controller = biogramPrompt(
                title: "Enter number",
                text: "Virtual / anonymous number",
                value: "+888 ",
                placeholder: "+888 00001212",
                actionTitle: presentationData.strings.Common_Done,
                cancelTitle: presentationData.strings.Common_Cancel,
                action: { value in
                    let trimmed = value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return false }
                    let number = BiogramVirtualNumber(number: trimmed)
                    BiogramManager.shared.addVirtualNumber(number) {
                        Queue.mainQueue().async { updateState() }
                    }
                    updateState()
                    return true
                }
            )
            presentControllerImpl?(controller, nil)
        },
editOrRemoveNumber: { number in
    let alert = BiogramActionsAlertController(
        title: number.number,
        message: "Edit or remove this number",
        actions: [
            (
                title: "Edit",
                destructive: false,
                action: {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }

                    let editCtrl = biogramPrompt(
                        title: "Number",
                        text: "Edit number",
                        value: number.number,
                        placeholder: "+888 ...",
                        actionTitle: presentationData.strings.Common_Done,
                        cancelTitle: presentationData.strings.Common_Cancel,
                        action: { value in
                            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

                            guard !trimmed.isEmpty else {
                                return false
                            }

                            BiogramManager.shared.updateVirtualNumber(
                                id: number.id,
                                number: trimmed,
                                label: number.label
                            ) {
                                Queue.mainQueue().async {
                                    updateState()
                                }
                            }

                            updateState()
                            return true
                        }
                    )

                    presentControllerImpl?(editCtrl, nil)
                }
            ),
            (
                title: "Delete",
                destructive: true,
                action: {
                    BiogramManager.shared.removeVirtualNumber(id: number.id) {
                        Queue.mainQueue().async {
                            updateState()
                        }
                    }

                    updateState()
                }
            )
        ]
    )

    presentControllerImpl?(alert, nil)
},
        addAlias: {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let controller = biogramPrompt(
                title: "Enter username",
                text: "Alias / username (without @)",
                value: "",
                placeholder: "username",
                actionTitle: presentationData.strings.Common_Done,
                cancelTitle: presentationData.strings.Common_Cancel,
                action: { value in
                    var trimmed = value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    if trimmed.hasPrefix("@") {
                        trimmed = String(trimmed.dropFirst())
                    }
                    guard !trimmed.isEmpty else { return false }
                    BiogramManager.shared.addAlias(trimmed) {
                        Queue.mainQueue().async { updateState() }
                    }
                    updateState()
                    return true
                }
            )
            presentControllerImpl?(controller, nil)
        },
editOrRemoveAlias: { alias in
    let alert = BiogramActionsAlertController(
        title: alias.username,
        message: "Edit or remove this username",
        actions: [
            (
                title: "Edit",
                destructive: false,
                action: {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }

                    let editCtrl = biogramPrompt(
                        title: "Username",
                        text: "Edit username",
                        value: alias.username,
                        placeholder: "@username",
                        actionTitle: presentationData.strings.Common_Done,
                        cancelTitle: presentationData.strings.Common_Cancel,
                        action: { value in
                            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

                            guard !trimmed.isEmpty else {
                                return false
                            }

                            BiogramManager.shared.replaceAlias(
                                id: alias.id,
                                username: trimmed
                            ) {
                                Queue.mainQueue().async {
                                    updateState()
                                }
                            }

                            updateState()
                            return true
                        }
                    )

                    presentControllerImpl?(editCtrl, nil)
                }
            ),
            (
                title: "Delete",
                destructive: true,
                action: {
                    BiogramManager.shared.removeAlias(id: alias.id) {
                        Queue.mainQueue().async {
                            updateState()
                        }
                    }

                    updateState()
                }
            )
        ]
    )

    presentControllerImpl?(alert, nil)
},
        toggleColor: { enabled in
            let current = BiogramManager.shared.profileColor ?? BiogramProfileColor.presets[0].1
            BiogramManager.shared.setProfileColor(current, enabled: enabled) {
                Queue.mainQueue().async { updateState() }
            }
            updateState()
        },
        selectPreset: { color in
            let brightness = BiogramManager.shared.profileColor?.brightness ?? 1.0
            let newColor = BiogramProfileColor(r: color.r, g: color.g, b: color.b, brightness: brightness)
            BiogramManager.shared.setProfileColor(newColor, enabled: true) {
                Queue.mainQueue().async { updateState() }
            }
            updateState()
        },
        setBrightness: { value in
            guard var color = BiogramManager.shared.profileColor else { return }
            color.brightness = value
            BiogramManager.shared.setProfileColor(color, enabled: true) {
                Queue.mainQueue().async { updateState() }
            }
            updateState()
        },
pickBrightness: {
    let alert = BiogramActionsAlertController(
        title: "Brightness",
        message: "Choose shade intensity",
        actions: [
            (
                title: "30%",
                destructive: false,
                action: {
                    guard var color = BiogramManager.shared.profileColor else { return }
                    color.brightness = 0.3
                    BiogramManager.shared.setProfileColor(color, enabled: true) {
                        Queue.mainQueue().async { updateState() }
                    }
                    updateState()
                }
            ),
            (
                title: "50%",
                destructive: false,
                action: {
                    guard var color = BiogramManager.shared.profileColor else { return }
                    color.brightness = 0.5
                    BiogramManager.shared.setProfileColor(color, enabled: true) {
                        Queue.mainQueue().async { updateState() }
                    }
                    updateState()
                }
            ),
            (
                title: "70%",
                destructive: false,
                action: {
                    guard var color = BiogramManager.shared.profileColor else { return }
                    color.brightness = 0.7
                    BiogramManager.shared.setProfileColor(color, enabled: true) {
                        Queue.mainQueue().async { updateState() }
                    }
                    updateState()
                }
            ),
            (
                title: "85%",
                destructive: false,
                action: {
                    guard var color = BiogramManager.shared.profileColor else { return }
                    color.brightness = 0.85
                    BiogramManager.shared.setProfileColor(color, enabled: true) {
                        Queue.mainQueue().async { updateState() }
                    }
                    updateState()
                }
            ),
            (
                title: "100%",
                destructive: false,
                action: {
                    guard var color = BiogramManager.shared.profileColor else { return }
                    color.brightness = 1.0
                    BiogramManager.shared.setProfileColor(color, enabled: true) {
                        Queue.mainQueue().async { updateState() }
                    }
                    updateState()
                }
            ),
            (
                title: "115%",
                destructive: false,
                action: {
                    guard var color = BiogramManager.shared.profileColor else { return }
                    color.brightness = 1.15
                    BiogramManager.shared.setProfileColor(color, enabled: true) {
                        Queue.mainQueue().async { updateState() }
                    }
                    updateState()
                }
            ),
            (
                title: "120%",
                destructive: false,
                action: {
                    guard var color = BiogramManager.shared.profileColor else { return }
                    color.brightness = 1.2
                    BiogramManager.shared.setProfileColor(color, enabled: true) {
                        Queue.mainQueue().async { updateState() }
                    }
                    updateState()
                }
            )
        ]
    )

    presentControllerImpl?(alert, nil)
},
        removeCollectible: { id in
            BiogramManager.shared.removeCollectible(id: id) {
                Queue.mainQueue().async { updateState() }
            }
            updateState()
        },
 browseCatalog: {
    var giftActions: [(title: String, destructive: Bool, action: () -> Void)] = []

    for item in BiogramGiftCatalog.items {
        giftActions.append((
            title: item.title,
            destructive: false,
            action: {
                let collectible = BiogramCollectible(
                    title: item.title,
                    assetFilename: item.slug,
                    assetType: "gift",
                    giftSlug: item.slug
                )
                BiogramManager.shared.addCollectible(collectible) {
                    Queue.mainQueue().async { updateState() }
                }
                updateState()
            }
        ))
    }

    let alert = BiogramActionsAlertController(
        title: "Gift Catalog",
        message: "Choose a gift to add locally",
        actions: giftActions
    )

    presentControllerImpl?(alert, nil)
}
    )
    let signal = combineLatest(
        queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get()
    )
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
