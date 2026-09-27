import Foundation

/// Keep typed fragments literal throughout this app, including WebKit, native
/// field editors and auxiliary windows. Install before AppKit/WebKit initialize
/// their cached text-checking state. These are app-domain preferences only.
public enum TextInputPolicy {
    public static func install() {
        for key in [
            "NSAutomaticSpellingCorrectionEnabled",
            "NSAutomaticTextReplacementEnabled",
            "NSAutomaticCapitalizationEnabled",
            "NSAutomaticPeriodSubstitutionEnabled",
            "NSAutomaticQuoteSubstitutionEnabled",
            "NSAutomaticDashSubstitutionEnabled",
            "NSAutomaticTextCompletionEnabled",
            "NSAutomaticInlinePredictionEnabled",
            // WebKit caches its own overrides separately from NSSpellChecker.
            "WebAutomaticSpellingCorrectionEnabled",
            "WebAutomaticTextReplacementEnabled",
            "WebAutomaticQuoteSubstitutionEnabled",
            "WebAutomaticDashSubstitutionEnabled",
        ] {
            UserDefaults.standard.set(false, forKey: key)
        }
    }
}
