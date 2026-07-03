import { BrowserRouter, Routes, Route } from "react-router-dom";
import { Toaster } from "sonner";
import { AppIcon } from "./pages/AppIcon";
import { PrivacyPolicy } from "./pages/PrivacyPolicy";
import { Home } from "./pages/Home";

export function App() {
    return (
        <BrowserRouter>
            <Toaster position="bottom-right" richColors theme="light" />
            <Routes>
                <Route path="/" element={<Home />} />
                <Route path="/privacy" element={<PrivacyPolicy />} />
                <Route path="/lab/designer" element={<AppIcon />} />
            </Routes>
        </BrowserRouter>
    );
}

export default App;