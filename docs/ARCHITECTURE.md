# Implementation notes

JoyPilot is a new application with its own bundle ID and settings domain. SayAll's public design and failure handling informed the implementation, but its membership packages, assets, services and user configuration are not dependencies.

## Input ownership

The HID manager matches only the right Joy-Con. All hardware callbacks capture a sample before dispatching to the main actor. The input router captures an immutable binding at press time, counts shared held actions, ignores duplicate edges, and clears deferred gestures on cancellation. R is a held combination layer; it does not generate an OS modifier key. ZR voice takes priority and ends active drag/gyro actions before forwarding the chosen speech-tool hotkey.

## Movement

Joystick motion is integrated using elapsed wall time. Gyro samples use the controller's three-sample packet stream, calibrated angular velocity, stationary zero-bias, exponential smoothing and a small noise deadzone. Only one of joystick and gyro drives the pointer at a time. Screen bounds use active CG display coordinates, including negative coordinates.

Scroll accumulates fractional pixels per axis, emits whole pixel wheel events, and retains the remainder. Stopping, reversal or context cancellation removes stale remainder. No per-frame rounding discards low-speed input.

## Focus

Explicit per-app shortcut takes priority over a learned accessibility target, followed by bounded generic discovery. Learning stores role, identifier, placeholder, ancestor structure and normalized frame, never field text values. Restoring focus requires the expected app to remain frontmost and validates the actual focused control after the request. Secure fields and identifiable browser address bars are excluded. Matching is best effort and requires application-specific verification.

## Voice

The bridge forwards key edges or balanced tap sequences. Hold, toggle and tap-on-both-edges modes differ. It does not record audio or use a transcription API. Installation detection is advisory. Microphone selection and the actual voice shortcut belong to the external tool.

## Source reference

Reviewed SayAll revision: `85a9148ef751fb0ba962ceda9ea584c54f56331a`; important references are RemoteMappingCanvas.swift, RemoteButtonInteraction.swift, KeyboardInjector.swift, ShortcutEventSequence.swift and VoiceInputCapabilityMatrix.swift. See THIRD_PARTY_NOTICES.md for licensing and provenance.
