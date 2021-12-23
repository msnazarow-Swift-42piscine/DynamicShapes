//
//  ViewController.swift
//  DynamicShapes
//
//  Created by out-nazarov2-ms on 28.09.2021.
//

import UIKit
import CoreMotion
import CoreHaptics
import AudioToolbox

class ViewController: UIViewController {
    // MARK: - Constants


    private lazy var animator = UIDynamicAnimator(referenceView: view)

    // MARK: - Behaviors
    private lazy var behaviors: [DynamicShapeBehavior] = [gravity, collision, elacticity]
    private let gravity: UIGravityBehavior = {
        let gravity = UIGravityBehavior()
        return gravity
    }()
    private lazy var collision: UICollisionBehavior = {
        let collision = UICollisionBehavior()
        collision.translatesReferenceBoundsIntoBoundary = true
        collision.collisionDelegate = self
        return collision
    }()
    private let elacticity: UIDynamicItemBehavior = {
        let dynamic = UIDynamicItemBehavior()
        dynamic.elasticity = 1
        dynamic.resistance = 0
        dynamic.density = 2
        return dynamic
    }()
    private let density: UIDynamicItemBehavior = {
        let dynamic = UIDynamicItemBehavior()
        dynamic.density = 2
        return dynamic
    }()

    // MARK: - Animated
    var animated = false {
        didSet {
            if animated {
                behaviors.forEach { animator.addBehavior($0) }
            } else {
                behaviors.forEach { animator.removeBehavior($0) }
            }
        }
    }
    lazy var supportsHaptics: Bool = {
        return (UIApplication.shared.delegate as? AppDelegate)?.supportsHaptics ?? false
    }()

    // MARK: - Managers
    private var motionManager = CMMotionManager()
    private var motionQueue = OperationQueue()
    private var engine = try? CHHapticEngine()
    private let generator = UIImpactFeedbackGenerator(style: .heavy)

    // MARK: - Properties
    private var engineNeedsStart = true
    private let kMaxVelocity: Float = 500
    private let itemsHeight: CGFloat = 100
    private let itemsWight: CGFloat = 100

