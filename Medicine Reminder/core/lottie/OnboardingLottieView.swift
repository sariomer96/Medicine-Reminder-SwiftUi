//
//  OnboardingLottieView.swift
//  Medicine Reminder
//

import SwiftUI
 
import Lottie

struct OnboardingLottieView: UIViewRepresentable {
    let animationName: String

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView(frame: .zero)
        let animationView = LottieAnimationView(name: animationName)

        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .playOnce
        animationView.play()

        containerView.addSubview(animationView)

        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: containerView.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

 
