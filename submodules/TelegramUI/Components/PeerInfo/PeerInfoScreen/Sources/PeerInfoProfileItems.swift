// MARK: Swiftgram
import SGSimpleSettings
import SGSettingsUI
import SGStrings
import CountrySelectionUI
import Foundation
import UIKit
import Display
import AccountContext
import TelegramPresentationData
import TelegramCore
import PeerInfoUI
import TextFormat
import PhoneNumberFormat
import SwiftSignalKit
import TelegramStringFormatting
import AsyncDisplayKit
import LocationResources
import AttachmentUI
import WebUI
import AvatarNode
import PeerNameColorItem
import BoostLevelIconComponent

private let enabledPublicBioEntities: EnabledEntityTypes = [.allUrl, .mention, .hashtag]
private let enabledPrivateBioEntities: EnabledEntityTypes = [.allUrl, .mention, .hashtag] // MARK: Swiftgram

enum InfoSection: Int, CaseIterable {
    case unofficial
    case community
    case swiftgram
    case groupLocation
    case calls
    case personalChannel
    case peerInfo
    case balances
    case permissions
    case peerInfoTrailing
    case peerSettings
    case peerMembers
    case channelMonoforum
    case botAffiliateProgram
}

func infoItems(
    nearestChatParticipant: (String?, Int32?), showProfileId: Bool, data: PeerInfoScreenData?,
    context: AccountContext,
    presentationData: PresentationData,
    interaction: PeerInfoInteraction,
    reactionSourceMessageId: EngineMessage.Id?,
    canDeleteReaction: Bool,
    callMessages: [EngineMessage],
    chatLocation: ChatLocation,
    isOpenedFromChat: Bool,
    isMyProfile: Bool
) -> [(AnyHashable, [PeerInfoScreenItem])] {
    guard let data = data else {
        return []
    }
    
    var currentPeerInfoSection: InfoSection = .peerInfo

    // MARK: Swiftgram
    var sgItemId = 0
    var idText = ""
    var isMutualContact = false
        
    var items: [InfoSection: [PeerInfoScreenItem]] = [:]
    for section in InfoSection.allCases {
        items[section] = []
    }
    
    let bioContextAction: (ASDisplayNode, ContextGesture?, CGPoint?) -> Void = { node, gesture, _ in
        interaction.openBioContextMenu(node, gesture)
    }
    let noteContextAction: (ASDisplayNode, ContextGesture?, CGPoint?) -> Void = { node, gesture, _ in
        interaction.openNoteContextMenu(node, gesture)
    }
    let bioLinkAction: (TextLinkItemActionType, TextLinkItem, ASDisplayNode, CGRect?, Promise<Bool>?) -> Void = { action, item, _, _, _ in
        interaction.performBioLinkAction(action, item)
    }
    let workingHoursContextAction: (ASDisplayNode, ContextGesture?, CGPoint?) -> Void = { node, gesture, _ in
        interaction.openWorkingHoursContextMenu(node, gesture)
    }
    let businessLocationContextAction: (ASDisplayNode, ContextGesture?, CGPoint?) -> Void = { node, gesture, _ in
        interaction.openBusinessLocationContextMenu(node, gesture)
    }
    let birthdayContextAction: (ASDisplayNode, ContextGesture?, CGPoint?) -> Void = { node, gesture, _ in
        interaction.openBirthdayContextMenu(node, gesture)
    }
    
    if case let .user(user) = data.peer {
        let ItemCallList = 1000
        let ItemPersonalChannelHeader = 2000
        let ItemPersonalChannel = 2001
        let ItemPhoneNumber = 3000
        let ItemUsername = 3001
        let ItemBirthdate = 3002
        let ItemAbout = 3003
        let ItemNote = 3004
        let ItemAppFooter = 3005
        let ItemAffiliate = 4000
        let ItemAffiliateInfo = 4001
        let ItemBusinessHours = 5000
        let ItemLocation = 5001
        let ItemAddToContacts = 6000
        let ItemDeleteReaction = 6001
        let ItemReport = 6002
        let ItemBlock = 6003
        let ItemEncryptionKey = 6004
        let ItemBalanceHeader = 7000
        let ItemBalanceTon = 7001
        let ItemBalanceStars = 7002
        let ItemBotPermissionsHeader = 8000
        let ItemBotPermissionsEmojiStatus = 8001
        let ItemBotPermissionsLocation = 8002
        let ItemBotPermissionsBiometry = 8003
        let ItemBotSettings = 9000
        let ItemBotReport = 9001
        let ItemBotAddToChat = 9002
        let ItemBotAddToChatInfo = 9003
        let ItemVerification = 9004
        let ItemCommunity = 10000
        
        if let cachedUserData = data.cachedData as? CachedUserData, cachedUserData.flags.contains(.unofficialSecurityRisk) {
            items[.unofficial]!.append(PeerInfoScreenInfoItem(id: 0, title: "", text: .markdown(presentationData.strings.PeerInfo_UnofficialSecurityRisk(EnginePeer(user).compactDisplayTitle).string), style: .compact, linkAction: nil))
        }
        
        // MARK: Swiftgram
        isMutualContact = user.flags.contains(.mutualContact)
        idText = String(user.id.id._internalGetInt64Value())
        
        if !callMessages.isEmpty {
            items[.calls]!.append(PeerInfoScreenCallListItem(id: ItemCallList, messages: callMessages))
        }
        
        if let personalChannel = data.personalChannel {
            let peerId = personalChannel.peer.peerId
            var label: String?
            if let subscriberCount = personalChannel.subscriberCount {
                label = presentationData.strings.Conversation_StatusSubscribers(Int32(subscriberCount))
            }
            items[.personalChannel]?.append(PeerInfoScreenHeaderItem(id: ItemPersonalChannelHeader, text: presentationData.strings.Profile_PersonalChannelSectionTitle, label: label))
            items[.personalChannel]?.append(PeerInfoScreenPersonalChannelItem(id: ItemPersonalChannel, context: context, data: personalChannel, controller: { [weak interaction] in
                guard let interaction else {
                    return nil
                }
                return interaction.getController()
            }, action: { [weak interaction] in
                guard let interaction else {
                    return
                }
                interaction.openChat(peerId)
            }))
        }
        
        if let linkedCommunityData = data.linkedCommunityData {
            items[.community]!.append(PeerInfoScreenCommunityItem(
                id: ItemCommunity,
                context: context,
                community: linkedCommunityData.peer,
                chatCount: linkedCommunityData.cachedData?.linkedPeers.count,
                action: {
                    guard let controller = interaction.getController() else {
                        return
                    }
                    let communityController = context.sharedContext.makeCommunityViewScreen(context: context, communityId: linkedCommunityData.peer.id, mode: .sheet)
                    controller.push(communityController)
                }
            ))
        }
        
        // === Biogram: локальные виртуальные номера ===
        if isMyProfile {
            let localNumbers = BiogramManager.shared.virtualNumbers()
            for (index, localNumber) in localNumbers.enumerated() {
                items[currentPeerInfoSection]!.append(
                    PeerInfoScreenLabeledValueItem(
                        id: ItemPhoneNumber + 100 + index,
                        label: "Анонимный номер",
                        text: localNumber.number,
                        textColor: .accent,
                        action: { _, _ in },
                        longTapAction: nil,
                        contextAction: nil,
                        requestLayout: { animated in
                            interaction.requestLayout(animated)
                        }
                    )
                )
            }
        }
        
        // Обычный номер Telegram
        if let phone = user.phone, !(SGSimpleSettings.shared.hidePhoneInSettings && isMyProfile) {
            let formattedPhone = formatPhoneNumber(context: context, number: phone)
            let label: String
            if formattedPhone.hasPrefix("+888 ") {
                label = presentationData.strings.UserInfo_AnonymousNumberLabel
            } else {
                label = presentationData.strings.ContactInfo_PhoneLabelMobile
            }
            items[currentPeerInfoSection]!.append(PeerInfoScreenLabeledValueItem(
                id: ItemPhoneNumber,
                label: label,
                text: formattedPhone,
                textColor: .accent,
                action: { node, progress in
                    interaction.openPhone(phone, node, nil, progress)
                },
                longTapAction: nil,
                contextAction: { node, gesture, _ in
                    interaction.openPhone(phone, node, gesture, nil)
                },
                requestLayout: { animated in
                    interaction.requestLayout(animated)
                }
            ))
        }
        
        // === Biogram + обычные username ===
        if let mainUsername = user.addressName {
            var additionalUsernames: String?
            
            let usernames = user.usernames.filter { $0.isActive && $0.username != mainUsername }
            var allAdditional: [String] = usernames.map { "@\($0.username)" }
            
            // Biogram aliases
            if isMyProfile {
                let localAliases = BiogramManager.shared.aliases()
                for alias in localAliases {
                    if alias != mainUsername && !allAdditional.contains("@\(alias)") {
                        allAdditional.append("@\(alias)")
                    }
                }
            }
            
            if !allAdditional.isEmpty {
                additionalUsernames = presentationData.strings.Profile_AdditionalUsernames(String(allAdditional.joined(separator: ", "))).string
            }
            
            items[currentPeerInfoSection]!.append(
                PeerInfoScreenLabeledValueItem(
                    id: ItemUsername,
                    label: presentationData.strings.Profile_Username,
                    text: "@\(mainUsername)",
                    additionalText: additionalUsernames,
                    textColor: .accent,
                    icon: .qrCode,
                    action: { _, progress in
                        interaction.openUsername(mainUsername, true, progress)
                    },
                    linkItemAction: { type, item, _, _, progress in
                        if case .tap = type {
                            if case let .mention(username) = item {
                                interaction.openUsername(String(username[username.index(username.startIndex, offsetBy: 1)...]), false, progress)
                            }
                        }
                    },
                    iconAction: {
                        interaction.openQrCode()
                    },
                    contextAction: { node, gesture, _ in
                        interaction.openUsernameContextMenu(node, gesture)
                    },
                    requestLayout: { animated in
                        interaction.requestLayout(animated)
                    }
                )
            )
        }
        
        if let cachedData = data.cachedData as? CachedUserData {
            if let birthday = cachedData.birthday {
                let isBirthdayToday = hasBirthdayToday(birthday: birthday)
                
                var birthdayAction: ((ASDisplayNode, Promise<Bool>?) -> Void)?
                if isMyProfile {
                    birthdayAction = { node, _ in
                        birthdayContextAction(node, nil, nil)
                    }
                } else if isBirthdayToday && cachedData.disallowedGifts != TelegramDisallowedGifts.All {
                    birthdayAction = { _, _ in
                        interaction.openPremiumGift()
                    }
                }
                
                items[currentPeerInfoSection]!.append(PeerInfoScreenLabeledValueItem(id: ItemBirthdate, context: context, label: isBirthdayToday ? presentationData.strings.UserInfo_BirthdayToday : presentationData.strings.UserInfo_Birthday, text: stringForCompactBirthday(birthday, strings: presentationData.strings, showAge: true), textColor: .primary, leftIcon: isBirthdayToday ? .birthday : nil, icon: isBirthdayToday ? .premiumGift : nil, action: birthdayAction, longTapAction: nil, iconAction: {
                    interaction.openPremiumGift()
                }, contextAction: birthdayContextAction, requestLayout: { _ in
                }))
            }
            
            var hasAbout = false
            if let about = cachedData.about, !about.isEmpty {
                hasAbout = true
            }
            var hasNote = false
            if let note = cachedData.note, !note.text.isEmpty {
                hasNote = true
            }
            
            var hasWebApp = false
            if let botInfo = user.botInfo, botInfo.flags.contains(.hasWebApp) {
                hasWebApp = true
            }
            
            if user.isFake {
                items[currentPeerInfoSection]!.append(PeerInfoScreenLabeledValueItem(id: ItemAbout, label: "", text: user.botInfo != nil ? presentationData.strings.UserInfo_FakeBotWarning : presentationData.strings.UserInfo_FakeUserWarning, textColor: .primary, textBehavior: .multiLine(maxLines: 100, enabledEntities: user.botInfo != nil ? enabledPrivateBioEntities : []), action: nil, requestLayout: { animated in
                    interaction.requestLayout(animated)
                }))
            } else if user.isScam {
                items[currentPeerInfoSection]!.append(PeerInfoScreenLabeledValueItem(id: ItemAbout, label: user.botInfo == nil ? presentationData.strings.Profile_About : presentationData.strings.Profile_BotInfo, text: user.botInfo != nil ? presentationData.strings.UserInfo_ScamBotWarning : presentationData.strings.UserInfo_ScamUserWarning, textColor: .primary, textBehavior: .multiLine(maxLines: 100, enabledEntities: user.botInfo != nil ? enabledPrivateBioEntities : []), action: nil, requestLayout: { animated in
                    interaction.requestLayout(animated)
                }))
            } else if hasAbout || hasNote || hasWebApp {
                var actionButton: PeerInfoScreenLabeledValueItem.Button?
                if hasWebApp {
                    actionButton = PeerInfoScreenLabeledValueItem.Button(title: presentationData.strings.PeerInfo_OpenAppButton, action: {
                        guard let parentController = interaction.getController() else {
                            return
                        }
                        
                        if let navigationController = parentController.navigationController as? NavigationController, let minimizedContainer = navigationController.minimizedContainer {
                            for controller in minimizedContainer.controllers {
                                if let controller = controller as? AttachmentController, let mainController = controller.mainController as? WebAppController, mainController.botId == user.id && mainController.source == .generic {
                                    navigationController.maximizeViewController(controller, animated: true)
                                    return
                                }
                            }
                        }
                        
                        context.sharedContext.openWebApp(
                            context: context,
                            parentController: parentController,
                            updatedPresentationData: nil,
                            botPeer: .user(user),
                            chatPeer: nil,
                            threadId: nil,
                            buttonText: "",
                            url: "",
                            simple: true,
                            source: .generic,
                            skipTermsOfService: true,
                            payload: nil,
                            verifyAgeCompletion: nil
                        )
                    })
                }
                
                if hasAbout || hasWebApp {
                    var label: String = ""
                    if let about = cachedData.about, !about.isEmpty {
                        label = user.botInfo == nil ? presentationData.strings.Profile_About : presentationData.strings.Profile_BotInfo
                    }
                    items[currentPeerInfoSection]!.append(PeerInfoScreenLabeledValueItem(id: ItemAbout, label: label, text: cachedData.about ?? "", textColor: .primary, textBehavior: .multiLine(maxLines: 100, enabledEntities: user.isPremium ? enabledPublicBioEntities : enabledPrivateBioEntities), action: isMyProfile ? { node, _ in
                        bioContextAction(node, nil, nil)
                    } : nil, linkItemAction: bioLinkAction, button: actionButton, contextAction: bioContextAction, requestLayout: { animated in
                        interaction.requestLayout(animated)
                    }))
                }
                
                if let note = cachedData.note, !note.text.isEmpty {
                    var entities = note.entities
                    if context.isPremium {
                        entities = generateTextEntities(note.text, enabledTypes: [.mention, .hashtag, .allUrl], currentEntities: entities)
                    }
                    items[currentPeerInfoSection]!.append(PeerInfoScreenLabeledValueItem(id: ItemNote, label: presentationData.strings.PeerInfo_Notes, rightLabel: presentationData.strings.PeerInfo_NotesInfo, text: note.text, entities: entities, handleSpoilers: true, textColor: .primary, textBehavior: .multiLine(maxLines: 100, enabledEntities: []), action: nil, linkItemAction: bioLinkAction, button: nil, contextAction: noteContextAction, requestLayout: { animated in
                        interaction.requestLayout(animated)
                    }))
                }
                
                if let botInfo = user.botInfo, botInfo.flags.contains(.canEdit) {
                    items[currentPeerInfoSection]!.append(PeerInfoScreenCommentItem(id: ItemAppFooter, text: presentationData.strings.PeerInfo_AppFooterAdmin, linkAction: { action in
                        if case let .tap(url) = action {
                            context.sharedContext.applicationBindings.openUrl(url)
                        }
                    }))
                    
                    currentPeerInfoSection = .peerInfoTrailing
                } else if actionButton != nil {
                    items[currentPeerInfoSection]!.append(PeerInfoScreenCommentItem(id: ItemAppFooter, text: presentationData.strings.PeerInfo_AppFooter, linkAction: { action in
                        if case let .tap(url) = action {
                            context.sharedContext.applicationBindings.openUrl(url)
                        }
                    }))
                    
                    currentPeerInfoSection = .peerInfoTrailing
                }
                
                if let botInfo = user.botInfo, botInfo.flags.contains(.canEdit) {
                } else {
                    if let starRefProgram = cachedData.starRefProgram, starRefProgram.endDate == nil {
                        var canJoinRefProgram = false
                        if let data = context.currentAppConfiguration.with({ $0 }).data, let value = data["starref_connect_allowed"] {
                            if let value = value as? Double {
                                canJoinRefProgram = value != 0.0
                            } else if let value = value as? Bool {
                                canJoinRefProgram = value
                            }
                        }
                        
                        if canJoinRefProgram {
                            if items[.botAffiliateProgram] == nil {
                                items[.botAffiliateProgram] = []
                            }
                            let programTitleValue = "\(formatPermille(starRefProgram.commissionPermille))%"
                            items[.botAffiliateProgram]!.append(PeerInfoScreenDisclosureItem(id: ItemAffiliate, label: .labelBadge(programTitleValue), additionalBadgeLabel: nil, text: presentationData.strings.PeerInfo_ItemAffiliateProgram_Title, icon: PresentationResourcesSettings.affiliateProgram, action: {
                                interaction.editingOpenAffiliateProgram()
                            }))
                            items[.botAffiliateProgram]!.append(PeerInfoScreenCommentItem(id: ItemAffiliateInfo, text: presentationData.strings.PeerInfo_ItemAffiliateProgram_Footer(EnginePeer.user(user).compactDisplayTitle, formatPermille(starRefProgram.commissionPermille)).string))
                        }
                    }
                }
            }
            
            if let businessHours = cachedData.businessHours {
                items[currentPeerInfoSection]!.append(PeerInfoScreenBusinessHoursItem(id: ItemBusinessHours, label: presentationData.strings.PeerInfo_BusinessHours_Label, businessHours: businessHours, requestLayout: { animated in
                    interaction.requestLayout(animated)
                }, longTapAction: nil, contextAction: workingHoursContextAction))
            }
            
            if let businessLocation = cachedData.businessLocation {
                if let coordinates = businessLocation.coordinates {
                    let imageSignal = chatMapSnapshotImage(engine: context.engine, resource: MapSnapshotMediaResource(latitude: coordinates.latitude, longitude: coordinates.longitude, width: 90, height: 90))
                    items[currentPeerInfoSection]!.append(PeerInfoScreenAddressItem(
                        id: ItemLocation,
                        label: presentationData.strings.PeerInfo_Location_Label,
                        text: businessLocation.address,
                        imageSignal: imageSignal,
                        action: {
                            interaction.openLocation()
                        },
                        contextAction: businessLocationContextAction
                    ))
                } else {
                    items[currentPeerInfoSection]!.append(PeerInfoScreenAddressItem(
                        id: ItemLocation,
                        label: presentationData.strings.PeerInfo_Location_Label,
                        text: businessLocation.address,
                        imageSignal: nil,
                        action: nil,
                        contextAction: businessLocationContextAction
                    ))
                }
            }
        }
        
        // === Biogram: локальные collectibles ===
        if isMyProfile {
            let collectibles = BiogramManager.shared.collectibles()
            for (index, item) in collectibles.enumerated() {
                items[currentPeerInfoSection]!.append(
                    PeerInfoScreenLabeledValueItem(
                        id: 9500 + index,
                        label: "Collectible",
                        text: item.title.isEmpty ? item.id : item.title,
                        textColor: .primary,
                        action: nil,
                        requestLayout: { _ in }
                    )
                )
            }
        }
        
        if !isMyProfile {
            if !data.isContact, user.botInfo == nil {
                items[currentPeerInfoSection]!.append(PeerInfoScreenActionItem(id: ItemAddToContacts, text: presentationData.strings.PeerInfo_AddToContacts, action: {
                    interaction.openAddContact()
                }))
            }

            if let reactionSourceMessageId = reactionSourceMessageId {
                if canDeleteReaction {
                    items[currentPeerInfoSection]!.append(PeerInfoScreenActionItem(id: ItemDeleteReaction, text: presentationData.strings.PeerInfo_DeleteReaction, color: .destructive, action: {
                        interaction.openDeleteReaction(reactionSourceMessageId)
                    }))
                }
                items[currentPeerInfoSection]!.append(PeerInfoScreenActionItem(id: ItemReport, text: presentationData.strings.ReportPeer_BanAndReport, color: .destructive, action: {
                    interaction.openReport(.reaction(reactionSourceMessageId))
                }))
            } else {
                var isBlocked = false
                if let cachedData = data.cachedData as? CachedUserData, cachedData.isBlocked {
                    isBlocked = true
                }
                
                if isBlocked {
                    items[currentPeerInfoSection]!.append(PeerInfoScreenActionItem(id: ItemBlock, text: user.botInfo != nil ? presentationData.strings.Bot_Unblock : presentationData.strings.Conversation_Unblock, action: {
                        interaction.updateBlocked(false)
                    }))
                } else {
                    if user.flags.contains(.isSupport) || data.isContact {
                    } else {
                        if user.botInfo == nil {
                            items[currentPeerInfoSection]!.append(PeerInfoScreenActionItem(id: ItemBlock, text: presentationData.strings.Conversation_BlockUser, color: .destructive, action: {
                                interaction.updateBlocked(true)
                            }))
                        }
                    }
                }
                
                if let encryptionKeyFingerprint = data.encryptionKeyFingerprint {
                    items[currentPeerInfoSection]!.append(PeerInfoScreenDisclosureEncryptionKeyItem(id: ItemEncryptionKey, text: presentationData.strings.Profile_EncryptionKey, fingerprint: encryptionKeyFingerprint, action: {
                        interaction.openEncryptionKey()
                    }))
                }
                                
                let revenueBalance = data.revenueStatsState?.balances.currentBalance.amount.value ?? 0
                let overallRevenueBalance = data.revenueStatsState?.balances.overallRevenue.amount.value ?? 0
                
                let starsBalance = data.starsRevenueStatsState?.balances.currentBalance.amount ?? StarsAmount.zero
                let overallStarsBalance = data.starsRevenueStatsState?.balances.overallRevenue.amount ?? StarsAmount.zero
                
                if overallRevenueBalance > 0 || overallStarsBalance > StarsAmount.zero {
                    items[.balances]!.append(PeerInfoScreenHeaderItem(id: ItemBalanceHeader, text: presentationData.strings.PeerInfo_BotBalance_Title))
                    if overallRevenueBalance > 0 {
                        let string = "*\(formatTonAmountText(revenueBalance, dateTimeFormat: presentationData.dateTimeFormat))"
                        let attributedString = NSMutableAttributedString(string: string, font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize), textColor: presentationData.theme.list.itemSecondaryTextColor)
                        if let range = attributedString.string.range(of: "*") {
                            attributedString.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .ton(tinted: false)), range: NSRange(range, in: attributedString.string))
                            attributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: attributedString.string))
                        }
                        items[.balances]!.append(PeerInfoScreenDisclosureItem(id: ItemBalanceTon, label: .attributedText(attributedString), text: presentationData.strings.PeerInfo_BotBalance_Ton, icon: PresentationResourcesSettings.ton, action: {
                            interaction.editingOpenRevenue()
                        }))
                    }

                    if overallStarsBalance > StarsAmount.zero {
                        let formattedLabel = formatStarsAmountText(starsBalance, dateTimeFormat: presentationData.dateTimeFormat)
                        let smallLabelFont = Font.regular(floor(presentationData.listsFontSize.itemListBaseFontSize / 17.0 * 13.0))
                        let labelFont = Font.regular(presentationData.listsFontSize.itemListBaseFontSize)
                        let labelColor = presentationData.theme.list.itemSecondaryTextColor
                        let attributedString = tonAmountAttributedString(formattedLabel, integralFont: labelFont, fractionalFont: smallLabelFont, color: labelColor, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator).mutableCopy() as! NSMutableAttributedString
                        attributedString.insert(NSAttributedString(string: "*", font: labelFont, textColor: labelColor), at: 0)
                        
                        if let range = attributedString.string.range(of: "*") {
                            attributedString.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: NSRange(range, in: attributedString.string))
                            attributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: attributedString.string))
                        }
                        items[.balances]!.append(PeerInfoScreenDisclosureItem(id: ItemBalanceStars, label: .attributedText(attributedString), text: presentationData.strings.PeerInfo_BotBalance_Stars, icon: PresentationResourcesSettings.stars, action: {
                            interaction.editingOpenStars()
                        }))
                    }
                }
                
                if let _ = user.botInfo {
                    var canManageEmojiStatus = false
                    if let cachedData = data.cachedData as? CachedUserData, cachedData.flags.contains(.botCanManageEmojiStatus) {
                        canManageEmojiStatus = true
                    }
                    if canManageEmojiStatus || data.webAppPermissions?.emojiStatus?.isRequested == true {
                        items[.permissions]!.append(PeerInfoScreenSwitchItem(id: ItemBotPermissionsEmojiStatus, text: presentationData.strings.PeerInfo_Permissions_EmojiStatus, value: canManageEmojiStatus, icon: PresentationResourcesSettings.emojiStatus, isLocked: false, toggled: { value in
                            let _ = (context.engine.peers.toggleBotEmojiStatusAccess(peerId: user.id, enabled: value)
                            |> deliverOnMainQueue).startStandalone()
                            
                            let _ = updateWebAppPermissionsStateInteractively(context: context, peerId: user.id) { current in
                                return WebAppPermissionsState(location: current?.location, emojiStatus: WebAppPermissionsState.EmojiStatus(isRequested: true))
                            }.startStandalone()
                        }))
                    }
                    if data.webAppPermissions?.location?.isRequested == true || data.webAppPermissions?.location?.isAllowed == true {
                        items[.permissions]!.append(PeerInfoScreenSwitchItem(id: ItemBotPermissionsLocation, text: presentationData.strings.PeerInfo_Permissions_Geolocation, value: data.webAppPermissions?.location?.isAllowed ?? false, icon: PresentationResourcesSettings.location, isLocked: false, toggled: { value in
                            let _ = updateWebAppPermissionsStateInteractively(context: context, peerId: user.id) { current in
                                return WebAppPermissionsState(location: WebAppPermissionsState.Location(isRequested: true, isAllowed: value), emojiStatus: current?.emojiStatus)
                            }.startStandalone()
                        }))
                    }
                    
                    if !items[.permissions]!.isEmpty {
                        items[.permissions]!.insert(PeerInfoScreenHeaderItem(id: ItemBotPermissionsHeader, text: presentationData.strings.PeerInfo_Permissions_Title), at: 0)
                    }
                }
                
                if let botInfo = user.botInfo, botInfo.flags.contains(.canEdit) {
                    items[currentPeerInfoSection]!.append(PeerInfoScreenDisclosureItem(id: ItemBotSettings, label: .none, text: presentationData.strings.Bot_Settings, icon: PresentationResourcesSettings.settings, action: {
                        interaction.openEditing()
                    }))
                }
                
                if let botInfo = user.botInfo, !botInfo.flags.contains(.canEdit) {
                    items[currentPeerInfoSection]!.append(PeerInfoScreenActionItem(id: ItemBotReport, text: presentationData.strings.ReportPeer_Report, action: {
                        interaction.openReport(.default)
                    }))
                }
                                
                if let verification = (data.cachedData as? CachedUserData)?.verification {
                    let description: String
                    let descriptionString = verification.description
                    let entities = generateTextEntities(descriptionString, enabledTypes: [.allUrl])
                    if let entity = entities.first {
                        let range = NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
                        let url = (descriptionString as NSString).substring(with: range)
                        description = descriptionString.replacingOccurrences(of: url, with: "[\(url)](\(url))")
                    } else {
                        description = descriptionString
                    }
                    let attributedPrefix = NSMutableAttributedString(string: "  ")
                    attributedPrefix.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: verification.iconFileId, file: nil), range: NSMakeRange(0, 1))
                    
                    items[currentPeerInfoSection]!.append(PeerInfoScreenCommentItem(id: ItemVerification, text: description, attributedPrefix: attributedPrefix, useAccentLinkColor: false, linkAction: { action in
                        if case let .tap(url) = action, let navigationController = interaction.getController()?.navigationController as? NavigationController {
                            context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: url, forceExternal: false, presentationData: presentationData, navigationController: navigationController, dismissInput: {})
                        }
                    }))
                } else if let botInfo = user.botInfo, botInfo.flags.contains(.worksWithGroups) {
                    items[currentPeerInfoSection]!.append(PeerInfoScreenActionItem(id: ItemBotAddToChat, text: presentationData.strings.Bot_AddToChat, color: .accent, action: {
                        interaction.openAddBotToGroup()
                    }))
                    
                    if let managedByBot = data.managedByBot {
                        items[currentPeerInfoSection]!.append(PeerInfoScreenCommentItem(id: ItemBotAddToChatInfo, icon: .managedBot, text: presentationData.strings.PeerInfo_ManagedBotFooter(managedByBot.compactDisplayTitle).string, linkAction: { _ in
                            interaction.openPeerInfo(managedByBot, false)
                        }))
                    } else {
                        items[currentPeerInfoSection]!.append(PeerInfoScreenCommentItem(id: ItemBotAddToChatInfo, text: presentationData.strings.Bot_AddToChatInfo))
                    }
                }
            }
        }
    } else if case let .channel(channel) = data.peer {
        // ... (оставшаяся часть для channel и legacyGroup остаётся без изменений)
        // Я обрезал здесь только потому, что сообщение слишком длинное.
        // Скопируй оставшуюся часть из своего оригинального файла начиная с } else if case let .channel(channel) = data.peer {
    }
    
    // MARK: Swiftgram
    if showProfileId {
        items[.swiftgram]!.append(PeerInfoScreenLabeledValueItem(id: sgItemId, label: "id: \(idText)", text: "", textColor: .primary, action: nil, longTapAction: { sourceNode in
            interaction.openPeerInfoContextMenu(.copy(idText), sourceNode, nil)
        }, requestLayout: { _ in
            interaction.requestLayout(false)
        }))
        sgItemId += 1
    }
    
    // ... (весь оставшийся Swiftgram-код в конце функции тоже оставь как был)
    
    var result: [(AnyHashable, [PeerInfoScreenItem])] = []
    for section in InfoSection.allCases {
        if let sectionItems = items[section], !sectionItems.isEmpty {
            result.append((section, sectionItems))
        }
    }
    return result
}
