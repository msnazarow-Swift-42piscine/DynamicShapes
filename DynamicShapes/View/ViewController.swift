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

class ViewController: UIViewController, UICollisionBehaviorDelegate {

    private lazy var animator = UIDynamicAnimator(referenceView: view)
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
        dynamic.elasticity = 0.9
        return dynamic
    }()

    private let dencity: UIDynamicItemBehavior = {
        let dynamic = UIDynamicItemBehavior()
        dynamic.density = 2
        return dynamic
    }()

    open var animated = false{
        didSet {
            if animated {
                behaviors.forEach{ animator.addBehavior($0) }
            } else {
                behaviors.forEach{ animator.addBehavior($0) }
            }
        }
    }

    let itemsHeight: CGFloat = 100
    let itemsWight: CGFloat = 100

    private var motionManager: CMMotionManager!
    private var motionQueue: OperationQueue!
    private var motionData: CMAccelerometerData!
    private var engine: CHHapticEngine!
    private let generator = UIImpactFeedbackGenerator(style: .heavy)
    private var engineNeedsStart = true
    private var foregroundToken: NSObjectProtocol?
    private var backgroundToken: NSObjectProtocol?
    private let kMaxVelocity: Float = 500



    lazy var supportsHaptics: Bool = {
        return (UIApplication.shared.delegate as? AppDelegate)?.supportsHaptics ?? false
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        createAndStartHapticEngine()
        activateAccelerometer()
        addObservers()
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(makeShape)))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.animated = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.animated = false
    }



    @objc func makeShape(_ recognizer: UITapGestureRecognizer) {
        let x = recognizer.location(in: view).x
        let y = recognizer.location(in: view).y
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        let rotate = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation))
        let long = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))

        let shape = ShapeView(
            shape: ShapeView.Shape(rawValue: .random(in: 0 ..< ShapeView.Shape.allCases.count))!,
            frame: CGRect(origin: CGPoint(x: x - 0.5 * itemsWight, y: y - 0.5 * itemsHeight),size: CGSize( width: itemsHeight, height: itemsWight)),
            color: UIColor(int: .random(in: 1000...100000000)))
        view.addSubview(shape)
        [pan, pinch, rotate] .forEach {
            shape.addGestureRecognizer($0)
            $0.delegate = self
        }
        shape.addGestureRecognizer(long)
        ([gravity,  collision] as [DynamicShapeBehavior]).forEach{ $0.addItem(shape)}
        if shape.shape == .ellipse {
            elacticity.addItem(shape)
        } else {
            dencity.addItem(shape)
        }

    }

    @objc func handlePan(recognizer: UIPanGestureRecognizer){
        guard let recognizerView = recognizer.view as? ShapeView, let superview = recognizerView.superview else { return }
        let translation = recognizer.translation(in: superview)
        switch recognizer.state {
        case .began:
            gravity.removeItem(recognizerView)
        case .changed:
            recognizerView.shape == .ellipse ? elacticity.removeItem(recognizerView) : dencity.removeItem(recognizerView)
            collision.removeItem(recognizerView)
            recognizerView.center = CGPoint(x: recognizerView.center.x + translation.x, y: recognizerView.center.y + translation.y)
            recognizer.setTranslation(.zero, in: superview)
            animator.updateItem(usingCurrentState: recognizerView)
            recognizerView.shape == .ellipse ? elacticity.addItem(recognizerView) : dencity.addItem(recognizerView)
            collision.addItem(recognizerView)
        case .ended:
            gravity.addItem(recognizerView)
        default:
            break
        }

    }


    @objc func handlePinch(recognizer: UIPinchGestureRecognizer) {
        guard let recognizerView = recognizer.view as? ShapeView, let superview = recognizerView.superview else { return }
        switch recognizer.state {
        case .began:
            self.gravity.removeItem(recognizerView)
        case .changed:
            recognizerView.shape == .ellipse ? elacticity.removeItem(recognizerView) : dencity.removeItem(recognizerView)
            collision.removeItem(recognizerView)
             //
            //            recognizerView.transform = recognizerView.transform.scaledBy(x: recognizer.scale, y: recognizer.scale)
            let newWidth = recognizerView.layer.bounds.size.width * recognizer.scale
            let newHeigh = recognizerView.layer.bounds.size.height * recognizer.scale
            if (newWidth < superview.bounds.width - 50 && newHeigh < superview.bounds.height - 50 && newWidth > 10 && newHeigh > 10) {
                //                            recognizerView.bounds = recognizerView.bounds.applying(CGAffineTransform(scaleX: recognizer.scale, y: recognizer.scale))
                recognizerView.layer.bounds.size.width = newWidth
                recognizerView.layer.bounds.size.height = newHeigh
                recognizer.scale = 1
//                animator.updateItem(usingCurrentState: recognizerView)
            }
            recognizerView.shape == .ellipse ? elacticity.addItem(recognizerView) : dencity.addItem(recognizerView)
            collision.addItem(recognizerView)
        case .ended:
            self.gravity.addItem(recognizerView)
        default:
            break
        }

    }

    @objc func handleRotation(recognizer: UIRotationGestureRecognizer){
        guard let recognizerView = recognizer.view as? ShapeView, let _ = recognizerView.superview else { return }
        switch recognizer.state {
        case .began:
            gravity.removeItem(recognizerView)
        case .changed:
            recognizerView.shape == .ellipse ? elacticity.removeItem(recognizerView) : dencity.removeItem(recognizerView)
            collision.removeItem(recognizerView)
            recognizerView.transform = recognizerView.transform.rotated(by: recognizer.rotation)
            recognizer.rotation = 0
            animator.updateItem(usingCurrentState: recognizerView)
            recognizerView.shape == .ellipse ? elacticity.addItem(recognizerView) : dencity.addItem(recognizerView)
            collision.addItem(recognizerView)
        case .ended:
            gravity.addItem(recognizerView)
        default:
            break
        }
    }

    @objc func handleLongPress(recognizer: UILongPressGestureRecognizer) {
        guard let recognizerView = recognizer.view as? ShapeView, let superview = recognizerView.superview else { return }
        behaviors.forEach{ $0.removeItem(recognizerView)}
        recognizerView.center = recognizer.location(in: superview)
        generator.impactOccurred()

        UIView.animate(withDuration: 0.2, animations: {recognizerView.alpha = 0.0},
                       completion: {(value: Bool) in
            recognizerView.removeFromSuperview()
        })
    }

    private func createAndStartHapticEngine() {
        guard supportsHaptics else { return }

        // Create and configure a haptic engine.
        do {
            engine = try CHHapticEngine()
        } catch let error {
            fatalError("Engine Creation Error: \(error)")
        }

        // The stopped handler alerts engine stoppage.
        engine.stoppedHandler = { reason in
            print("Stop Handler: The engine stopped for reason: \(reason.rawValue)")
            switch reason {
            case .audioSessionInterrupt:
                print("Audio session interrupt.")
            case .applicationSuspended:
                print("Application suspended.")
            case .idleTimeout:
                print("Idle timeout.")
            case .notifyWhenFinished:
                print("Finished.")
            case .systemError:
                print("System error.")
            case .engineDestroyed:
                print("Engine destroyed.")
            case .gameControllerDisconnect:
                print("Controller disconnected.")
            @unknown default:
                print("Unknown error")
            }

            // Indicate that the next time the app requires a haptic, the app must call engine.start().
            self.engineNeedsStart = true
        }

        // The reset handler notifies the app that it must reload all its content.
        // If necessary, it recreates all players and restarts the engine in response to a server restart.
        engine.resetHandler = {
            print("The engine reset --> Restarting now!")

            // Tell the rest of the app to start the engine the next time a haptic is necessary.
            self.engineNeedsStart = true
        }

        // Start haptic engine to prepare for use.
        do {
            try engine.start()

            // Indicate that the next time the app requires a haptic, the app doesn't need to call engine.start().
            engineNeedsStart = false
        } catch let error {
            print("The engine failed to start with error: \(error)")
        }
    }

    private func activateAccelerometer() {
        // Manage motion events in a separate queue off the main thread.
        motionQueue = OperationQueue()
        motionManager = CMMotionManager()

        guard let manager = motionManager else { return }

        manager.startDeviceMotionUpdates(to: motionQueue) { deviceMotion, error in
            guard let motion = deviceMotion else { return }

            let gravity = motion.gravity

            // Dispatch gravity updates to main queue, since they affect UI.
            DispatchQueue.main.async {
                self.gravity.gravityDirection = CGVector(dx: gravity.x,
                                                         dy: -gravity.y)
            }
        }
    }

    private func addObservers() {

        backgroundToken = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                                                 object: nil,
                                                                 queue: nil) { [weak self] _ in
            guard let self = self, self.supportsHaptics else { return }

            // Stop the haptic engine.
            self.engine.stop { error in
                if let error = error {
                    print("Haptic Engine Shutdown Error: \(error)")
                    return
                }
                self.engineNeedsStart = true
            }

        }

        foregroundToken = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification,
                                                                 object: nil,
                                                                 queue: nil) { [weak self] _ in
            guard let self = self, self.supportsHaptics else { return }

            // Restart the haptic engine.
            self.engine.start { error in
                if let error = error {
                    print("Haptic Engine Startup Error: \(error)")
                    return
                }
                self.engineNeedsStart = false
            }
        }
    }

    // pragma mark - UICollisionBehaviorDelegate

    /// - Tag: MapVelocity
    func collisionBehavior(_ behavior: UICollisionBehavior,
                           beganContactFor item: UIDynamicItem,
                           withBoundaryIdentifier identifier: NSCopying?,
                           at point: CGPoint) {
        // Play collision haptic for supported devices.
        guard supportsHaptics else { return }

        // Play haptic here.
        do {
            // Start the engine if necessary.
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
        return try engine.makePlayer(with: pattern)
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
