import SwiftUI

/// Who a visitor is and what they say: the cinnamon fox on the main trail
/// (spec 03b) and the creatures who live down the side paths (spec 07). They
/// talk about the places and the pet, never about drinking.
struct VisitorProfile {
    /// The sheet's ribbon: "A visitor at dusk".
    let title: String
    /// Their art, when it exists (spec 05).
    let spritePath: String
    /// What VoiceOver hears for the picture.
    let description: String
    /// A stand-in until the art lands.
    let placeholderSymbol: String
    let lines: (_ petName: String) -> [String]

    static func profile(for visitorID: String) -> VisitorProfile {
        switch visitorID {
        case "heron":
            return VisitorProfile(
                title: "A heron in the shallows",
                spritePath: "Wander/visitor-heron",
                description: "A grey heron standing in the water",
                placeholderSymbol: "bird.fill"
            ) { pet in [
                "Hush… the fish are shy this morning. I'm Sable. I've stood in this inlet longer than the reeds have grown.",
                "\(pet) has a light step. Not many find the boardwalk.",
                "There are smooth pebbles further along. Stack a few by your pond and think of the water here.",
            ] }
        case "owl":
            return VisitorProfile(
                title: "An owl in the hollow",
                spritePath: "Wander/visitor-owl",
                description: "A small owl peering out of a hollow willow trunk",
                placeholderSymbol: "moon.stars.fill"
            ) { pet in [
                "Hoo! You've found my willow. I'm Bramble. I keep an eye on the grove at night.",
                "\(pet) circled the old trunk. That's how you say hello to a willow, you know.",
                "Mind the roots on your way back. They like to keep a little something for visitors.",
            ] }
        case "hedgehog":
            return VisitorProfile(
                title: "A hedgehog in the ferns",
                spritePath: "Wander/visitor-hedgehog",
                description: "A round hedgehog with a fern leaf on its back",
                placeholderSymbol: "leaf.fill"
            ) { pet in [
                "Oh! Hello. I'm Thistle. I was looking for beetles, but company is nicer.",
                "The stream down here sings if you sit still. \(pet) sat very still.",
                "If you see mushrooms glowing on your way up, they're saying goodnight.",
            ] }
        case "toad":
            return VisitorProfile(
                title: "A toad with a flute",
                spritePath: "Wander/visitor-toad",
                description: "A plump toad playing a reed flute on a toadstool",
                placeholderSymbol: "music.note"
            ) { pet in [
                "Welcome to the ring! I'm Bellow. I play for the toadstools; they dance when no one's looking.",
                "\(pet) tapped along. Good rhythm, that one.",
                "Sit a while if you like. There's always room in the ring.",
            ] }
        default:
            return VisitorProfile(
                title: "A visitor at dusk",
                spritePath: "Pet/fox-dusk",
                description: "A cinnamon fox sitting by a lantern",
                placeholderSymbol: "pawprint.fill"
            ) { pet in [
                "Evening! I'm Cinnamon. I wander these reeds when the lanterns come on.",
                "I've seen \(pet) hopping about. Your pond is getting cozier by the day.",
                "I'll be off now. Keep wandering: there are paths off the trail with secrets of their own.",
            ] }
        }
    }
}
