import { useEffect, useState } from "react";
import { api } from "./lib/ipc";
import { useDictationState } from "./lib/useVoxly";
import { HistoryPage } from "./pages/HistoryPage";
import { ModelsPage } from "./pages/ModelsPage";
import { SettingsPage } from "./pages/SettingsPage";
import { AboutPage } from "./pages/AboutPage";
import { OnboardingPage } from "./pages/OnboardingPage";
import { Sidebar, type Section } from "./components/Sidebar";
import { StatusBar } from "./components/StatusBar";
import "./styles/app.css";

export function App() {
  const [section, setSection] = useState<Section>("history");
  const [onboarding, setOnboarding] = useState(false);
  const dictation = useDictationState();

  useEffect(() => {
    api.getSettings().then((s) => setOnboarding(!s.hasCompletedOnboarding)).catch(() => {});
  }, []);

  if (onboarding) {
    return <OnboardingPage onDone={() => setOnboarding(false)} />;
  }

  return (
    <div className="shell">
      <Sidebar section={section} onSelect={setSection} dictation={dictation} />
      <main className="content">
        <div className="page">
          {section === "history" && <HistoryPage dictation={dictation} />}
          {section === "models" && <ModelsPage />}
          {section === "settings" && <SettingsPage dictation={dictation} />}
          {section === "about" && <AboutPage dictation={dictation} />}
        </div>
        <StatusBar dictation={dictation} />
      </main>
    </div>
  );
}
