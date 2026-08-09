//
//  SkiScene.swift
//  Skii
//

import SpriteKit
import CoreMotion
import UIKit

final class SkiScene: SKScene {
    private enum TileSheet {
        static let resourceName = "tilemap"
        static let resourceExtension = "png"
        static let tileSize = CGSize(width: 16, height: 16)
        static let spacing: CGFloat = 1
        static let columns = 12
        static let rows = 11
    }

    private let backgroundLayer = SKNode()
    private let obstacleLayer = SKNode()
    private let skierLayer = SKNode()
    private let hudLayer = SKNode()

    private var snowPages: [SKNode] = []
    private var treeNodes: [SKNode] = []
    private var skierNode: SKNode?
    private var snowEmitter: SKEmitterNode?
    private var distanceLabel: SKLabelNode?
    private var gameOverLabel: SKLabelNode?

    private var lastUpdateTime: TimeInterval = 0
    private var treeSpawnAccumulator: TimeInterval = 0
    private var distanceTravelled: CGFloat = 0
    private var lateralTilt: CGFloat = 0
    private var lateralVelocity: CGFloat = 0
    private var isGameOver = false

    private let motionManager = CMMotionManager()
    private let scrollSpeed: CGFloat = 180
    private let maxLateralSpeed: CGFloat = 340
    private let treeSpawnInterval: TimeInterval = 0.7

    private var skierVerticalPosition: CGFloat {
        size.height * 0.25
    }

