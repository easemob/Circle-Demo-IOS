//
//  ChannelSettingViewController.swift
//  discord-ios
//
//  Created by 冯钊 on 2022/7/5.
//

import UIKit
import HyphenateChat
import MJRefresh
import SnapKit

class ChannelSettingViewController: ServerBaseSettingViewController {
    
    private let serverId: String
    private let channelId: String
    private let userOnlineStateCache = UserOnlineStateCache()
    private var muteStateMap: [String: NSNumber]?
    
    private var result: EMCursorResult<EMCircleUser>?
    private var role: EMCircleUserRole?
    private let fromViewController: UIViewController
    
    init(serverId: String, channelId: String, fromViewController: UIViewController) {
        self.serverId = serverId
        self.channelId = channelId
        self.fromViewController = fromViewController
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        EMClient.shared().circleManager?.add(channelDelegate: self, queue: nil)
        EMClient.shared().addMultiDevices(delegate: self, queue: nil)
        
        self.titleLabel.text = self.channelId
        
        self.collectionViewDataSource = [
            (image: "invite_friends", title: "邀请好友", handle: self.inviteAction)
        ]
        self.tableViewDataSource = [
            (image: "server_members", title: "查看频道成员", handle: self.membersAction)
        ]
        
        EMClient.shared().circleManager?.fetchChannelDetail(self.serverId, channelId: self.channelId, completion: { channel, error in
            if let error = error {
                Toast.show(error.errorDescription, duration: 2)
            } else if let name = channel?.name, name.count > 0 {
                self.titleLabel.text = name
            }
            ServerRoleManager.shared.queryServerRole(serverId: self.serverId) { role in
                self.role = role
                switch role {
                case .owner:
                    if channel?.mode == .voice {
                        self.collectionViewDataSource = [
                            (image: "invite_friends", title: "邀请好友", handle: self.inviteAction),
                            (image: "server_setting", title: "编辑频道", handle: self.editAction)
                        ]
                        self.tableViewDataSource = [
                            (image: "server_change_group", title: "移动频道至", handle: self.moveGroupAcrion),
                            (image: "server_members", title: "查看频道成员", handle: self.membersAction)
                        ]
                    } else {
                        self.collectionViewDataSource = [
                            (image: "invite_friends", title: "邀请好友", handle: self.inviteAction),
                            (image: "#_channel_setting", title: "子区", handle: self.threadAction),
//                            (image: "notification_setting", title: "通知设置", handle: self.notificationSettingAction),
                            (image: "server_setting", title: "编辑频道", handle: self.editAction)
                        ]
                        self.tableViewDataSource = [
                            (image: "server_make_read", title: "标记为已读", handle: self.makeAllReadAction),
                            (image: "server_change_group", title: "移动频道至", handle: self.moveGroupAcrion),
                            (image: "server_members", title: "查看频道成员", handle: self.membersAction)
                        ]
                    }
                case .moderator:
                    if channel?.mode == .voice {
                        self.collectionViewDataSource = [
                            (image: "invite_friends", title: "邀请好友", handle: self.inviteAction),
                            (image: "server_setting", title: "编辑频道", handle: self.editAction)
                        ]
                        self.tableViewDataSource = [
                            (image: "server_change_group", title: "移动频道至", handle: self.moveGroupAcrion),
                            (image: "server_members", title: "查看频道成员", handle: self.membersAction)
                        ]
                    } else {
                        self.collectionViewDataSource = [
                            (image: "invite_friends", title: "邀请好友", handle: self.inviteAction),
                            (image: "#_channel_setting", title: "子区", handle: self.threadAction),
//                            (image: "notification_setting", title: "通知设置", handle: self.notificationSettingAction),
                            (image: "server_setting", title: "编辑频道", handle: self.editAction)
                        ]
                        self.tableViewDataSource = [
                            (image: "server_make_read", title: "标记为已读", handle: self.makeAllReadAction),
                            (image: "server_change_group", title: "移动频道至", handle: self.moveGroupAcrion),
                            (image: "server_members", title: "查看频道成员", handle: self.membersAction)
                        ]
                    }
                default:
                    if channel?.mode == .voice {
                        self.collectionViewDataSource = [
                            (image: "invite_friends", title: "邀请好友", handle: self.inviteAction)
                        ]
                        self.tableViewDataSource = [
                            (image: "server_members", title: "查看频道成员", handle: self.membersAction)
                        ]
                    } else {
                        self.collectionViewDataSource = [
                            (image: "invite_friends", title: "邀请好友", handle: self.inviteAction),
                            (image: "#_channel_setting", title: "子区", handle: self.threadAction)
//                            (image: "notification_setting", title: "通知设置", handle: self.notificationSettingAction)
                        ]
                        self.tableViewDataSource = [
                            (image: "server_make_read", title: "标记为已读", handle: self.makeAllReadAction),
                            (image: "server_members", title: "查看频道成员", handle: self.membersAction)
                        ]
                    }
                }
            }
        })
    }
    
