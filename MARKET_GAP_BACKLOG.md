# Market Gap Backlog

This backlog captures product gaps that are useful for future discovery but are not release blockers for the current TestFlight reactivation. The current release notes and manual QA checklist live in `TESTFLIGHT_NOTES.md`.

## Current release boundary

Chowser 3.1.5 is a native macOS TestFlight reactivation only. It does not include Electrobun, Windows, Linux, CI upload automation, or a public App Store launch claim. T14 owns manual QA for the signed sandbox build, browser launch behavior, MCP curl checks, onboarding, routing, private clipboard behavior, and Liquid Glass/fallback visuals.

## Post-TestFlight market gaps

Every item below is **Post-TestFlight** and **Out of scope for 3.1.5 TestFlight reactivation**.

| Gap | Release label | Future discovery note |
|-----|---------------|-----------------------|
| Browser extensions | Post-TestFlight, Out of scope for 3.1.5 TestFlight reactivation | Explore whether extensions can improve in-browser handoff, active-tab context, or user education without duplicating the native picker. |
| Rule tester/history | Post-TestFlight, Out of scope for 3.1.5 TestFlight reactivation | Chowser already has a basic native rule tester/simulation view; future discovery is for routing history, richer explanations, and deeper tester workflows. |
| Tracking stripping | Post-TestFlight, Out of scope for 3.1.5 TestFlight reactivation | Explore privacy-focused parameter removal as a product promise only after behavior, exceptions, and user controls are defined. |
| URL rewrites/native app targets | Post-TestFlight, Out of scope for 3.1.5 TestFlight reactivation | Explore URL transform rules and native app launch targets separately from current browser-only TestFlight routing. |
| Short URL expansion | Post-TestFlight, Out of scope for 3.1.5 TestFlight reactivation | Explore network-backed short-link expansion, timeout behavior, and privacy implications before making it a release commitment. |
| Focus/Shortcuts | Post-TestFlight, Out of scope for 3.1.5 TestFlight reactivation | Chowser already has menu-bar Focus Mode for temporary browser routing; future discovery is for Apple Shortcuts automation and deeper Focus integration. |
| Mail/file handlers | Post-TestFlight, Out of scope for 3.1.5 TestFlight reactivation | Explore non-HTTP handlers only after the current HTTP/HTTPS routing release is stable. |

These items should stay out of implementation plans for the 3.1.5 TestFlight reactivation unless the release scope is explicitly reopened.
