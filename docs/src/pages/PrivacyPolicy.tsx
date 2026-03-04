import { Navbar } from "../components/Navbar";
import { Footer } from "../components/Footer";

export const PrivacyPolicy = () => {
    return (
        <div className="min-h-screen bg-background text-foreground flex flex-col">
            <Navbar />
            <main className="flex-1 max-w-3xl mx-auto px-6 py-20">
                <h1 className="text-4xl font-bold mb-2">Privacy Policy</h1>
                <p className="text-muted-foreground mb-10">
                    Last updated: March 4, 2026
                </p>

                <div className="space-y-8 text-muted-foreground leading-relaxed">
                    <section>
                        <h2 className="text-xl font-semibold text-foreground mb-3">
                            Overview
                        </h2>
                        <p>
                            Chowser is a macOS utility that intercepts browser
                            links and routes them to your configured browsers.
                            Your privacy is important to us. This policy explains
                            what data Chowser handles and how.
                        </p>
                    </section>

                    <section>
                        <h2 className="text-xl font-semibold text-foreground mb-3">
                            Data Collection
                        </h2>
                        <p>
                            <strong className="text-foreground">
                                Chowser does not collect, transmit, or store any
                                personal data.
                            </strong>{" "}
                            All information stays on your Mac.
                        </p>
                    </section>

                    <section>
                        <h2 className="text-xl font-semibold text-foreground mb-3">
                            Data Stored Locally
                        </h2>
                        <p className="mb-3">
                            Chowser stores the following data locally on your
                            device using macOS UserDefaults:
                        </p>
                        <ul className="list-disc list-inside space-y-2 ml-2">
                            <li>
                                Your browser configurations (which browsers to
                                show, display names, profiles)
                            </li>
                            <li>
                                Routing rules you create (domain patterns,
                                browser assignments)
                            </li>
                            <li>
                                Domain click frequency counts (used for
                                suggesting routing rules)
                            </li>
                            <li>
                                App preferences (window position, update
                                settings)
                            </li>
                        </ul>
                        <p className="mt-3">
                            This data never leaves your device and is not
                            accessible to us or any third party.
                        </p>
                    </section>

                    <section>
                        <h2 className="text-xl font-semibold text-foreground mb-3">
                            Network Access
                        </h2>
                        <p>
                            Chowser makes network requests only to check for app
                            updates via the App Store. No user data is transmitted
                            during update checks.
                        </p>
                    </section>

                    <section>
                        <h2 className="text-xl font-semibold text-foreground mb-3">
                            Third-Party Services
                        </h2>
                        <p>Chowser does not integrate with any third-party analytics, tracking, or advertising services.</p>
                    </section>

                    <section>
                        <h2 className="text-xl font-semibold text-foreground mb-3">
                            Children's Privacy
                        </h2>
                        <p>
                            Chowser does not collect any data from anyone,
                            including children under 13.
                        </p>
                    </section>

                    <section>
                        <h2 className="text-xl font-semibold text-foreground mb-3">
                            Changes to This Policy
                        </h2>
                        <p>
                            We may update this privacy policy from time to time.
                            Changes will be posted on this page with an updated
                            date.
                        </p>
                    </section>

                    <section>
                        <h2 className="text-xl font-semibold text-foreground mb-3">
                            Contact
                        </h2>
                        <p>
                            If you have questions about this privacy policy,
                            please open an issue on our{" "}
                            <a
                                href="https://github.com/bsreeram08/chowser"
                                className="text-foreground underline underline-offset-4 hover:text-primary transition-colors"
                            >
                                GitHub repository
                            </a>
                            .
                        </p>
                    </section>
                </div>
            </main>
            <Footer />
        </div>
    );
};
