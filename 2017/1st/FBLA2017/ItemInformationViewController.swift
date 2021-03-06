//
//  InfoViewController.swift
//  FBLA2017
//
//  Created by Luke Mann on 4/13/17.
//  Copyright © 2017 Luke Mann. All rights reserved.
//

import UIKit
import Popover
import FirebaseDatabase
import FirebaseAuth
import NVActivityIndicatorView
import ChameleonFramework
import Instructions

protocol NextItemDelegate {
    func goToNextItem()
}

protocol DismissDelgate {
    func switchCurrentVC(shouldReload: Bool)
}

//This class is presented above pictures of the items 
class InfoContainerViewController: UIViewController {
    
    var item: Item?
    var tempUserImage: UIImage?
    
    let walkthroughController = CoachMarksController()
    
    var nextItemDelegate: NextItemDelegate?
    var dismissDelegate: DismissDelgate?
    
    var ref: FIRDatabaseReference =
        FIRDatabase.database().reference().child(currentGroup).child("users").child((FIRAuth.auth()?.currentUser?.uid)!).child("likedCoverImages")
    
    var activitityIndicator: NVActivityIndicatorView?
    
    @IBOutlet weak var favoriteButton: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        pageControl.transform = CGAffineTransform(rotationAngle: CGFloat(M_PI / 2))
        setupViews()
        
        walkthroughController.dataSource = self
        
        item?.user?.delegate = self
        
