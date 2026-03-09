import { useEffect } from "react";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import { Toaster } from "sonner";
import { AppIcon } from "./pages/AppIcon";
import { PrivacyPolicy } from "./pages/PrivacyPolicy";
import { Home } from "./pages/Home";

export function App() {
    useEffect(() => {
        document.documentElement.classList.add("dark");
    }, []);

    return (
        <BrowserRouter>
            <Toaster position="bottom-right" richColors theme="dark" />
            <Routes>
                <Route path="/" element={<Home />} />
                <Route path="/privacy" element={<PrivacyPolicy />} />
                <Route path="/lab/designer" element={<AppIcon />} />
            </Routes>
        </BrowserRouter>
    );
}

export default App;