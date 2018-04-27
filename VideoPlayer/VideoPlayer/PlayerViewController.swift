//
//  PlayerViewController.swift
//  DriverDemo
//
//  Created by XUXIAOTENG on 11/12/2017.
//  Copyright © 2017 Bravesoft. All rights reserved.
//

import UIKit
import AVKit
import Alamofire

class PlayerViewController: UIViewController {
    
    let videoURL = URL(string: "http://45.76.67.253/faded.mp4")!
    let videoScheme = "video"
    
    var playerController: AVPlayerViewController!
    var player: AVPlayer!
    
    lazy var resourceManager = PlayerResourceManager(videoURL: videoURL, videoScheme: videoScheme)
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.navigationItem.largeTitleDisplayMode = .never
        
//        player = AVPlayer(url: videoURL)
        self.preparePlayer()
        
        playerController = AVPlayerViewController()
        playerController.player = player
        playerController.view.frame = self.view.bounds
        self.addChildViewController(playerController)
        self.view.addSubview(playerController.view)
        player.play()
        
//        let playerLayer = AVPlayerLayer(player: player)
//        playerLayer.frame = self.view.bounds
//        self.view.layer.addSublayer(playerLayer)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: true)
    }

    func preparePlayer() {
        var urlComponents = URLComponents(url: videoURL, resolvingAgainstBaseURL: false)
        urlComponents?.scheme = videoScheme
        
        guard let url = urlComponents?.url else {
            return
        }
        let urlAsset = AVURLAsset(url: url)
        urlAsset.resourceLoader.setDelegate(resourceManager, queue: DispatchQueue.main)
        
        let playerItem = AVPlayerItem(asset: urlAsset)
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        
        player = AVPlayer(playerItem: playerItem)
        player.replaceCurrentItem(with: playerItem)
    }

}
