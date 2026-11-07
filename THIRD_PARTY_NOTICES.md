# Third-party notices

## SayAll / 无线麦 — design and behavior reference

- Project: https://github.com/HD838A/remote-mic-app
- Reviewed revision: `85a9148ef751fb0ba962ceda9ea584c54f56331a`.
- Upstream software license: **GPL-3.0-only**.
- JoyPilot implements a new Joy-Con-specific application. Its visual mapping canvas, action categories, hold/repeat lifecycle, application focus strategies and voice-tool capability separation were informed by SayAll's public code and documentation.
- SayAll's application, brand assets, private packages, membership capabilities, audio drivers and installed user configuration are not bundled here. This reference is not an endorsement or affiliation.
- The small system-media key event formatter in `EventEmitter.swift` is adapted from the public `KeyboardInjector.swift` event format and is distributed under GPL-3.0-only with acknowledgement to HD838A / SayAll contributors.
- JoyPilot's original application and core code are distributed under GPL-3.0-only; see `LICENSE`.

## JoyConSwift — vendored hardware communication

- https://github.com/magicien/JoyConSwift
- Copyright (c) 2019 magicien / DarkHorse, **MIT**. Full notice: `ThirdParty/JoyConSwift-LICENSE` and the adjacent vendored `LICENSE`.
- The source was taken from the MIT-licensed vendored copy maintained by Berrry Joyful (https://github.com/Berrry-Computer/berrry-joyful). Berrry's notice is retained in `ThirdParty/Berrry-Joyful-LICENSE`.
- That copy includes safe unaligned byte reads and initialization/calibration reliability changes. JoyPilot further limits HID matching to the right Joy-Con and disables upstream logs containing device identifiers. No other Berrry Joyful application UI or speech-recognition runtime is included.

Nintendo, DJI, Apple and the voice tool names are used to describe interoperability. JoyPilot is an independent project.
