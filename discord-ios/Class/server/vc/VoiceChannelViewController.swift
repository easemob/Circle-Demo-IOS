//
//  VoiceChannelViewController.swift
//  discord-ios
//
//  Created by 冯钊 on 2022/12/22.
//

import UIKit
import HyphenateChat

class VoiceChannelViewController: UIViewController {
    
    enum ShowType {
        case detail(server: EMCircleServer, channel: EMCircleChannel)
        case id(serverId: String, channelId: String, closeHandle: () -> Void)
    }
    
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var channelNameLabel: UILabel!
    @IBOutlet private weak var serverNameLabel: UILabel!
    @IBOutlet private weak var settingButton: UIButton!
    @IBOutlet private weak var inviteButton: UIButton!
    @IBOutlet private weak var inviteButtonRightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var muteButton: UIButton!
    @IBOutlet private weak var leaveButton: UIButton!
    @IBOutlet private weak var joinButton: UIButton!
    @IBOutlet private weak var noDataView: UIView!
    private let shapeLayer = CAShapeLayer()
    
    private let showType: ShowType
    private let fromViewController: UIViewController
    
    private var result: EMCursorResult<EMCircleUser>?
    private var server: EMCircleServer?
    private var channel: EMCircleChannel?
    
    init(showType: ShowType, fromViewController: UIViewController) {
        self.showType = showType
        self.fromViewController = fromViewController
        super.init(nibName: nil, bundle: nil)
        self.modalTransitionStyle = .crossDissolve
        self.modalPresentationStyle = .overFullScreen
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.contentView.layer.mask = self.shapeLayer
        
        switch self.showType {
        case .detail(server: let server, channel: let channel):
            self.channelNameLabel.text = channel.name
            self.serverNameLabel.text = server.name
            self.server = server
            self.channel = channel
        case .id(serverId: let serverId, channelId: let channelId, closeHandle: _):
            ServerInfoManager.shared.getServerInfo(serverId: serverId, refresh: false) { server, _ in
                self.serverNameLabel.text = server?.name ?? ""
                self.server = server
            }
            EMClient.shared().circleManager?.fetchChannelDetail(serverId, channelId: channelId, completion: { channel, _ in
                self.channelNameLabel.text = channel?.name ?? ""
                self.channel = channel
            })
        }
        
        self.tableView.register(UINib(nibName: "VoiceChannelMemberTableViewCell", bundle: nil), forCellReuseIdentifier: "cell")
        
        let isJoined = VoiceChatManager.shared.currentChannel?.channelId == self.showType.channelId
        self.joinButton.isHidden = isJoined
        self.muteButton.isHidden = !isJoined
        self.leaveButton.isHidden = !isJoined
        self.muteButton.isSelected = VoiceChatManager.shared.isMuted()
        self.inviteButton.isHidden = !isJoined

        EMClient.shared().circleManager?.fetchChannelMembers(self.showType.serverId, channelId: self.showType.channelId, limit: 20, cursor: nil, completion: { result, error in
            if let error = error {
                Toast.show(error.errorDescription, duration: 2)
            } else if let result = result {
                self.result = result
                if let list = result.list {
                    var requestList: [String] = []
                    for i in list {
                        requestList.append(i.userId)
                    }
                    UserInfoManager.share.queryUserInfo(userIds: requestList) {
                        self.tableView.reloadData()
                    }
                }
                self.tableView.reloadData()
                self.tableView.isHidden = result.count <= 0
                self.noDataView.isHidden = result.count > 0
            }
        })
        ServerRoleManager.shared.queryServerRole(serverId: self.showType.serverId) { role in
            if role == .user {
                self.settingButton.isHidden = true
                self.inviteButtonRightConstraint.constant = 12
            } else {
                self.settingButton.isHidden = false
                self.inviteButtonRightConstraint.constant = 52
            }
        }
        
        EMClient.shared().circleManager?.add(channelDelegate: self, queue: nil)
        EMClient.shared().addMultiDevices(delegate: self, queue: nil)
        VoiceChatManager.shared.addDelegate(self)
        
        NotificationCenter.default.addObserver(self, selector: #selector(didRecvJoinChannelNotification(_:)), name: EMCircleDidJoinChannel, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didRecvLeftChannelNotification(_:)), name: EMCircleDidExitedChannel, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didRecvDestroyChannelNotification(_:)), name: EMCircleDidDestroyChannel, object: nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let corner: UIRectCorner = [.topLeft, .topRight]
        let path = UIBezierPath(roundedRect: self.contentView.bounds, byRoundingCorners: corner, cornerRadii: CGSize(width: 12, height: 12))
        self.shapeLayer.frame = self.contentView.bounds
        self.shapeLayer.path = path.cgPath
    }
    
    private func dismiss() {
        self.dismiss(animated: true)
        VoiceChatManager.shared.removeDelegate(self)
    }
    
    @IBAction func tapAction() {
        self.dismiss()
    }
    
    @IBAction func inviteAction() {
        guard let channel = self.channel else {
            return
        }
        self.dismiss()
        if (self.result?.list?.count ?? 0) >= channel.maxUsers {
            Toast.show("语聊房已满", duration: 2)
            return
        }
        let vc = FriendInviteViewController()
        vc.didInviteHandle = { userId, complete in
            EMClient.shared().circleManager?.inviteUserToChannel(serverId: self.showType.serverId, channelId: self.showType.channelId, userId: userId, welcome: nil, completion: { error in
                if let error = error {
                    Toast.show(error.errorDescription, duration: 2)
                } else {
                    let body = EMCustomMessageBody(event: "invite_channel", customExt: [
                        "server_id": self.showType.serverId,
                        "server_name": self.server?.name ?? "",
                        "icon": self.server?.icon ?? "",
                        "channel_id": self.showType.channelId,
                        "desc": self.channel?.desc ?? "",
                        "channel_name": self.channel?.name ?? ""
                    ])
                    let message = EMChatMessage(conversationID: userId, from: EMClient.shared().currentUsername!, to: userId, body: body, ext: nil)
                    EMClient.shared().chatManager?.send(message, progress: nil)
                    complete(true)
                }
            })
        }
        self.fromViewController.navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func settingAction() {
        self.dismiss()
        let vc = ChannelEditViewController(serverId: self.showType.serverId, channelId: self.showType.channelId)
        self.fromViewController.navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func joinAction() {
        if let current = VoiceChatManager.shared.currentChannel {
            let alertVc = UIAlertController(title: nil, message: "您已经在一个语聊房频道内了，确认要切换到 \(self.channelNameLabel.text ?? "") 吗", preferredStyle: .alert)
            alertVc.addAction(UIAlertAction(title: "我再想想", style: .cancel))
            alertVc.addAction(UIAlertAction(title: "确认", style: .default, handler: { _ in
                EMClient.shared().circleManager?.leaveChannel(current.serverId, channelId: current.channelId, completion: { error in
                    if let error = error {
                        Toast.show(error.errorDescription, duration: 2)
                    } else {
                        NotificationCenter.default.post(name: EMCircleDidExitedChannel, object: (current.serverId, current.channelId))
                    }
                })
                self.joinChannel()
            }))
            self.present(alertVc, animated: true)
        } else {
            self.joinChannel()
        }
    }
    
    @IBAction func muteAction() {
        if self.muteButton.isSelected {
            self.muteButton.isSelected = false
        } else {
            self.muteButton.isSelected = true
        }
        VoiceChatManager.shared.mute(self.muteButton.isSelected)
        self.tableView.reloadData()
    }
    
    @IBAction func leaveAction() {
        self.dismiss()
        EMClient.shared().circleManager?.leaveChannel(self.showType.serverId, channelId: self.showType.channelId, completion: { error in
            if let error = error {
                Toast.show(error.errorDescription, duration: 2)
            }
        })
        NotificationCenter.default.post(name: EMCircleDidExitedChannel, object: (self.showType.serverId, self.showType.channelId))
        VoiceChatManager.shared.leaveChannel()
    }
    
    @objc private func didRecvJoinChannelNotification(_ notification: Notification) {
        if let channel = notification.object as? EMCircleChannel, self.showType.channelId == channel.channelId, let userId = EMClient.shared().currentUsername {
            if let list = self.result?.list {
                for i in list where i.userId == userId {
                    return
                }
            }
            ServerRoleManager.shared.queryServerRole(serverId: channel.serverId) { role in
                UserInfoManager.share.queryUserInfo(userId: userId, loadCache: true) { _, _ in
                    let member = EMCircleUser()
                    member.userId = userId
                    member.role = role
                    self.addMember(member)
                }
            }
        }
    }
    
    @objc private func didRecvLeftChannelNotification(_ notification: Notification) {
        if let channel = notification.object as? (String, String), let userId = EMClient.shared().currentUsername {
            if channel.1 == self.showType.channelId {
                self.removeMember(userId)
            }
        }
    }
    
    @objc private func didRecvDestroyChannelNotification(_ notification: Notification) {
        if let channel = notification.object as? (String, String) {
            if channel.1 == self.showType.channelId {
                self.dismiss()
            }
        }
    }
    
    private func removeMember(_ member: String) {
        guard let list = self.result?.list else {
            return
        }
        for i in 0..<list.count where list[i].userId == member {
            self.result?.list?.remove(at: i)
            self.tableView.reloadData()
            break
        }
        self.tableView.isHidden = list.count <= 0
        self.noDataView.isHidden = list.count > 0
    }
    
    private func addMember(_ member: EMCircleUser) {
        self.result?.list?.append(member)
        self.tableView.reloadData()
        
        self.tableView.isHidden = false
        self.noDataView.isHidden = true
    }
    
    private func joinChannel() {
        EMClient.shared().circleManager?.joinChannel(self.showType.serverId, channelId: self.showType.channelId, completion: { channel, error in
            if let error = error {
                if error.code == .reachLimit {
                    Toast.show("语聊房已满", duration: 2)
                } else {
                    Toast.show(error.errorDescription, duration: 2)
                }
            } else {
                self.joinButton.isHidden = true
                self.muteButton.isHidden = false
                self.leaveButton.isHidden = false
                self.inviteButton.isHidden = false
                VoiceChatManager.shared.joinChannel(serverId: self.showType.serverId, channel: self.showType.channelId)
                if let channel = channel {
                    NotificationCenter.default.post(name: EMCircleDidJoinChannel, object: channel)
                }
            }
        })
    }
    
    @IBAction private func goServerAction() {
        self.dismiss()
        NotificationCenter.default.post(name: MainShouldSelectedServer, object: self.showType.serverId)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension VoiceChannelViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.result?.list?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        if let cell = cell as? VoiceChannelMemberTableViewCell, let item = self.result?.list?[indexPath.row] {
            if let userInfo = UserInfoManager.share.userInfo(userId: item.userId) {
                cell.avatarImageView.setImage(withUrl: userInfo.avatarUrl, placeholder: "head_placeholder")
                cell.nameLabel.text = userInfo.showname
            } else {
                cell.avatarImageView.image = UIImage(named: "head_placeholder")
                cell.nameLabel.text = item.userId
            }
            cell.muteImageView.isHidden = !VoiceChatManager.shared.isMuted(username: item.userId)
            cell.isSpeak = VoiceChatManager.shared.isSpeak(username: item.userId)
        }
        return cell
    }
}

extension VoiceChannelViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let members = self.result?.list else {
            return
        }
        let member = members[indexPath.row]
        if member.userId == EMClient.shared().currentUsername {
            return
        }
        ServerRoleManager.shared.queryServerRole(serverId: self.showType.serverId) { role in
            EMClient.shared().presenceManager?.fetchPresenceStatus([member.userId], completion: { presences, _ in
                var state: UserStatusView.Status = .offline
                if let presences = presences {
                    for i in presences where i.publisher == member.userId {
                        state = i.userStatus
                        break
                    }
                }
                DispatchQueue.main.async {
                    let vc = ServerUserMenuViewController(userId: member.userId, showType: .voiceChannel(serverId: self.showType.serverId, channelId: self.showType.channelId), role: role, targetRole: member.role, onlineState: state, isMute: false)
                    vc.didKickHandle = { userId in
                        for i in 0..<members.count where member.userId == userId {
                            self.result?.list?.remove(at: i)
                            self.tableView.reloadData()
                            break
                        }
                        self.tableView.isHidden = self.result?.count ?? 0 <= 0
                        self.noDataView.isHidden = self.result?.count ?? 0 > 0
                    }
                    self.present(vc, animated: true)
                }
            })
        }
    }
}

extension VoiceChannelViewController: VoiceChatManagerDelegate {
    func voiceManagerDidAudioMuted(channel: String, username: String, muted: Bool) {
        if username == EMClient.shared().currentUsername {
            self.muteButton.isSelected = muted
        }
        self.tableView.reloadData()
    }
    
