//
//  MessageServerChannelCell.swift
//  discord-ios
//
//  Created by 冯钊 on 2022/6/29.
//

import UIKit
import HyphenateChat

class MessageServerChannelCell: UITableViewCell {

    enum ShowType {
        case threads(threads: [EMChatThread])
        case members(members: [(EMCircleUser, EMUserInfo)])
    }
    
    @IBOutlet private weak var channelButton: UIButton!
    @IBOutlet private weak var privateImageView: UIImageView!
    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var foldButton: UIButton!
    @IBOutlet private weak var foldImageView: UIImageView!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var unreadView: UIView!
    @IBOutlet private weak var unreadCountLabel: UILabel!
    @IBOutlet private weak var sublevelLabel: UILabel!
    @IBOutlet private weak var foldButtonHeightConstraints: NSLayoutConstraint!
    
    var speakSet: Set<String>? {
        didSet {
            self.tableView.reloadData()
        }
    }
    var muteSet: Set<String>? {
        didSet {
            self.tableView.reloadData()
        }
    }
    
    var isFold = true {
        didSet {
            UIView.animate(withDuration: 0.2) {
                self.foldImageView.transform = CGAffineTransform(rotationAngle: self.isFold ? 0 : CGFloat.pi)
            }
        }
    }
    
    var isLoading: Bool = false
    
    var channel: EMCircleChannel? {
        didSet {
            self.nameLabel.text = channel?.name
            if channel?.mode == .chat {
                self.privateImageView.image = UIImage(named: channel?.type == .private ? "#_channel_private" : "#_channel_public")
                self.sublevelLabel.text = "子区"
                if let channelId = self.channel?.channelId, let conversation = EMClient.shared().chatManager?.getConversation(channelId, type: .groupChat, createIfNotExist: true, isThread: false, isChannel: true) {
                    if conversation.unreadMessagesCount > 0 {
                        self.unreadView.isHidden = false
                        self.unreadCountLabel.text = "\(conversation.unreadMessagesCount)"
                        self.unreadView.backgroundColor = UIColor(named: ColorName_FF1477)
                        self.unreadCountLabel.textColor = .white
                    } else {
                        self.unreadView.isHidden = true
                    }
                } else {
                    self.unreadView.isHidden = true
                }
            } else {
                self.foldButton.isHidden = false
                self.foldButtonHeightConstraints.constant = 32
                self.privateImageView.image = UIImage(named: channel?.type == .private ? "mic_channel_private" : "mic_channel_public")
                self.sublevelLabel.text = "语聊房成员"
                self.unreadCountLabel.text = "\(self.channel?.maxUsers ?? 0)"
                self.unreadView.isHidden = false
                if self.channel?.channelId == VoiceChatManager.shared.currentChannel?.channelId {
                    self.unreadView.backgroundColor = UIColor(named: ColorName_14FF72)
                    self.unreadCountLabel.textColor = UIColor(named: ColorName_181818)
                } else {
                    self.unreadView.backgroundColor = nil
                    self.unreadCountLabel.textColor = UIColor(named: ColorName_757575)
                }
            }
        }
    }
    
    var showType: ShowType?
    var hasNoMoreData: Bool?
    
