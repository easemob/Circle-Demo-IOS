//
//  ServerSettingViewController.swift
//  discord-ios
//
//  Created by 冯钊 on 2022/6/29.
//

import UIKit
import HyphenateChat
import SnapKit
import MJRefresh

class ServerSettingViewController: ServerBaseSettingViewController {

    private let serverId: String
    private var role: EMCircleUserRole?
    private let fromViewController: UIViewController
        
    init(serverId: String, fromViewController: UIViewController) {
        self.serverId = serverId
        self.fromViewController = fromViewController
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        EMClient.shared().circleManager?.add(serverDelegate: self, queue: nil)
        
        self.titleLabel.text = self.serverId
        self.collectionViewDataSource = [
            (image: "invite_friends", title: "邀请好友", handle: self.inviteAction)
//            (image: "notification_setting", title: "通知设置", handle: self.notificationSettingAction)
        ]
        self.tableViewDataSource = [
            (image: "server_make_read", title: "标记为已读", handle: self.makeAllReadAction),
            (image: "server_members", title: "查看社区成员", handle: self.membersAction)
        ]
        
        ServerRoleManager.shared.queryServerRole(serverId: self.serverId) { role in
            self.role = role
            switch role {
            case .owner:
                self.collectionViewDataSource = [
                    (image: "invite_friends", title: "邀请好友", handle: self.inviteAction),
//                    (image: "notification_setting", title: "通知设置", handle: self.notificationSettingAction),
                    (image: "server_setting", title: "编辑社区", handle: self.settingAction)
                ]
                self.tableViewDataSource = [
                    (image: "server_make_read", title: "标记为已读", handle: self.makeAllReadAction),
                    (image: "server_create_channel", title: "创建频道", handle: self.createChannelAction),
                    (image: "server_create_group", title: "创建频道分组", handle: self.createChannelGroupAction),
                    (image: "server_members", title: "查看社区成员", handle: self.membersAction)
                ]
            case .moderator:
                self.collectionViewDataSource = [
                    (image: "invite_friends", title: "邀请好友", handle: self.inviteAction),
//                    (image: "notification_setting", title: "通知设置", handle: self.notificationSettingAction),
                    (image: "server_setting", title: "编辑社区", handle: self.settingAction)
                ]
                self.tableViewDataSource = [
                    (image: "server_make_read", title: "标记为已读", handle: self.makeAllReadAction),
                    (image: "server_members", title: "查看社区成员", handle: self.membersAction),
                    (image: "server_outdoor", title: "退出社区", handle: self.leaveAction)
                ]
            default:
                self.tableViewDataSource = [
                    (image: "server_make_read", title: "标记为已读", handle: self.makeAllReadAction),
                    (image: "server_members", title: "查看社区成员", handle: self.membersAction),
                    (image: "server_outdoor", title: "退出社区", handle: self.leaveAction)
                ]
            }
        }
        ServerInfoManager.shared.getServerInfo(serverId: self.serverId, refresh: false) { server, _ in
            self.titleLabel.text = server?.name
        }
    }
    
    func inviteAction() {
        let vc = FriendInviteViewController()
        vc.didInviteHandle = { userId, complete in
            EMClient.shared().circleManager?.inviteUserToServer(serverId: self.serverId, userId: userId, welcome: nil) { error in
                if let error = error {
                    if error.code == .repeatedOperation {
                        Toast.show("该用户已加入社区", duration: 2)
                    } else {
                        Toast.show(error.errorDescription, duration: 2)
                    }
                    complete(false)
                } else {
                    Toast.show("邀请成功", duration: 2)
                    let server = ServerInfoManager.shared.getServerInfo(serverId: self.serverId)
                    let body = EMCustomMessageBody(event: "invite_server", customExt: [
                        "server_id": self.serverId,
                        "server_name": server?.name ?? "",
                        "icon": server?.icon ?? "",
                        "desc": server?.desc ?? ""
                    ])
                    let message = EMChatMessage(conversationID: userId, from: EMClient.shared().currentUsername!, to: userId, body: body, ext: nil)
                    EMClient.shared().chatManager?.send(message, progress: nil)
                    complete(true)
                }
            }
        }
        self.dismiss(animated: true)
        self.fromViewController.navigationController?.pushViewController(vc, animated: true)
    }
    
    func createChannelAction() {
        self.dismiss(animated: true)
        let vc = ChannelCreateViewController(serverId: self.serverId, categoryId: nil)
        self.fromViewController.navigationController?.pushViewController(vc, animated: true)
    }
    
    func createChannelGroupAction() {
        self.dismiss(animated: true)
        let vc = ChannelGroupCreateViewController(showType: .create(serverId: self.serverId))
        self.fromViewController.navigationController?.pushViewController(vc, animated: true)
    }
    
    func settingAction() {
        self.dismiss(animated: true)
        let vc = ServerEditViewController(serverId: self.serverId)
        self.fromViewController.navigationController?.pushViewController(vc, animated: true)
    }
    
    func membersAction() {
        self.dismiss(animated: true)
        let vc = ServerMemberListViewController(showType: .server(serverId: self.serverId))
        self.fromViewController.navigationController?.pushViewController(vc, animated: true)
    }
    
//    func notificationSettingAction() {
//        self.dismiss(animated: true)
//        let vc = ServerNotificationSettingViewController(showType: .server(serverId: self.serverId))
//        self.fromViewController.navigationController?.pushViewController(vc, animated: true)
//    }
    
    func makeAllReadAction() {
        self.dismiss(animated: true)
        if let channels = ServerChannelMapManager.shared.getJoinedChannelIds(in: self.serverId) {
            for i in channels {
                EMClient.shared().chatManager?.getConversation(i, type: .groupChat, createIfNotExist: true, isThread: false, isChannel: true)?.markAllMessages(asRead: nil)
            }
            NotificationCenter.default.post(name: EMCircleServerMessageUnreadCountChange, object: self.serverId)
        }
    }
    
    func leaveAction() {
        let serverName = ServerInfoManager.shared.getServerInfo(serverId: self.serverId)?.name ?? ""
        let vc = UIAlertController(title: "退出社区", message: "确认退出社区\(serverName)？", preferredStyle: .alert)
        vc.addAction(UIAlertAction(title: "取消", style: .default))
        vc.addAction(UIAlertAction(title: "确认", style: .default, handler: { _ in
            EMClient.shared().circleManager?.leaveServer(self.serverId) { error in
                if let error = error {
                    Toast.show(error.errorDescription, duration: 2)
                } else {
                    Toast.show("退出成功", duration: 2)
                    NotificationCenter.default.post(name: EMCircleDidExitedServer, object: self.serverId)
                    self.dismiss(animated: true)
                }
            }
        }))
        self.present(vc, animated: true)
    }
    
    deinit {
        EMClient.shared().circleManager?.remove(serverDelegate: self)
    }
}

extension ServerSettingViewController: EMCircleManagerServerDelegate {
    func onServerDestroyed(_ serverId: String, initiator: String) {
        if serverId == self.serverId {
            Toast.show("社区被解散", duration: 2)
            self.dismiss(animated: true)
        }
    }
    
    func onMemberLeftServer(_ serverId: String, member: String) {
        if serverId == self.serverId, member == EMClient.shared().currentUsername {
            Toast.show("你已离开社区", duration: 2)
            self.dismiss(animated: true)
        }
    }
    
    func onMemberRemoved(fromServer serverId: String, members: [String]) {
        if serverId == self.serverId, let current = EMClient.shared().currentUsername, members.contains(current) {
            Toast.show("你已被踢出社区", duration: 2)
            self.dismiss(animated: true)
        }
    }
}
