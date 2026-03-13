import Foundation

enum AptuneBanner {
    private static let reset = "\u{001B}[0m"
    private static let rainbow = [
        "\u{001B}[38;5;214m",
        "\u{001B}[38;5;220m",
        "\u{001B}[38;5;190m",
        "\u{001B}[38;5;118m",
        "\u{001B}[38;5;48m",
        "\u{001B}[38;5;51m",
        "\u{001B}[38;5;39m",
        "\u{001B}[38;5;63m",
        "\u{001B}[38;5;135m",
        "\u{001B}[38;5;201m",
        "\u{001B}[38;5;196m"
    ]

    static let text = {
        [
            " █████╗ ██████╗ ████████╗██╗   ██╗███╗   ██╗███████╗",
            "██╔══██╗██╔══██╗╚══██╔══╝██║   ██║████╗  ██║██╔════╝",
            "███████║██████╔╝   ██║   ██║   ██║██╔██╗ ██║█████╗  ",
            "██╔══██║██╔═══╝    ██║   ██║   ██║██║╚██╗██║██╔══╝  ",
            "██║  ██║██║        ██║   ╚██████╔╝██║ ╚████║███████╗",
            "╚═╝  ╚═╝╚═╝        ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚══════╝",
            "                                                    "
        ]
        .map(colorize)
        .joined(separator: "\n")
    }()

    private static func colorize(_ line: String) -> String {
        let characters = Array(line)
        let visibleCount = max(characters.filter { !$0.isWhitespace }.count, 1)
        var visibleIndex = 0

        return characters.map { character in
            guard !character.isWhitespace else {
                return String(character)
            }

            let colorIndex = Int(Double(visibleIndex) / Double(visibleCount) * Double(rainbow.count - 1))
            let color = rainbow[colorIndex]
            visibleIndex += 1
            return "\(color)\(character)\(reset)"
        }.joined()
    }
}