    // MARK: - Views
    let label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .gray
        label.text = "Animated 2.0"
        return label
    }()
    let animateSwitch: UISwitch = {
        let animateSwitch = UISwitch()
        animateSwitch.setOn(true, animated: true)
        animateSwitch.translatesAutoresizingMaskIntoConstraints = false
        animateSwitch.addTarget(self, action: #selector(switchAnimation), for: .valueChanged)
        return animateSwitch
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(label)
        view.addSubview(animateSwitch)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            label.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            animateSwitch.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            animateSwitch.topAnchor.constraint(equalTo: label.bottomAnchor)
        ])
        view.backgroundColor = .white
        createAndStartHapticEngine()
        activateAccelerometer()
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapGestureRecognized)))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.animated = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.animated = false
    }

    // MARK: - Actions
    @objc func switchAnimation(_ sender: UISwitch) {
        animated = sender.isOn
    }

    @objc func tapGestureRecognized(_ recognizer: UITapGestureRecognizer) {
        let x = recognizer.location(in: view).x
        let y = recognizer.location(in: view).y
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panGestureRecognized))
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinchGestureRecognizer))
        let rotate = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation))
        let long = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        guard let shape = ShapeView.Shape(rawValue: .random(in: 0 ..< ShapeView.Shape.allCases.count)) else { return }
        let shapeView = ShapeView(
            shape: shape,
            frame: CGRect(origin: CGPoint(x: x - 0.5 * itemsWight, y: y - 0.5 * itemsHeight), size: CGSize( width: itemsHeight, height: itemsWight)),
            color: UIColor(int: .random(in: 1000...100000000)))
        view.addSubview(shapeView)
        [pan, pinch, rotate] .forEach {
            shapeView.addGestureRecognizer($0)
            $0.delegate = self
        }
        shapeView.addGestureRecognizer(long)
        ([gravity, collision] as [DynamicShapeBehavior]).forEach { $0.addItem(shapeView) }
        if shape == .ellipse {
            elacticity.addItem(shapeView)
        } else {
            density.addItem(shapeView)
        }
    }

    @objc func panGestureRecognized(_ recognizer: UIPanGestureRecognizer) {
        guard let recognizerView = recognizer.view as? ShapeView, let superview = recognizerView.superview else { return }
        let translation = recognizer.translation(in: superview)
        switch recognizer.state {
        case .began:
            gravity.removeItem(recognizerView)
        case .changed:
            recognizerView.shape == .ellipse ? elacticity.removeItem(recognizerView) : density.removeItem(recognizerView)
            collision.removeItem(recognizerView)
            recognizerView.center = CGPoint(x: recognizerView.center.x + translation.x, y: recognizerView.center.y + translation.y)
            recognizer.setTranslation(.zero, in: superview)
            animator.updateItem(usingCurrentState: recognizerView)
            recognizerView.shape == .ellipse ? elacticity.addItem(recognizerView) : density.addItem(recognizerView)
            collision.addItem(recognizerView)
        case .ended:
            gravity.addItem(recognizerView)
        default:
            break
        }
    }

    @objc func pinchGestureRecognizer(_ recognizer: UIPinchGestureRecognizer) {
        guard let recognizerView = recognizer.view as? ShapeView, let superview = recognizerView.superview else { return }
        switch recognizer.state {
        case .began:
            self.gravity.removeItem(recognizerView)
        case .changed:
            recognizerView.shape == .ellipse ? elacticity.removeItem(recognizerView) : density.removeItem(recognizerView)
            collision.removeItem(recognizerView)
            let newWidth = recognizerView.layer.bounds.size.width * recognizer.scale
            let newHeigh = recognizerView.layer.bounds.size.height * recognizer.scale
            if newWidth < superview.bounds.width - 50 && newHeigh < superview.bounds.height - 50 && newWidth > 10 && newHeigh > 10 {
                recognizerView.layer.bounds.size.width = newWidth
                recognizerView.layer.bounds.size.height = newHeigh
                recognizer.scale = 1
            }
            recognizerView.shape == .ellipse ? elacticity.addItem(recognizerView) : density.addItem(recognizerView)
            collision.addItem(recognizerView)
        case .ended:
            self.gravity.addItem(recognizerView)
        default:
            break
        }
    }

    @objc func handleRotation(recognizer: UIRotationGestureRecognizer) {
        guard let recognizerView = recognizer.view as? ShapeView else { return }
        switch recognizer.state {
        case .began:
            gravity.removeItem(recognizerView)
        case .changed:
            recognizerView.shape == .ellipse ? elacticity.removeItem(recognizerView) : density.removeItem(recognizerView)
            collision.removeItem(recognizerView)
            recognizerView.transform = recognizerView.transform.rotated(by: recognizer.rotation)
            recognizer.rotation = 0
            animator.updateItem(usingCurrentState: recognizerView)
            recognizerView.shape == .ellipse ? elacticity.addItem(recognizerView) : density.addItem(recognizerView)
            collision.addItem(recognizerView)
        case .ended:
            gravity.addItem(recognizerView)
        default:
            break
        }
    }

    @objc func handleLongPress(recognizer: UILongPressGestureRecognizer) {
        guard let recognizerView = recognizer.view as? ShapeView, let superview = recognizerView.superview else { return }
        behaviors.forEach { $0.removeItem(recognizerView) }
        recognizerView.center = recognizer.location(in: superview)
        generator.impactOccurred()

        UIView.animate(withDuration: 0.2, animations: { recognizerView.alpha = 0.0 }) { _ in
            recognizerView.removeFromSuperview()
        }
    }
}
extension ViewController: UICollisionBehaviorDelegate {
    private func createAndStartHapticEngine() {
        guard supportsHaptics, let engine = engine else { return }
        do {
            try engine.start()
        } catch let error {
            fatalError("Engine Creation Error: \(error)")
        }
    }

