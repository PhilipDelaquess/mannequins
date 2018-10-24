//
//  GameViewController.swift
//  SKMannequins
//
//  Created by Philip Delaquess on 10/11/18.
//  Copyright © 2018 Philip Delaquess. All rights reserved.
//

import UIKit
import QuartzCore
import SceneKit

class GameViewController: UIViewController {

    private let pixelsPerRadian = Float(360)
    private let twistFactor = Float(2)

    var sceneView : SCNView!
    var mannequinScene : SCNScene!
    var selfieStick: SCNNode!
    var armature: Segment!
    var selectedSegment: Segment?
    var startingTouches = 0
    var startingEulers: SCNVector3?
    var startingSelfieX: SCNVector3?
    var startingSelfieZ: SCNVector3?

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView = self.view as! SCNView

        mannequinScene = SCNScene(named: "mannequin.scn")!
        sceneView.scene = mannequinScene
        selfieStick = mannequinScene.rootNode.childNode(withName: "selfieStick", recursively: true)!

        let path = Bundle.main.path(forResource: "armature", ofType: "plist")
        let dict = NSDictionary(contentsOfFile: path!) as! [String : Any]
        armature = Segment(dict: dict, parentNode: mannequinScene.rootNode)

        // Tap recognizer selects body part
        let tapper = UITapGestureRecognizer()
        tapper.numberOfTapsRequired = 1
        tapper.numberOfTouchesRequired = 1
        tapper.addTarget(self, action: #selector(GameViewController.sceneViewTapped(recognizer:)))
        sceneView.addGestureRecognizer(tapper)

        // Double-tap recognizer resets segment
        let dblTapper = UITapGestureRecognizer()
        dblTapper.numberOfTapsRequired = 2
        dblTapper.numberOfTouchesRequired = 1
        dblTapper.addTarget(self, action: #selector(GameViewController.sceneViewDblTapped(recognizer:)))
        sceneView.addGestureRecognizer(dblTapper)

        // Pan recognizer rotates selected body part or the whole scene
        let panner = UIPanGestureRecognizer()
        panner.addTarget(self, action: #selector(GameViewController.sceneViewPanned(recognizer:)))
        sceneView.addGestureRecognizer(panner)

        // Rotate recognizer twists selected body part if it has freedom around Y
        let rotater = UIRotationGestureRecognizer()
        rotater.addTarget(self, action: #selector(GameViewController.sceneViewRotated(recognizer:)))
        sceneView.addGestureRecognizer(rotater)
    }

    func panCamera (_ recognizer: UIPanGestureRecognizer) {
        if recognizer.state == .began {
            startingTouches = 2
            startingEulers = selfieStick.eulerAngles
        } else if recognizer.state == .changed && startingTouches == 2 {
            let trans = recognizer.translation(in: sceneView)
            let yRads = Float(trans.x)  * Float.pi / -pixelsPerRadian
            let xRads = Float(trans.y) * Float.pi / -pixelsPerRadian
            let curr = startingEulers!
            let xNew = Float.minimum(Float.maximum(curr.x + xRads, Float.pi * -0.49), Float.pi * 0.49)
            selfieStick.eulerAngles = SCNVector3Make(xNew, curr.y + yRads, curr.z)
        }
    }

    /*
 Some ideas on rotating segments:

     Finger movement determines a delta angle around a vector aimed at the camera.
     The selfieStick orientation is such a vector.
     The segment origin projected onto the screen compared to the pan begin location
     results in a starting angle. That same projection combined with the pan change location
     results in a current angle. Their delta is the angle around the camera Z axis that I attempt
     to rotate. I need to transform the camera Z into the segment's local coordinates,
     apply the rotation, and then clamp the euler angles.
     A SCNNode has a 'transform' matrix, a 'rotation' 4-vector, an 'orientation' quaternion,
     and 'eulerAngles'. With any luck, setting one of them should recalculate all the others.

     I could write some unit tests to experiment with this.
 */

    func panSegment (_ recognizer: UIPanGestureRecognizer) {
        if let segment = selectedSegment {
            let node = segment.node
            if recognizer.state == .began {
                startingTouches = 1
                startingEulers = segment.eulerCurrent

                // What is the selfieStick Z axis in the world?
                //let worldZ = selfieStick.transform * SCNVector3Make(0, 0, 1)
                //NSLog("%@", "selfie world Z axis is \(worldZ.x) \(worldZ.y) \(worldZ.z)")

                // Where is world origin in node local?
                let sOrigin = node.parent!.convertVector(SCNVector3Make(0, 0, 0), from: selfieStick)
                let sxAxis = node.parent!.convertVector(SCNVector3Make(1, 0, 0), from: selfieStick)
                let szAxis = node.parent!.convertVector(SCNVector3Make(0, 0, 1), from: selfieStick)
                startingSelfieX = SCNVector3Make(sxAxis.x - sOrigin.x, sxAxis.y - sOrigin.y, sxAxis.z - sOrigin.z)
                startingSelfieZ = SCNVector3Make(szAxis.x - sOrigin.x, szAxis.y - sOrigin.y, szAxis.z - sOrigin.z)
                NSLog("%@", "selfie segment X axis is \(startingSelfieX!.x) \(startingSelfieX!.y) \(startingSelfieX!.z)")
                NSLog("%@", "selfie segment Z axis is \(startingSelfieZ!.x) \(startingSelfieZ!.y) \(startingSelfieZ!.z)")

            } else if recognizer.state == .changed && startingTouches == 1 {
                let trans = recognizer.translation(in: sceneView)
                // X increases to the right, Y increases DOWN
                let vrads = Float(trans.y)  * Float.pi / pixelsPerRadian
                let hrads = Float(trans.x)  * Float.pi / (node.name == "Head" ? -pixelsPerRadian : pixelsPerRadian)
                let sx = startingSelfieX!
                let sz = startingSelfieZ!
                let dx = vrads * sx.x + hrads * sz.x
                let dz = vrads * sx.z + hrads * sz.z
                let min = segment.eulerMin
                let max = segment.eulerMax

                // when selfie X is 1 0 0, x rot is all deltaY, z rot is all deltaX
                // when selfie X is 0 0 -1

                // figure facing me, (1 0 0) (0 0 1)
                // dv -> xrot, dh -> zrot or xrot = sx.x times dv +/- sx.z or sz.x times dh
                // figure facing left, (0 0 -1) (1 0 0)
                // dv -> -zrot, dh -> xrot, xrot = sx.x times dv + sz.x times dh
                // figure facing away, (-1 0 0) (0 0 -1)
                // dv -> -xrot, dh -> -zrot or xrot = sx.x times dv + sz.x times dh
                // figure facing right, (0 0 1) (-1 0 0)
                // dv -> zrot, dh -> -xrot or xrot = sx.x times dv _ sz.x times dh

                let curr = startingEulers!
                let xNew = Float.minimum(Float.maximum(curr.x + dx, min.x), max.x)
                let zNew = Float.minimum(Float.maximum(curr.z + dz, min.z), max.z)
                segment.eulerCurrent = SCNVector3Make(xNew, curr.y, zNew)
                segment.applyEuler()
            }
        }
    }

    @objc func sceneViewTapped (recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: sceneView)
        let hitResults = sceneView.hitTest(location, options: nil)
        var hitNodeName: String?
        if hitResults.count > 0 {
            let result = hitResults.first
            if let node = result?.node {
                hitNodeName = node.name
                selectedSegment = armature.find(byName: hitNodeName)
                //
            }
        } else {
            selectedSegment = nil
        }
        armature.node.enumerateHierarchy() { node, _ in
            node.geometry!.firstMaterial!.diffuse.contents = node.name == hitNodeName ? UIColor.green : UIColor.yellow
        }
    }

    @objc func sceneViewDblTapped (recognizer: UITapGestureRecognizer) {
        if let segment = selectedSegment {
            segment.reset(recursively: true)
        }
    }

    @objc func sceneViewPanned (recognizer: UIPanGestureRecognizer) {
        if recognizer.numberOfTouches == 2 {
            panCamera(recognizer)
        } else {
            panSegment(recognizer)
        }
    }

    @objc func sceneViewRotated (recognizer: UIRotationGestureRecognizer) {
        if let segment = selectedSegment {
            if recognizer.state == .began {
                startingEulers = segment.eulerCurrent
            } else if recognizer.state == .changed {
                let yRads = Float(recognizer.rotation) * twistFactor
                let min = segment.eulerMin
                let max = segment.eulerMax
                let curr = startingEulers!
                let yNew = Float.minimum(Float.maximum(curr.y + yRads, min.y), max.y)
                segment.eulerCurrent = SCNVector3Make(curr.x, yNew, curr.z)
                segment.applyEuler()
            }
        }
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

}
