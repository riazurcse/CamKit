//
//  ViewController.swift
//  CamKit
//
//  Created by riajur-bitsmedia on 09/16/2021.
//  Copyright (c) 2021 riajur-bitsmedia. All rights reserved.
//

import UIKit
import CamKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func capturePhotoButtonTapped(_ sender: UIButton) {
        guard let cameraVController = CameraViewController.get(for: .photo) else {
            return
        }
        cameraVController.capturePhotoCompletion = { image in
            print(image)
        }
        self.present(cameraVController, animated: true, completion: nil)
    }

    @IBAction func captureVideoButtonTapped(_ sender: UIButton) {
        guard let cameraVController = CameraViewController.get(for: .video) else {
            return
        }
        cameraVController.captureVideoCompletion = { url in
            print(url)
        }
        self.present(cameraVController, animated: true, completion: nil)
    }
}

