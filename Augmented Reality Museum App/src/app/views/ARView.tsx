import { useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import { Navigation, Scan, MapPin, Sparkles, X, Play, Image as ImageIcon } from "lucide-react";

const AR_BACKGROUND = "https://images.unsplash.com/photo-1617121346253-43ef95179ac9?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxjaXR5JTIwc3RyZWV0JTIwcGxhemElMjBwb3Z8ZW58MXx8fHwxNzgxNTAyNzIxfDA&ixlib=rb-4.1.0&q=80&w=1080";
const OBJECT_IMG = "https://images.unsplash.com/photo-1618005198919-d3d4b5a92ead?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxhYnN0cmFjdCUyMDNkJTIwZmxvYXRpbmclMjBvYmplY3R8ZW58MXx8fHwxNzgxNTAyNzIxfDA&ixlib=rb-4.1.0&q=80&w=1080";
const EXHIBIT_IMG1 = "https://images.unsplash.com/photo-1546012112-142c81b59a42?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxhYmFuZG9uZWQlMjBzdG9yZWZyb250fGVufDF8fHx8MTc4MTUwMjcyMXww&ixlib=rb-4.1.0&q=80&w=1080";
const EXHIBIT_IMG2 = "https://images.unsplash.com/photo-1495379572396-5f27a279ee91?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxoaXN0b3JpYyUyMHRyYWluJTIwc3RhdGlvbiUyMHZpbnRhZ2V8ZW58MXx8fHwxNzgxNTAyNzIxfDA&ixlib=rb-4.1.0&q=80&w=1080";

type Exhibit = {
  id: string;
  title: string;
  type: string;
  distance: string;
  description: string;
  image: string;
  x: number;
  y: number;
};

const MOCK_EXHIBITS: Exhibit[] = [
  {
    id: "ex1",
    title: "The Ghost Station",
    type: "Immersive Narrative",
    distance: "12m",
    description: "Listen to the echoes of the 1924 transit line that used to run exactly where you are standing. Local residents have reconstructed the ambiance.",
    image: EXHIBIT_IMG2,
    x: 30,
    y: 40,
  },
  {
    id: "ex2",
    title: "Lost Corner Store",
    type: "Community Art",
    distance: "5m",
    description: "A virtual gallery of photographs from when this intersection was the neighborhood's bustling marketplace before the 1990s redevelopment.",
    image: EXHIBIT_IMG1,
    x: 65,
    y: 25,
  }
];

export function ARView() {
  const [selectedExhibit, setSelectedExhibit] = useState<Exhibit | null>(null);

  return (
    <div className="relative w-full h-full bg-zinc-900 text-white overflow-hidden">
      {/* Simulated Camera Feed */}
      <div 
        className="absolute inset-0 bg-cover bg-center"
        style={{ backgroundImage: `url(${AR_BACKGROUND})` }}
      >
        <div className="absolute inset-0 bg-black/10" />
      </div>

      {/* Top HUD */}
      <div className="absolute top-0 w-full p-6 pt-12 flex justify-between items-start z-10">
        <div className="bg-black/40 backdrop-blur-md rounded-full px-4 py-2 flex items-center gap-2 border border-white/20 shadow-lg">
          <Navigation className="w-4 h-4 text-blue-400" />
          <span className="text-sm font-medium tracking-wide">Pioneer Square</span>
        </div>
        
        <button className="bg-black/40 backdrop-blur-md w-10 h-10 rounded-full flex items-center justify-center border border-white/20 shadow-lg">
          <Scan className="w-5 h-5 text-white" />
        </button>
      </div>

      {/* AR Markers */}
      <div className="absolute inset-0 pointer-events-none">
        {MOCK_EXHIBITS.map((exhibit) => (
          <motion.div
            key={exhibit.id}
            className="absolute pointer-events-auto cursor-pointer flex flex-col items-center gap-2"
            style={{ left: `${exhibit.x}%`, top: `${exhibit.y}%` }}
            initial={{ scale: 0, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            transition={{ type: "spring", bounce: 0.5, delay: 0.2 }}
            onClick={() => setSelectedExhibit(exhibit)}
          >
            {/* Pulsing ring */}
            <div className="relative flex items-center justify-center">
              <motion.div
                className="absolute w-16 h-16 rounded-full bg-blue-500/20 border border-blue-400/50"
                animate={{ scale: [1, 1.5, 1], opacity: [0.8, 0, 0.8] }}
                transition={{ duration: 2, repeat: Infinity, ease: "easeInOut" }}
              />
              <div className="w-10 h-10 rounded-full bg-black/60 backdrop-blur-md border border-white/30 flex items-center justify-center shadow-[0_0_15px_rgba(59,130,246,0.5)]">
                <Sparkles className="w-5 h-5 text-blue-400" />
              </div>
            </div>
            
            <div className="bg-black/60 backdrop-blur-md px-3 py-1 rounded-full border border-white/20 flex flex-col items-center shadow-lg">
              <span className="text-xs font-semibold whitespace-nowrap">{exhibit.title}</span>
              <span className="text-[10px] text-white/60">{exhibit.distance}</span>
            </div>
          </motion.div>
        ))}
      </div>

      {/* Radar Mini-map */}
      <div className="absolute bottom-28 left-6 w-20 h-20 bg-black/40 backdrop-blur-md rounded-full border border-white/20 flex items-center justify-center shadow-lg">
        <div className="w-1.5 h-1.5 bg-blue-500 rounded-full shadow-[0_0_8px_rgba(59,130,246,1)] z-10" />
        {/* Radar sweep */}
        <motion.div
          className="absolute inset-0 rounded-full border-t border-blue-400/50 bg-gradient-to-tr from-transparent to-blue-500/20 origin-center"
          animate={{ rotate: 360 }}
          transition={{ duration: 4, repeat: Infinity, ease: "linear" }}
        />
        {/* Dots on radar */}
        <div className="absolute top-4 right-4 w-1 h-1 bg-white rounded-full opacity-60" />
        <div className="absolute bottom-6 left-5 w-1 h-1 bg-white rounded-full opacity-60" />
      </div>

      {/* Exhibit Details Drawer */}
      <AnimatePresence>
        {selectedExhibit && (
          <motion.div
            initial={{ y: "100%" }}
            animate={{ y: 0 }}
            exit={{ y: "100%" }}
            transition={{ type: "spring", bounce: 0, duration: 0.4 }}
            className="absolute bottom-0 left-0 right-0 h-[70%] bg-zinc-950/95 backdrop-blur-xl rounded-t-3xl border-t border-white/10 p-6 flex flex-col z-50 shadow-2xl"
          >
            {/* Handle */}
            <div className="w-12 h-1.5 bg-white/20 rounded-full mx-auto mb-6" />
            
            <div className="flex justify-between items-start mb-4">
              <div>
                <p className="text-blue-400 text-xs font-bold uppercase tracking-wider mb-1">{selectedExhibit.type}</p>
                <h2 className="text-2xl font-bold">{selectedExhibit.title}</h2>
              </div>
              <button 
                onClick={() => setSelectedExhibit(null)}
                className="p-2 bg-white/10 rounded-full hover:bg-white/20 transition"
              >
                <X className="w-5 h-5 text-white/80" />
              </button>
            </div>

            <div className="relative w-full h-48 rounded-2xl overflow-hidden mb-6 flex-shrink-0">
              <img src={selectedExhibit.image} alt={selectedExhibit.title} className="w-full h-full object-cover" />
              <div className="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent" />
              <div className="absolute bottom-3 left-3 flex gap-2">
                <div className="bg-black/50 backdrop-blur-md rounded-full px-3 py-1.5 flex items-center gap-1.5 text-xs text-white">
                  <Play className="w-3 h-3 fill-current" /> Audio
                </div>
                <div className="bg-black/50 backdrop-blur-md rounded-full px-3 py-1.5 flex items-center gap-1.5 text-xs text-white">
                  <ImageIcon className="w-3 h-3" /> 5 Archives
                </div>
              </div>
            </div>

            <div className="flex-1 overflow-y-auto pr-2 pb-20">
              <p className="text-white/80 leading-relaxed text-sm mb-6">
                {selectedExhibit.description}
              </p>
              
              <h3 className="font-semibold text-sm mb-3">Community Contributions</h3>
              <div className="space-y-3">
                {[1, 2].map((i) => (
                  <div key={i} className="bg-white/5 rounded-xl p-3 flex gap-3">
                    <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-blue-500 to-purple-500 flex-shrink-0" />
                    <div>
                      <p className="text-xs text-white/60 mb-1">Local Resident</p>
                      <p className="text-sm text-white/90">"I remember my grandfather telling me stories about this corner..."</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
            
            {/* Sticky Action Button */}
            <div className="absolute bottom-6 left-6 right-6">
              <button className="w-full py-3.5 bg-white text-black font-semibold rounded-xl flex items-center justify-center gap-2 shadow-lg shadow-white/10 active:scale-95 transition-transform">
                <Play className="w-4 h-4 fill-current" /> Begin Experience
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Safe area for BottomNav */}
      <div className="absolute bottom-0 w-full h-24 bg-gradient-to-t from-black/80 to-transparent pointer-events-none z-40" />
    </div>
  );
}
