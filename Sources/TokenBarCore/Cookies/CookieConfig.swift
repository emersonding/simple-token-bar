public struct CookieConfig: Codable, Sendable {
    public var enableChrome: Bool = true
    public var enableSafari: Bool = false   // requires Full Disk Access
    public var enableFirefox: Bool = false

    public init(enableChrome: Bool = true, enableSafari: Bool = false, enableFirefox: Bool = false) {
        self.enableChrome = enableChrome
        self.enableSafari = enableSafari
        self.enableFirefox = enableFirefox
    }
}