    var channelClickHandle: ((_ channel: EMCircleChannel) -> Void)?
    var memberClickHandle: ((_ channel: EMCircleChannel, _ member: (EMCircleUser, EMUserInfo)) -> Void)?
    var foldClickHandle: ((_ channel: EMCircleChannel) -> Void)?
    var threadClickHandle: ((_ thread: EMChatThread) -> Void)?
    var moreClickHandle: ((_ channel: EMCircleChannel) -> Void)?
    var channelLongPressHandle: ((_ channel: EMCircleChannel) -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.tableView.tableFooterView = UIView()
        self.tableView.separatorStyle = .none
        self.tableView.separatorColor = UIColor.clear
        self.tableView.register(UINib(nibName: "MessageServerThreadCell", bundle: nil), forCellReuseIdentifier: "ThreadCell")
        self.tableView.register(UINib(nibName: "VoiceChannelMemberTableViewCell", bundle: nil), forCellReuseIdentifier: "MemberCell")
        self.tableView.register(UINib(nibName: "MessageServerThreadListFooter", bundle: nil), forHeaderFooterViewReuseIdentifier: "footer")
            
        self.channelButton.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(channelLongPressAction)))
    }
    
    @IBAction func channelAction() {
        if let channel = channel {
            self.channelClickHandle?(channel)
        }
    }
    
    @IBAction func foldAction() {
        if let channel = channel {
            self.foldClickHandle?(channel)
        }
    }
    
    func setThreads(threads: [EMChatThread], hasNoMoreData: Bool, isLoading: Bool) {
        self.foldButton.isHidden = threads.count <= 0
        self.foldButtonHeightConstraints.constant = threads.count <= 0 ? 0 : 32
        self.tableView.isHidden = self.isFold
        if self.isFold {
            return
        }
        self.isLoading = isLoading
        self.showType = .threads(threads: threads)
        self.hasNoMoreData = hasNoMoreData
        self.tableView.reloadData()
    }
    
    func setMembers(_ members: [(EMCircleUser, EMUserInfo)]) {
        self.foldButton.isHidden = false
        self.foldButtonHeightConstraints.constant = 32
        self.tableView.isHidden = self.isFold
        if self.isFold {
            return
        }
        self.isLoading = false
        self.showType = .members(members: members)
        self.hasNoMoreData = true
        self.tableView.reloadData()
        let total = self.channel?.maxUsers ?? 0
        let max = max(members.count, Int(total))
        self.unreadCountLabel.text = "\(members.count)/\(max)"
        self.unreadView.backgroundColor = self.channel?.channelId == VoiceChatManager.shared.currentChannel?.channelId ? UIColor(named: ColorName_14FF72) : nil
    }
    
    @objc private func channelLongPressAction() {
        if let channel = self.channel {
            self.channelLongPressHandle?(channel)
        }
    }
}

extension MessageServerChannelCell: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.isFold {
            return 0
        }
        return self.showType?.count() ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch self.showType {
        case .threads(let threads):
            let cell = tableView.dequeueReusableCell(withIdentifier: "ThreadCell", for: indexPath)
            if let cell = cell as? MessageServerThreadCell {
                cell.nameLabel.text = threads[indexPath.row].threadName
            }
            return cell
        case .members(let members):
            let cell = tableView.dequeueReusableCell(withIdentifier: "MemberCell", for: indexPath)
            if let cell = cell as? VoiceChannelMemberTableViewCell {
                let member = members[indexPath.row]
                cell.showType = .sublist
                cell.avatarImageView.setImage(withUrl: member.1.avatarUrl, placeholder: "head_placeholder")
                cell.nameLabel.text = member.1.showname
                cell.muteImageView.isHidden = !(self.muteSet?.contains(member.0.userId) ?? false)
                cell.isSpeak = self.speakSet?.contains(member.0.userId) ?? false
            }
            return cell
        default:
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if self.hasNoMoreData ?? true {
            return nil
        }
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: "footer")
        if let view = view as? MessageServerThreadListFooter {
            view.clickHandle = { [unowned self] in
                if let channel = self.channel {
                    self.moreClickHandle?(channel)
                }
            }
            view.isLoading = self.isLoading
        }
        return view
    }
}

extension MessageServerChannelCell: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch self.showType {
        case .threads(let threads):
            self.threadClickHandle?(threads[indexPath.row])
        case .members(let members):
            if let channel = self.channel {
                self.memberClickHandle?(channel, members[indexPath.row])
            }
        default:
            break
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if self.hasNoMoreData ?? true {
            return 0
        }
        return 32
    }
}

extension MessageServerChannelCell.ShowType {
    func count() -> Int {
        switch self {
        case .members(let members):
            return members.count
        case .threads(let threads):
            return threads.count
        }
    }
}
