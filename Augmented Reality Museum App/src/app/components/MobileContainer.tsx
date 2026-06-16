import { Outlet, useLocation, useNavigate } from "react-router";
import { Camera, Map, Library, User } from "lucide-react";
import { motion } from "motion/react";

export function MobileContainer() {
  return (
    <div className="flex items-center justify-center min-h-screen bg-zinc-950 p-0 sm:p-8 w-full">
      <div className="relative w-full h-[100dvh] sm:h-[844px] sm:w-[390px] sm:rounded-[40px] sm:shadow-2xl sm:overflow-hidden bg-black flex flex-col border sm:border-zinc-800">
        <main className="flex-1 relative overflow-hidden">
          <Outlet />
        </main>
        <BottomNav />
      </div>
    </div>
  );
}

function BottomNav() {
  const location = useLocation();
  const navigate = useNavigate();

  const navItems = [
    { path: "/", icon: Camera, label: "Explore" },
    { path: "/map", icon: Map, label: "Map" },
    { path: "/collection", icon: Library, label: "Saved" },
    { path: "/profile", icon: User, label: "Profile" },
  ];

  return (
    <div className="absolute bottom-0 w-full bg-black/60 backdrop-blur-xl border-t border-white/10 z-50 px-6 py-4 pb-8 sm:pb-6 flex justify-between items-center">
      {navItems.map((item) => {
        const isActive = location.pathname === item.path;
        const Icon = item.icon;
        
        return (
          <button
            key={item.path}
            onClick={() => navigate(item.path)}
            className={`relative flex flex-col items-center gap-1 p-2 ${
              isActive ? "text-white" : "text-white/50 hover:text-white/80"
            } transition-colors`}
          >
            <Icon className="w-6 h-6" strokeWidth={isActive ? 2.5 : 2} />
            {isActive && (
              <motion.div
                layoutId="nav-indicator"
                className="absolute -bottom-2 w-1.5 h-1.5 rounded-full bg-blue-500"
                transition={{ type: "spring", bounce: 0.2, duration: 0.6 }}
              />
            )}
          </button>
        );
      })}
    </div>
  );
}
