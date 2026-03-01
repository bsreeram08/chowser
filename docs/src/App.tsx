import { useEffect } from "react";
import { Toaster } from "sonner";
import { Home } from "./pages/Home";

export function App() {
    useEffect(() => {
        document.documentElement.classList.add("dark");
    }, []);

    return (
        <>
            <Toaster position="bottom-right" richColors theme="dark" />
            <Home />
        </>
    );
}

export default App;