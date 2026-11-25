// Intentionally empty. The app's code is the SwiftPM package's Tippy
// library (Sources/Tippy), whose @main is the entry point; this target
// only exists so xcodebuild can wrap it in an .app for the simulator UI
// smoke test. A C file rather than Swift so the target emits no Swift module
// that could clash with the package's Tippy module. See UISmoke/project.yml.