    private func activateAccelerometer() {
        motionManager.startDeviceMotionUpdates(to: motionQueue) { deviceMotion, _ in
            guard let motion = deviceMotion else { return }
            let gravity = motion.gravity
            // Dispatch gravity updates to main queue, since they affect UI.
            DispatchQueue.main.async {
                self.gravity.gravityDirection = CGVector(dx: gravity.x * 5, dy: -gravity.y * 5)
            }
        }
    }

    func collisionBehavior(_ behavior: UICollisionBehavior, beganContactFor item1: UIDynamicItem, with item2: UIDynamicItem, at point: CGPoint) {
        guard let engine = engine else { return }
        do {
            // Start the engine if necessary.
            if engineNeedsStart {
                try engine.start()
                engineNeedsStart = false
            }

            // Map the bounce velocity to intensity & sharpness.
            let velocity = self.elacticity.linearVelocity(for: item1)
            let xVelocity = Float(velocity.x)
            let yVelocity = Float(velocity.y)

            // Normalize magnitude to map one number to haptic parameters:
            let magnitude = sqrtf(xVelocity * xVelocity + yVelocity * yVelocity)
            let normalizedMagnitude = min(max(Float(magnitude) / kMaxVelocity, 0.0), 1.0)

            // Create a haptic pattern player from normalized magnitude.
            let hapticPlayer = try playerForMagnitude(normalizedMagnitude)

            // Start player, fire and forget
            try hapticPlayer?.start(atTime: CHHapticTimeImmediate)
        } catch let error {
            print("Haptic Playback Error: \(error)")
        }
    }

    func collisionBehavior(
        _ behavior: UICollisionBehavior,
        beganContactFor item: UIDynamicItem,
        withBoundaryIdentifier identifier: NSCopying?,
        at point: CGPoint
    ) {
        // Play collision haptic for supported devices.
        guard supportsHaptics, let engine = engine else { return }

        // Play haptic here.
        do {
            if engineNeedsStart {
                try engine.start()
                engineNeedsStart = false
            }

            // Map the bounce velocity to intensity & sharpness.
            let velocity = self.elacticity.linearVelocity(for: item)
            let xVelocity = Float(velocity.x)
            let yVelocity = Float(velocity.y)

            // Normalize magnitude to map one number to haptic parameters:
            let magnitude = sqrtf(xVelocity * xVelocity + yVelocity * yVelocity)
            let normalizedMagnitude = min(max(Float(magnitude) / kMaxVelocity, 0.0), 1.0)

            // Create a haptic pattern player from normalized magnitude.
            let hapticPlayer = try playerForMagnitude(normalizedMagnitude)

            // Start player, fire and forget
            try hapticPlayer?.start(atTime: CHHapticTimeImmediate)
        } catch let error {
            print("Haptic Playback Error: \(error)")
        }
    }

    private func playerForMagnitude(_ magnitude: Float) throws -> CHHapticPatternPlayer? {
        let volume = linearInterpolation(alpha: magnitude, min: 0.1, max: 0.4)
        let decay: Float = linearInterpolation(alpha: magnitude, min: 0.0, max: 0.1)
        let audioEvent = CHHapticEvent(eventType: .audioContinuous, parameters: [
            CHHapticEventParameter(parameterID: .audioPitch, value: -0.15),
            CHHapticEventParameter(parameterID: .audioVolume, value: volume),
            CHHapticEventParameter(parameterID: .decayTime, value: decay),
            CHHapticEventParameter(parameterID: .sustained, value: 0)
        ], relativeTime: 0)

        let sharpness = linearInterpolation(alpha: magnitude, min: 0.9, max: 0.5)
        let intensity = linearInterpolation(alpha: magnitude, min: 0.375, max: 1.0)
        let hapticEvent = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        ], relativeTime: 0)

        let pattern = try CHHapticPattern(events: [audioEvent, hapticEvent], parameters: [])
        return try engine?.makePlayer(with: pattern)
    }

    private func linearInterpolation(alpha: Float, min: Float, max: Float) -> Float {
        return min + alpha * (max - min)
    }
}

extension ViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer is UILongPressGestureRecognizer || otherGestureRecognizer is UILongPressGestureRecognizer {
            return false
        } else {
            return true
        }
    }
}
