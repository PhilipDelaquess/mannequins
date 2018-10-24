//
//  Segment.swift
//  SKMannequins
//
//  Created by Philip Delaquess on 10/12/18.
//  Copyright © 2018 Philip Delaquess. All rights reserved.
//

import SceneKit
import SceneKit.ModelIO

class Segment: NSObject {

    let name: String
    let node: SCNNode
    let location: SCNVector3
    let eulerInitial: SCNVector3
    var eulerCurrent: SCNVector3!
    let eulerMin: SCNVector3
    let eulerMax: SCNVector3
    let children: [Segment]?

    init (dict: [String : Any], parentNode: SCNNode) {
        name = dict["Name"] as! String

        let locStr = dict["Location"] as! String
        location = Segment.makeVector(fromString: locStr)

        var rotX = SCNVector3()
        if let xs = dict["RotX"] as? String {
            rotX = Segment.makeVector(fromString: xs)
        }
        var rotY = SCNVector3()
        if let ys = dict["RotY"] as? String {
            rotY = Segment.makeVector(fromString: ys)
        }
        var rotZ = SCNVector3()
        if let zs = dict["RotZ"] as? String {
            rotZ = Segment.makeVector(fromString: zs)
        }
        eulerMin = SCNVector3Make(rotX.x * Float.pi / 180, rotY.x * Float.pi / 180, rotZ.x * Float.pi / 180)
        eulerInitial = SCNVector3Make(rotX.y * Float.pi / 180, rotY.y * Float.pi / 180, rotZ.y * Float.pi / 180)
        eulerCurrent = eulerInitial
        eulerMax = SCNVector3Make(rotX.z * Float.pi / 180, rotY.z * Float.pi / 180, rotZ.z * Float.pi / 180)

        let objFile = dict["ObjFile"] as! String
        let objPath = Bundle.main.path(forResource: objFile, ofType: "obj")!
        let url = URL(fileURLWithPath: objPath)
        let asset = MDLAsset(url: url)
        let mesh = asset.object(at: 0)

        let thisNode = SCNNode(mdlObject: mesh)
        thisNode.name = name

        thisNode.position = location
        thisNode.eulerAngles = eulerInitial
        parentNode.addChildNode(thisNode)
        node = thisNode

        node.geometry!.firstMaterial!.diffuse.contents = UIColor.yellow
        node.geometry!.firstMaterial!.specular.contents = UIColor.white 

        let subs = dict["Children"] as? [[String : Any]]
        if let s = subs {
            children = s.map { Segment(dict: $0, parentNode: thisNode) }
        } else {
            children = []
        }
    }

    func find (byName name: String?) -> Segment? {
        if self.name == name {
            return self
        }
        for child in children! {
            if let found = child.find(byName: name) {
                return found
            }
        }
        return nil
    }

    func applyEuler () {
        // SCNNode.eulerAngles is applied in X Y Z order. We require X Z Y.
        var m = SCNMatrix4Identity
        m = SCNMatrix4Rotate(m, eulerCurrent.y, 0, 1, 0)
        m = SCNMatrix4Rotate(m, eulerCurrent.z, 0, 0, 1)
        m = SCNMatrix4Rotate(m, eulerCurrent.x, 1, 0, 0)
        m = SCNMatrix4Translate(m, node.position.x, node.position.y, node.position.z)
        node.transform = m
    }

    func reset (recursively recurse: Bool = false) {
        eulerCurrent = eulerInitial
        applyEuler()
        if recurse {
            for child in children! {
                child.reset(recursively: true)
            }
        }
    }

    private static func makeVector (fromString str: String) -> SCNVector3 {
        let coords = str.split(separator: " ").map { Float($0)! }
        return SCNVector3(coords[0], coords[1], coords[2])
    }

}
