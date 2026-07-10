import { BrowserRouter, Routes, Route } from "react-router-dom";
import { Toaster } from "sonner";
import { AppIcon } from "./pages/AppIcon";
import { PrivacyPolicy } from "./pages/PrivacyPolicy";
import { Home } from "./pages/Home";
import { Guide } from "./pages/Guide";
import { PickerPrototypes } from "./pages/PickerPrototypes";
import { RewriteCatalog } from "./pages/RewriteCatalog";

export function App() {
    return (
        <BrowserRouter>
            <Toaster position="bottom-right" richColors theme="light" />
            <Routes>
                <Route path="/" element={<Home />} />
                <Route path="/privacy" element={<PrivacyPolicy />} />
                <Route path="/guide" element={<Guide />} />
                <Route path="/rewrites" element={<RewriteCatalog />} />
                <Route path="/lab/designer" element={<AppIcon />} />
                <Route path="/lab/picker-prototypes" element={<PickerPrototypes />} />
            </Routes>
        </BrowserRouter>
    );
}

export default App;