    func voiceManagerDidUserSpeak(channel: String, usernames: [String]) {
        if usernames.count > 0 {
            self.tableView.reloadData()
        }
    }
    
    func voiceManagerDidUserSpeakEnd(channel: String, usernames: [String]) {
        if usernames.count > 0 {
            self.tableView.reloadData()
        }
    }
}

extension VoiceChannelViewController: EMCircleManagerChannelDelegate {
    func onMemberLeftChannel(_ serverId: String, categoryId: String, channelId: String, member: String) {
        if channelId != self.showType.channelId {
            return
        }
        self.removeMember(member)
    }
    
    func onMemberRemoved(fromChannel serverId: String, categoryId: String, channelId: String, member: String, initiator: String) {
        if channelId != self.showType.channelId {
            return
        }
        if member == EMClient.shared().currentUsername {
            self.dismiss()
            Toast.show("你已被移除语聊房", duration: 2)
        } else {
            self.removeMember(member)
        }
    }
    
    func onMemberJoinedChannel(_ serverId: String, categoryId: String, channelId: String, member: EMCircleUser) {
        if channelId != self.showType.channelId {
            return
        }
        self.addMember(member)
    }
    
    func onChannelDestroyed(_ serverId: String, categoryId: String, channelId: String, initiator: String) {
        if channelId == self.showType.channelId {
            self.dismiss()
        }
    }
}

extension VoiceChannelViewController: EMMultiDevicesDelegate {
    func multiDevicesCircleChannelEventDidReceive(_ aEvent: EMMultiDevicesEvent, channelId aChannelId: String, ext aExt: Any?) {
        if aChannelId != self.showType.channelId {
            return
        }
        switch aEvent {
        case .circleChannelJoin:
            if let userId = EMClient.shared().currentUsername {
                ServerRoleManager.shared.queryServerRole(serverId: self.showType.serverId) { role in
                    let member = EMCircleUser()
                    member.userId = userId
                    member.role = role
                    self.addMember(member)
                }
            }
        case .circleChannelExit:
            if let userId = EMClient.shared().currentUsername {
                self.removeMember(userId)
            }
        case .circleChannelDestroy:
            self.dismiss()
        default:
            break
        }
    }
}

extension VoiceChannelViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view?.superview is UITableViewCell {
            return false
        }
        return true
    }
}

extension VoiceChannelViewController.ShowType {
    var serverId: String {
        switch self {
        case .detail(server: let server, channel: _):
            return server.serverId
        case .id(serverId: let serverId, channelId: _, closeHandle: _):
            return serverId
        }
    }
    
    var channelId: String {
        switch self {
        case .detail(server: _, channel: let channel):
            return channel.channelId
        case .id(serverId: _, channelId: let channelId, closeHandle: _):
            return channelId
        }
    }
}
