import { useEffect } from "react";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import { Toaster } from "sonner";
import { Home } from "./pages/Home";
import { PrivacyPolicy } from "./pages/PrivacyPolicy";

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
            </Routes>
        </BrowserRouter>
    );
}

export default App;