    @IBAction func inviteAction() {
        self.dismiss(animated: true)
        let vc = FriendInviteViewController()
        vc.didInviteHandle = { userId, complete in
            EMClient.shared().circleManager?.inviteUserToChannel(serverId: self.serverId, channelId: self.channelId, userId: userId, welcome: nil) { error in
                if let error = error {
                    if error.code == .repeatedOperation {
                        Toast.show("该用户已加入频道", duration: 2)
                    } else {
                        Toast.show(error.errorDescription, duration: 2)
                    }
                    complete(false)
                } else {
                    Toast.show("邀请成功", duration: 2)
                    EMClient.shared().circleManager?.fetchChannelDetail(self.serverId, channelId: self.channelId) { channel, _ in
                        let server = ServerInfoManager.shared.getServerInfo(serverId: self.serverId)
                        let body = EMCustomMessageBody(event: "invite_channel", customExt: [
                            "server_id": self.serverId,
                            "server_name": server?.name ?? "",
                            "icon": server?.icon ?? "",
                            "channel_id": self.channelId,
                            "desc": channel?.desc ?? "",
                            "channel_name": channel?.name ?? ""
                        ])
                        let message = EMChatMessage(conversationID: userId, from: EMClient.shared().currentUsername!, to: userId, body: body, ext: nil)
                        EMClient.shared().chatManager?.send(message, progress: nil)
                    }
                    complete(true)
                }
            }
        }
        self.fromViewController.navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func threadAction() {
        self.dismiss(animated: true)
        let vc = ThreadListViewController(chatType: .channel(serverId: self.serverId, channelId: self.channelId))
        self.fromViewController.navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func editAction() {
        self.dismiss(animated: true)
        let vc = ChannelEditViewController(serverId: self.serverId, channelId: self.channelId)
        self.fromViewController.navigationController?.pushViewController(vc, animated: true)
    }
    
    func notificationSettingAction() {
        self.dismiss(animated: true)
        let vc = ServerNotificationSettingViewController(showType: .channel(serverId: self.serverId, channelId: self.channelId))
        self.fromViewController.navigationController?.pushViewController(vc, animated: true)
    }
    
    func makeAllReadAction() {
        self.dismiss(animated: true)
        EMClient.shared().chatManager?.getConversation(self.channelId, type: .groupChat, createIfNotExist: true, isThread: false, isChannel: true)?.markAllMessages(asRead: nil)
        NotificationCenter.default.post(name: EMCircleServerMessageUnreadCountChange, object: self.serverId)
    }
    
    func membersAction() {
        self.dismiss(animated: true)
        let vc = ServerMemberListViewController(showType: .channel(serverId: self.serverId, channelId: self.channelId))
        self.fromViewController.navigationController?.pushViewController(vc, animated: true)
    }
    
    func moveGroupAcrion() {
        self.dismiss(animated: true)
        let vc = ChannelChangeGroupViewController(serverId: self.serverId, channelId: self.channelId)
        self.fromViewController.navigationController?.pushViewController(vc, animated: true)
    }
    
    func leaveAction() {
        let vc = UIAlertController(title: "退出频道", message: "确认退出频道？", preferredStyle: .alert)
        vc.addAction(UIAlertAction(title: "取消", style: .default))
        vc.addAction(UIAlertAction(title: "确认", style: .destructive, handler: { _ in
            EMClient.shared().circleManager?.leaveChannel(self.serverId, channelId: self.channelId) { error in
                if let error = error {
                    Toast.show(error.errorDescription, duration: 2)
                } else {
                    Toast.show("退出频道成功", duration: 2)
                    NotificationCenter.default.post(name: EMCircleDidExitedChannel, object: (self.serverId, self.channelId))
                    self.fromViewController.navigationController?.popToRootViewController(animated: true)
                }
            }
        }))
        self.present(vc, animated: true)
    }
    
    deinit {
        EMClient.shared().circleManager?.remove(channelDelegate: self)
        EMClient.shared().remove(self)
    }
}

extension ChannelSettingViewController: EMCircleManagerChannelDelegate {
    func onMemberRemoved(fromChannel serverId: String, categoryId: String, channelId: String, member: String, initiator: String) {
        if channelId == self.channelId, member == EMClient.shared().currentUsername {
            Toast.show("你已经从频道中踢出", duration: 2)
            self.dismiss(animated: true)
        }
    }
    
    func onChannelDestroyed(_ serverId: String, categoryId: String, channelId: String, initiator: String) {
        if channelId == self.channelId {
            Toast.show("频道已经被解散", duration: 2)
            self.dismiss(animated: true)
        }
    }
}

extension ChannelSettingViewController: EMMultiDevicesDelegate {
    func multiDevicesCircleChannelEventDidReceive(_ aEvent: EMMultiDevicesEvent, channelId: String, ext aExt: Any?) {
        guard serverId == self.serverId else {
            return
        }
        switch aEvent {
        case .circleChannelDestroy:
            Toast.show("频道被销毁", duration: 2)
            self.dismiss(animated: true)
        default:
            break
        }
    }
}
