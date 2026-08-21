import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import PresentationDataUtils
import Biogram

private enum BiogramSection: Int32 {
    case premium
    case numbers
    case aliases
    case collectibles
}

private enum BiogramEntry: ItemListNodeEntry {
    case premiumHeader(PresentationTheme)
    case premiumToggle(PresentationTheme, String, Bool)
    
    case numbersHeader(PresentationTheme)
    case number(PresentationTheme, Int, BiogramVirtualNumber)
    case addNumber(PresentationTheme, String)
    
    case aliasesHeader(PresentationTheme)
    case alias(PresentationTheme, Int, String)
    case addAlias(PresentationTheme, String)
    
    case collectiblesHeader(PresentationTheme)
    case collectible(PresentationTheme, Int, BiogramCollectible)
    case addCollectible(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
        case .premiumHeader, .premiumToggle:
            return BiogramSection.premium.rawValue
        case .numbersHeader, .number, .addNumber:
            return BiogramSection.numbers.rawValue
        case .aliasesHeader, .alias, .addAlias:
            return BiogramSection.aliases.rawValue
        case .collectiblesHeader, .collectible, .addCollectible:
            return BiogramSection.collectibles.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .premiumHeader: return 0
        case .premiumToggle: return 1
        case .numbersHeader: return 100
        case let .number(_, index, _): return 101 + Int32(index)
        case .addNumber: return 199
        case .aliasesHeader: return 200
        case let .alias(_, index, _): return 201 + Int32(index)
        case .addAlias: return 299
        case .collectiblesHeader: return 300
        case let .collectible(_, index, _): return 301 + Int32(index)
        case .addCollectible: return 399
        }
    }
    
    static func <(lhs: BiogramEntry, rhs: BiogramEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! BiogramArguments
        switch self {
        case let .premiumHeader(theme):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "LOCAL PREMIUM", sectionId: self.section)
        case let .premiumToggle(_, title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.togglePremium(value)
            })
        case .numbersHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "VIRTUAL NUMBERS", sectionId: self.section)
        case let .number(_, _, number):
            return ItemListDisclosureItem(presentationData: presentationData, title: number.label ?? number.number, label: number.number, sectionId: self.section, style: .blocks, action: {
                arguments.removeNumber(number.id)
            })
        case let .addNumber(_, title):
            return ItemListActionItem(presentationData: presentationData, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.addNumber()
            })
        case .aliasesHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ALIASES / USERNAMES", sectionId: self.section)
        case let .alias(_, _, alias):
            return ItemListDisclosureItem(presentationData: presentationData, title: "@\(alias)", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.removeAlias(alias)
            })
        case let .addAlias(_, title):
            return ItemListActionItem(presentationData: presentationData, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.addAlias()
            })
        case .collectiblesHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "COLLECTIBLES", sectionId: self.section)
        case let .collectible(_, _, item):
            return ItemListDisclosureItem(presentationData: presentationData, title: item.title ?? item.id, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.removeCollectible(item.id)
            })
        case let .addCollectible(_, title):
            return ItemListActionItem(presentationData: presentationData, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.addCollectible()
            })
        }
    }
}

private final class BiogramArguments {
    let context: AccountContext
    let togglePremium: (Bool) -> Void
    let addNumber: () -> Void
    let removeNumber: (String) -> Void
    let addAlias: () -> Void
    let removeAlias: (String) -> Void
    let addCollectible: () -> Void
    let removeCollectible: (String) -> Void
    
    init(context: AccountContext, togglePremium: @escaping (Bool) -> Void, addNumber: @escaping () -> Void, removeNumber: @escaping (String) -> Void, addAlias: @escaping () -> Void, removeAlias: @escaping (String) -> Void, addCollectible: @escaping () -> Void, removeCollectible: @escaping (String) -> Void) {
        self.context = context
        self.togglePremium = togglePremium
        self.addNumber = addNumber
        self.removeNumber = removeNumber
        self.addAlias = addAlias
        self.removeAlias = removeAlias
        self.addCollectible = addCollectible
        self.removeCollectible = removeCollectible
    }
}

private func biogramEntries(presentationData: PresentationData, premiumEnabled: Bool, numbers: [BiogramVirtualNumber], aliases: [String], collectibles: [BiogramCollectible]) -> [BiogramEntry] {
    var entries: [BiogramEntry] = []
    
    entries.append(.premiumHeader(presentationData.theme))
    entries.append(.premiumToggle(presentationData.theme, "Local Premium", premiumEnabled))
    
    entries.append(.numbersHeader(presentationData.theme))
    for (i, n) in numbers.enumerated() {
        entries.append(.number(presentationData.theme, i, n))
    }
    entries.append(.addNumber(presentationData.theme, "Add Virtual Number"))
    
    entries.append(.aliasesHeader(presentationData.theme))
    for (i, a) in aliases.enumerated() {
        entries.append(.alias(presentationData.theme, i, a))
    }
    entries.append(.addAlias(presentationData.theme, "Add Alias"))
    
    entries.append(.collectiblesHeader(presentationData.theme))
    for (i, c) in collectibles.enumerated() {
        entries.append(.collectible(presentationData.theme, i, c))
    }
    entries.append(.addCollectible(presentationData.theme, "Add Collectible"))
    
    return entries
}

public func biogramSettingsController(context: AccountContext) -> ViewController {
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let arguments = BiogramArguments(
        context: context,
        togglePremium: { enabled in
            BiogramManager.shared.setLocalPremiumEnabled(enabled)
        },
        addNumber: {
            // простой prompt
            let alert = textAlertController(
                context: context,
                title: "Virtual Number",
                text: "Enter number (e.g. +888 123456)",
                actions: [
                    TextAlertAction(type: .genericAction, title: "Cancel", action: {}),
                    TextAlertAction(type: .defaultAction, title: "Add", action: {
                        // пока заглушка — добавим нормальный input позже
                        let number = BiogramVirtualNumber(number: "+888 \(Int.random(in: 100000...999999))")
                        BiogramManager.shared.addVirtualNumber(number)
                    })
                ]
            )
            presentControllerImpl?(alert, nil)
        },
        removeNumber: { id in
            BiogramManager.shared.removeVirtualNumber(id: id)
        },
        addAlias: {
            let alert = textAlertController(
                context: context,
                title: "Alias",
                text: "Enter username without @",
                actions: [
                    TextAlertAction(type: .genericAction, title: "Cancel", action: {}),
                    TextAlertAction(type: .defaultAction, title: "Add", action: {
                        let alias = "alias\(Int.random(in: 100...999))"
                        BiogramManager.shared.addAlias(alias)
                    })
                ]
            )
            presentControllerImpl?(alert, nil)
        },
        removeAlias: { alias in
            BiogramManager.shared.removeAlias(alias)
        },
        addCollectible: {
            let item = BiogramCollectible(title: "Collectible \(Int.random(in: 1...99))", assetFilename: "placeholder", assetType: "image")
            BiogramManager.shared.addCollectible(item)
        },
        removeCollectible: { id in
            BiogramManager.shared.removeCollectible(id: id)
        }
    )
    
    let signal = context.sharedContext.presentationData
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let premium = BiogramManager.shared.localPremiumEnabled
        let numbers = BiogramManager.shared.virtualNumbers()
        let aliases = BiogramManager.shared.aliases()
        let collectibles = BiogramManager.shared.collectibles()
        
        let entries = biogramEntries(presentationData: presentationData, premiumEnabled: premium, numbers: numbers, aliases: aliases, collectibles: collectibles)
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Biogram"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks
        )
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    return controller
}
