import { BrowserRouter as Router, Routes, Route, useLocation } from "react-router-dom";
import { useEffect } from "react";
import { Toaster } from "sonner";
import { Home } from "./pages/Home";
import { AgenticSetup } from "./pages/AgenticSetup";
import { SecuritySetup } from "./pages/SecuritySetup";
import { Research } from "./pages/Research";

function ScrollToTop() {
    const { pathname } = useLocation();

    useEffect(() => {
        window.scrollTo(0, 0);
    }, [pathname]);

    return null;
}

export function App() {
    useEffect(() => {
        document.documentElement.classList.add("dark");
    }, []);

    return (
        <Router>
            <ScrollToTop />
            <Toaster position="bottom-right" richColors theme="dark" />
            <Routes>
                <Route path="/" element={<Home />} />
                <Route path="/agentic-setup" element={<AgenticSetup />} />
                <Route path="/security-setup" element={<SecuritySetup />} />
                <Route path="/research" element={<Research />} />
            </Routes>
        </Router>
    );
}

export default App;