    private lazy var tileSheetTexture = SKTexture(imageNamed: TileSheet.resourceName)
    private lazy var snowTextures = textures(for: [1, 2, 3, 4, 5, 6])
    private lazy var treeTextures = textures(for: [7, 8, 19, 20])

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.82, green: 0.93, blue: 1.0, alpha: 1.0)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        scaleMode = .resizeFill
    }

    deinit {
        motionManager.stopDeviceMotionUpdates()
        motionManager.stopAccelerometerUpdates()
    }

    override func didMove(to view: SKView) {
        removeAllChildren()

        addChild(backgroundLayer)
        addChild(obstacleLayer)
        addChild(skierLayer)
        addChild(hudLayer)

        backgroundLayer.zPosition = 0
        obstacleLayer.zPosition = 10
        skierLayer.zPosition = 20
        hudLayer.zPosition = 40

        rebuildSceneForCurrentSize()
        startMotionUpdates()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)

        guard view != nil else { return }
        rebuildSceneForCurrentSize()
    }

    override func update(_ currentTime: TimeInterval) {
        let deltaTime = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        guard deltaTime > 0 else { return }

        guard !isGameOver else { return }

        updateSkier(deltaTime: CGFloat(deltaTime))
        distanceTravelled += CGFloat(deltaTime) * scrollSpeed
        updateDistanceLabel()
        scrollSnow(by: CGFloat(deltaTime) * scrollSpeed)
        scrollTrees(by: CGFloat(deltaTime) * scrollSpeed)
        spawnTreesIfNeeded(deltaTime: deltaTime)
        checkTreeCollisions()
    }

    private func rebuildSceneForCurrentSize() {
        guard size.width > 0, size.height > 0 else { return }

        backgroundLayer.removeAllChildren()
        obstacleLayer.removeAllChildren()
        skierLayer.removeAllChildren()
        hudLayer.removeAllChildren()
        snowPages.removeAll()
        treeNodes.removeAll()
        distanceTravelled = 0
        lateralVelocity = 0
        isGameOver = false

        setupSnowBackground()
        setupSkier()
        setupSnowEmitter()
        setupHUD()
        lastUpdateTime = 0
        treeSpawnAccumulator = 0
    }

    private func startMotionUpdates() {
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.accelerometerUpdateInterval = 1.0 / 60.0

        if motionManager.isDeviceMotionAvailable {
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
                guard let self, let motion else { return }
                self.lateralTilt = self.clampedTilt(self.lateralTilt(from: motion))
            }
        } else if motionManager.isAccelerometerAvailable {
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] accelerometer, _ in
                guard let self, let accelerometer else { return }
                self.lateralTilt = self.clampedTilt(self.lateralTilt(from: accelerometer.acceleration))
            }
        }
    }

    private func setupSnowBackground() {
        let pageHeight = size.height + 64

        for index in 0..<3 {
            let page = makeSnowPage(height: pageHeight)
            page.position = CGPoint(x: 0, y: CGFloat(index) * pageHeight - 64)
            backgroundLayer.addChild(page)
            snowPages.append(page)
        }
    }

    private func makeSnowPage(height: CGFloat) -> SKNode {
        let page = SKNode()
        let tileDisplaySize = CGSize(width: 48, height: 48)
        let columns = Int(ceil(size.width / tileDisplaySize.width)) + 2
        let rows = Int(ceil(height / tileDisplaySize.height)) + 2

        for row in 0..<rows {
            for column in 0..<columns {
                let texture = snowTextures.randomElement()
                let tile = SKSpriteNode(texture: texture)
                tile.size = tileDisplaySize
                tile.anchorPoint = CGPoint(x: 0, y: 0)
                tile.position = CGPoint(
                    x: CGFloat(column) * tileDisplaySize.width - tileDisplaySize.width,
                    y: CGFloat(row) * tileDisplaySize.height
                )
                tile.alpha = CGFloat.random(in: 0.55...0.9)
                page.addChild(tile)
            }
        }

        return page
    }

    private func scrollSnow(by distance: CGFloat) {
        for page in snowPages {
            page.position.y -= distance
        }

        guard let lowestPage = snowPages.min(by: { $0.position.y < $1.position.y }),
              let highestPage = snowPages.max(by: { $0.position.y < $1.position.y }) else {
            return
        }

        let pageHeight = size.height + 64
        if lowestPage.position.y <= -pageHeight {
            lowestPage.position.y = highestPage.position.y + pageHeight
        }
    }

    private func setupSkier() {
        let skier = SKNode()
        skier.position = CGPoint(x: size.width * 0.5, y: skierVerticalPosition)

        if let skierTexture = texture(forTileID: 84) {
            let sprite = SKSpriteNode(texture: skierTexture)
            sprite.size = CGSize(width: 48, height: 48)
            sprite.texture?.filteringMode = .nearest
            skier.addChild(sprite)
        } else {
            addProceduralSkier(to: skier)
        }

        skierLayer.addChild(skier)
        skierNode = skier
    }

    private func updateSkier(deltaTime: CGFloat) {
        guard let skierNode else { return }

        let deadZone: CGFloat = 0.04
        let effectiveTilt = abs(lateralTilt) < deadZone ? 0 : lateralTilt
        let targetVelocity = effectiveTilt * maxLateralSpeed
        lateralVelocity += (targetVelocity - lateralVelocity) * min(1, deltaTime * 8)

        let halfSkierWidth: CGFloat = 24
        let minX = halfSkierWidth
        let maxX = max(minX, size.width - halfSkierWidth)
        let nextX = min(max(skierNode.position.x + lateralVelocity * deltaTime, minX), maxX)
        skierNode.position.x = nextX
        skierNode.position.y = skierVerticalPosition
        skierNode.zRotation = -effectiveTilt * 0.28
    }

    private func addProceduralSkier(to node: SKNode) {
        let leftSki = SKShapeNode(rectOf: CGSize(width: 8, height: 56), cornerRadius: 4)
        leftSki.fillColor = .darkGray
        leftSki.strokeColor = .clear
        leftSki.position = CGPoint(x: -10, y: -6)
        leftSki.zRotation = -0.12

        let rightSki = SKShapeNode(rectOf: CGSize(width: 8, height: 56), cornerRadius: 4)
        rightSki.fillColor = .darkGray
        rightSki.strokeColor = .clear
        rightSki.position = CGPoint(x: 10, y: -6)
        rightSki.zRotation = 0.12

        let body = SKShapeNode(circleOfRadius: 15)
        body.fillColor = SKColor(red: 0.92, green: 0.18, blue: 0.22, alpha: 1)
        body.strokeColor = .white
        body.lineWidth = 2
        body.position = CGPoint(x: 0, y: 4)

        node.addChild(leftSki)
        node.addChild(rightSki)
        node.addChild(body)
    }

    private func setupSnowEmitter() {
        snowEmitter?.removeFromParent()

        let emitter = SKEmitterNode()
        emitter.particleTexture = makeSnowflakeTexture()
        emitter.particleBirthRate = 120
        emitter.particleLifetime = 6
        emitter.particleLifetimeRange = 2
        emitter.particlePosition = CGPoint(x: size.width * 0.5, y: size.height + 20)
        emitter.particlePositionRange = CGVector(dx: size.width, dy: 24)
        emitter.emissionAngle = -.pi / 2
        emitter.emissionAngleRange = .pi / 8
        emitter.particleSpeed = 115
        emitter.particleSpeedRange = 65
        emitter.particleAlpha = 0.9
        emitter.particleAlphaRange = 0.3
        emitter.particleAlphaSpeed = -0.08
        emitter.particleScale = 0.08
        emitter.particleScaleRange = 0.06
        emitter.zPosition = 30
        emitter.advanceSimulationTime(3)

        addChild(emitter)
        snowEmitter = emitter
    }

    private func spawnTreesIfNeeded(deltaTime: TimeInterval) {
        treeSpawnAccumulator += deltaTime

        while treeSpawnAccumulator >= treeSpawnInterval {
            treeSpawnAccumulator -= treeSpawnInterval
            spawnTree()
        }
    }

    private func spawnTree() {
        guard let texture = treeTextures.randomElement() else { return }

        let tree = SKSpriteNode(texture: texture)
        tree.texture?.filteringMode = .nearest
        let scale = CGFloat.random(in: 2.8...4.1)
        tree.size = CGSize(width: TileSheet.tileSize.width * scale, height: TileSheet.tileSize.height * scale)
        let horizontalMargin = max(32, tree.size.width * 0.5)
        tree.position = CGPoint(
            x: CGFloat.random(in: horizontalMargin...max(horizontalMargin, size.width - horizontalMargin)),
            y: size.height + tree.size.height
        )
        tree.zPosition = 10

        obstacleLayer.addChild(tree)
        treeNodes.append(tree)
    }

    private func scrollTrees(by distance: CGFloat) {
        treeNodes.removeAll { tree in
            tree.position.y -= distance

            if tree.position.y < -80 {
                tree.removeFromParent()
                return true
            }

            return false
        }
    }

    private func checkTreeCollisions() {
        guard let skierNode else { return }

        let skierFrame = skierNode.calculateAccumulatedFrame().insetBy(dx: 14, dy: 10)
        let hitTree = treeNodes.contains { tree in
            tree.calculateAccumulatedFrame().insetBy(dx: 14, dy: 12).intersects(skierFrame)
        }

        if hitTree {
            endRun()
        }
    }

    private func endRun() {
        guard !isGameOver else { return }

        isGameOver = true
        lateralVelocity = 0
        skierNode?.run(.sequence([
            .rotate(byAngle: 0.45, duration: 0.12),
            .rotate(byAngle: -0.9, duration: 0.2),
            .rotate(byAngle: 0.45, duration: 0.12)
        ]))

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "Crash! Tap to ski again"
        label.fontSize = 24
        label.fontColor = .black
        label.position = CGPoint(x: size.width * 0.5, y: size.height * 0.62)
        label.zPosition = 1
        hudLayer.addChild(label)
        gameOverLabel = label
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isGameOver {
            rebuildSceneForCurrentSize()
        }
    }

    private func setupHUD() {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.fontSize = 20
        label.fontColor = .black
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .top
        label.position = CGPoint(x: 16, y: size.height - 24)
        hudLayer.addChild(label)
        distanceLabel = label
        updateDistanceLabel()
    }

    private func updateDistanceLabel() {
        distanceLabel?.text = "Distance \(Int(distanceTravelled / 10)) m"
    }

    private func clampedTilt(_ tilt: CGFloat) -> CGFloat {
        min(max(tilt, -0.75), 0.75) / 0.75
    }

    private func lateralTilt(from motion: CMDeviceMotion) -> CGFloat {
        lateralTilt(x: motion.gravity.x, y: motion.gravity.y)
    }

    private func lateralTilt(from acceleration: CMAcceleration) -> CGFloat {
        lateralTilt(x: acceleration.x, y: acceleration.y)
    }

    private func lateralTilt(x: Double, y: Double) -> CGFloat {
        switch currentInterfaceOrientation {
        case .landscapeLeft:
            return CGFloat(y)
        case .landscapeRight:
            return CGFloat(-y)
        case .portraitUpsideDown:
            return CGFloat(-x)
        default:
            return CGFloat(x)
        }
    }

    private var currentInterfaceOrientation: UIInterfaceOrientation {
        view?.window?.windowScene?.effectiveGeometry.interfaceOrientation ?? .landscapeRight
    }

    private func textures(for tileIDs: [Int]) -> [SKTexture] {
        tileIDs.compactMap { texture(forTileID: $0) }
    }

    private func texture(forTileID tileID: Int) -> SKTexture? {
        guard tileID > 0 else { return nil }

        let index = tileID - 1
        let column = index % TileSheet.columns
        let row = index / TileSheet.columns
        guard row < TileSheet.rows else { return nil }

        let sheetSize = CGSize(
            width: CGFloat(TileSheet.columns) * TileSheet.tileSize.width + CGFloat(TileSheet.columns - 1) * TileSheet.spacing,
            height: CGFloat(TileSheet.rows) * TileSheet.tileSize.height + CGFloat(TileSheet.rows - 1) * TileSheet.spacing
        )
        let pixelX = CGFloat(column) * (TileSheet.tileSize.width + TileSheet.spacing)
        let pixelY = CGFloat(row) * (TileSheet.tileSize.height + TileSheet.spacing)

        let rect = CGRect(
            x: pixelX / sheetSize.width,
            y: 1 - ((pixelY + TileSheet.tileSize.height) / sheetSize.height),
            width: TileSheet.tileSize.width / sheetSize.width,
            height: TileSheet.tileSize.height / sheetSize.height
        )

        let texture = SKTexture(rect: rect, in: tileSheetTexture)
        texture.filteringMode = .nearest
        return texture
    }

    private func makeSnowflakeTexture() -> SKTexture {
        let size = CGSize(width: 12, height: 12)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.withAlphaComponent(0.95).setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }

        return SKTexture(image: image)
    }
}
