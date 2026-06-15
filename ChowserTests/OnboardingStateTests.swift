import Testing
import Foundation
@testable import Chowser

struct OnboardingStateTests {
    private func makeTestDefaults() -> UserDefaults {
        let suiteName = "com.chowser.onboarding.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test("First launch defaults to incomplete onboarding")
    func firstLaunchDefaultsIncomplete() {
        let defaults = makeTestDefaults()
        let onboardingManager = OnboardingManager(defaults: defaults)

        #expect(onboardingManager.hasCompletedOnboarding == false)
        #expect(OnboardingManager.hasCompletedOnboarding(in: defaults) == false)
    }

    @Test("Completed onboarding persists through canonical defaults key")
    func completedOnboardingPersists() {
        let defaults = makeTestDefaults()
        let onboardingManager = OnboardingManager(defaults: defaults)

        onboardingManager.hasCompletedOnboarding = true

        let relaunchedOnboardingManager = OnboardingManager(defaults: defaults)
        #expect(relaunchedOnboardingManager.hasCompletedOnboarding == true)
        #expect(defaults.bool(forKey: OnboardingManager.completionDefaultsKey) == true)
    }

    @Test("Reset clears the state used by launch gating")
    func resetClearsLaunchGateState() {
        let defaults = makeTestDefaults()
        let onboardingManager = OnboardingManager(defaults: defaults)
        onboardingManager.hasCompletedOnboarding = true

        onboardingManager.resetOnboarding()

        #expect(onboardingManager.hasCompletedOnboarding == false)
        #expect(defaults.object(forKey: OnboardingManager.completionDefaultsKey) == nil)
    }

    @Test("BrowserManager bridges live canonical onboarding state")
    @MainActor
    func browserManagerBridgesLiveCanonicalOnboardingState() {
        let defaults = makeTestDefaults()
        let onboardingManager = OnboardingManager(defaults: defaults)
        let browserManager = BrowserManager(defaults: defaults)

        onboardingManager.hasCompletedOnboarding = true
        #expect(browserManager.hasCompletedOnboarding == true)

        browserManager.resetToFreshSetup()

        #expect(browserManager.hasCompletedOnboarding == false)
        #expect(onboardingManager.hasCompletedOnboarding == false)

        browserManager.completeOnboarding()

        #expect(browserManager.hasCompletedOnboarding == true)
        #expect(onboardingManager.hasCompletedOnboarding == true)
    }

    @Test("UI test defaults suite is isolated from standard defaults")
    func uiTestDefaultsSuiteIsIsolatedFromStandardDefaults() {
        let uiTestDefaults = UserDefaults(suiteName: AppEnvironment.uiTestDefaultsSuiteName)!
        uiTestDefaults.removePersistentDomain(forName: AppEnvironment.uiTestDefaultsSuiteName)

        let previousStandardValue = UserDefaults.standard.object(forKey: OnboardingManager.completionDefaultsKey)
        defer {
            if let previousStandardValue {
                UserDefaults.standard.set(previousStandardValue, forKey: OnboardingManager.completionDefaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: OnboardingManager.completionDefaultsKey)
            }
            uiTestDefaults.removePersistentDomain(forName: AppEnvironment.uiTestDefaultsSuiteName)
        }

        UserDefaults.standard.set(true, forKey: OnboardingManager.completionDefaultsKey)
        OnboardingManager.setHasCompletedOnboarding(false, in: uiTestDefaults)

        #expect(UserDefaults.standard.bool(forKey: OnboardingManager.completionDefaultsKey) == true)
        #expect(OnboardingManager.hasCompletedOnboarding(in: uiTestDefaults) == false)
    }
}