        //The remove from sale button only shows if the seller selects the item
        if (item?.user?.uid == currentUser.uid) {
            soldButton.isHidden = false
            soldButton.layer.cornerRadius = soldButton.frame.height / 2
            profileButton.isHidden = true
            profileImage.isHidden = true
            ratingLabel.isHidden = true
            conditionTitleLabel.isHidden = true
            titleLabel.isHidden = true
            costLabel.isHidden = true
            
        }
    }
    func setupViews() {
        if (item?.hasLiked)! {
            favoriteButton.setImage(#imageLiteral(resourceName: "HeartFilled"), for: .normal)
        }
        if let tempUserImage = self.tempUserImage {
            self.profileImage.image = tempUserImage
        } else {
            activitityIndicator = ActivityIndicatorLoader.startActivityIndicator(view: profileImage)
        }
        profileImage.layer.borderWidth = 1
        profileImage.layer.masksToBounds = false
        profileImage.layer.borderColor = UIColor.flatGrayDark.cgColor
        profileImage.layer.cornerRadius = profileImage.frame.height / 2
        profileImage.clipsToBounds = true
        
        if let rating: Int = item?.condition, let dollarsString: String = item?.dollarString {
            costLabel.text="Asking Price: \(dollarsString)"
            ratingLabel.text="\(String(describing: rating))/5"
            
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier=="showPageVC" {
            let pageDesitnation = segue.destination as! PageViewController
            pageDesitnation.images = self.item?.images
            titleLabel.text = item?.name
            pageDesitnation.pageControl = self.pageControl
            pageDesitnation.nextItemDelegate = self
            
        }
    }
    
    @IBAction func moreInfoButtonPressed(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "detailTop") as! MoreDetailsViewController
        vc.profileImageView = profileImage
        vc.item = self.item
        
        let sizeToSubtract = moreInfoButtonToTopConstraint.constant * (-1.4)
        let newFrame = CGRect(x: vc.view.frame.minX, y: vc.view.frame.minY, width: vc.view.frame.width - 10, height: vc.view.frame.height - sizeToSubtract)
        vc.view.frame = newFrame
        print(newFrame.height)
        print(newFrame.width)
        let point = CGPoint(x: moreInfoButton.center.x, y: moreInfoButton.center.y - (-1.0) * moreInfoButton.frame.height / 2)
        let popover = Popover()
        popover.show(vc.view!, point: point)
        
    }
    
    //MARK: - Favorites button control
    @IBAction func likeButtonPressed() {
        
        if (item?.hasLiked)! {
            favoriteButton.setImage(#imageLiteral(resourceName: "HeartEmpty"), for: .normal)
            if let keyString = item?.keyString {
                ref.child("\(keyString)").removeValue()
            }
            item?.hasLiked = false
        } else {
            favoriteButton.setImage(#imageLiteral(resourceName: "HeartFilled"), for: .normal)
            if let keyString = item?.keyString, let coverImagePath = item?.coverImagePath {
                ref.child("\(keyString)").setValue(coverImagePath)
            }
            item?.hasLiked = true
        }
        
    }
    
    @IBAction func exitButtonPressed(_ sender: UIButton) {
        dismissDelegate?.switchCurrentVC(shouldReload: false)
    }
    @IBOutlet var moreInfoButton: UIButton!
    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var costLabel: UILabel!
    @IBOutlet weak var ratingLabel: UILabel!
    @IBOutlet var moreInfoButtonToTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var profileButton: UIButton!
    @IBOutlet weak var soldButton: UIButton!
    @IBOutlet weak var conditionTitleLabel: UILabel!
    @IBOutlet weak var pageControl: UIPageControl!
    
    @IBAction func profileButtonPressed(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        let viewController = storyboard.instantiateViewController(withIdentifier: "OtherUserProfile") as! OtherUserProfileViewController
        viewController.otherUser = self.item?.user
        present(viewController, animated: true, completion: nil)
    }
    
    @IBAction func soldButtonPressed() {
        
        let alertController = UIAlertController(title: "Mark as Sold", message: "Are you sure you want to mark your product as sold?", preferredStyle: .alert)
        
        let okAction = UIAlertAction(title: "Mark as Sold", style: UIAlertActionStyle.default) {
            _ in
            NSLog("OK Pressed")
            self.removeItem(alertController: alertController)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel) {
            _ in
            NSLog("Cancel Pressed")
        }
        
        alertController.addAction(okAction)
        alertController.addAction(cancelAction)
        
        self.present(alertController, animated: true, completion: nil)
        
    }
    //MARK:- Remove item
    func removeItem(alertController: UIAlertController) {
        let ref = FIRDatabase.database().reference().child(currentGroup)
        
        ref.child("users").child((item?.user!.uid)!).child("coverImages").observe(.value, with: { (snapshot) in
            if let snapshots = snapshot.children.allObjects as? [FIRDataSnapshot] {
                for snapshot in snapshots {
                    if let path = snapshot.key as? String {
                        if let path2 = snapshot.value as? String {
                            if path2 == self.item?.coverImagePath {
                                
                                ref.child("users").child(self.item?.user?.uid ?? "n/a").child("coverImages").child(path).removeValue()
                                ref.child("users").child(self.item?.user?.uid ?? "n/a").child("itemChats").child(path).removeValue()
                                
                                let path: String = self.item?.keyString ?? "n/a"
                                ref.child("items").child(path).removeValue()
                                ref.child("coverImagePaths").child(self.item?.keyString ?? "n/a").removeValue()
                                alertController.dismiss(animated: false, completion: nil)
                                if let dd: FirstContainerViewController = self.dismissDelegate as? FirstContainerViewController {
                                    if dd.dismissDelegate == nil {
                                        self.item?.deleted = true
                                        self.dismissDelegate?.switchCurrentVC(shouldReload: false)
                                    } else {
                                        self.dismissDelegate?.switchCurrentVC(shouldReload: true)
                                        
                                    }
                                }
                                break
                            }
                        }
                    }
                }
            }
            
        })
        
    }
    
}

//MARK: - Switch between items by tapping
extension InfoContainerViewController:NextItemDelegate {
    func goToNextItem() {
        self.nextItemDelegate?.goToNextItem()
        
    }
}

extension InfoContainerViewController:UserDelegate {
    func imageLoaded(image: UIImage, user: User, index: Int?) {
        self.profileImage.image = image
        
    }
    
}

//MARK: - Walkthrough
extension InfoContainerViewController: CoachMarksControllerDataSource, CoachMarksControllerDelegate {
    func numberOfCoachMarks(for coachMarksController: CoachMarksController) -> Int {
        if (item?.user?.uid == currentUser.uid) {
            return 0
        }
        return 1
    }
    func coachMarksController(_ coachMarksController: CoachMarksController,
                              coachMarkAt index: Int) -> CoachMark {
        return coachMarksController.helper.makeCoachMark(for: self.profileImage)
    }
    func coachMarksController(_ coachMarksController: CoachMarksController, coachMarkViewsAt index: Int, madeFrom coachMark: CoachMark) -> (bodyView: CoachMarkBodyView, arrowView: CoachMarkArrowView?) {
        let view = coachMarksController.helper.makeDefaultCoachViews(withArrow: true, arrowOrientation: coachMark.arrowOrientation)
        
        view.bodyView.hintLabel.text = "Tap this to view the seller's profile"
        view.bodyView.hintLabel.font = Fonts.regular.get(size: 16)
        view.bodyView.nextLabel.font = Fonts.regular.get(size: 16)
        view.bodyView.nextLabel.text = "Ok!"
        
        return (bodyView: view.bodyView, arrowView: view.arrowView)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if !UserDefaults.standard.bool(forKey: "ItemWalkthroughHasLoaded") {
            self.walkthroughController.startOn(self)
            UserDefaults.standard.set(true, forKey: "ItemWalkthroughHasLoaded")
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.walkthroughController.stop(immediately: true)
    }
}
