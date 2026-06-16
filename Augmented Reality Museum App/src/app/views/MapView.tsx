import { MapPin, Search, Filter } from "lucide-react";

export function MapView() {
  return (
    <div className="w-full h-full bg-zinc-950 text-white flex flex-col relative">
      <div className="absolute top-0 w-full p-6 pt-12 z-10 flex gap-3 pointer-events-none">
        <div className="flex-1 bg-black/60 backdrop-blur-md rounded-2xl px-4 py-3 flex items-center gap-3 border border-white/10 pointer-events-auto">
          <Search className="w-5 h-5 text-white/50" />
          <input 
            type="text" 
            placeholder="Search city or exhibit..." 
            className="bg-transparent border-none outline-none text-sm w-full text-white placeholder-white/50"
          />
        </div>
        <button className="bg-black/60 backdrop-blur-md w-12 h-12 rounded-2xl flex items-center justify-center border border-white/10 flex-shrink-0 pointer-events-auto">
          <Filter className="w-5 h-5 text-white" />
        </button>
      </div>

      {/* Abstract Map Background Simulation */}
      <div className="absolute inset-0 bg-[#0a0a0a]">
        <div className="absolute inset-0 opacity-20" style={{ backgroundImage: 'radial-gradient(#3b82f6 1px, transparent 1px)', backgroundSize: '24px 24px' }}></div>
        {/* Fake streets */}
        <div className="absolute top-1/4 left-0 right-0 h-4 bg-zinc-900 rotate-12 transform origin-left" />
        <div className="absolute top-1/2 left-0 right-0 h-3 bg-zinc-900 -rotate-6 transform origin-right" />
        <div className="absolute top-0 bottom-0 left-1/3 w-6 bg-zinc-900" />
        <div className="absolute top-0 bottom-0 right-1/4 w-4 bg-zinc-900 rotate-3 transform origin-top" />
        
        {/* Map Pins */}
        <MapPinMarker x={35} y={45} title="Ghost Station" active />
        <MapPinMarker x={65} y={25} title="Lost Corner Store" />
        <MapPinMarker x={20} y={75} title="Echoes of 1999" />
        <MapPinMarker x={80} y={60} title="The First Library" />
      </div>

      {/* Selected Location Card */}
      <div className="absolute bottom-28 left-6 right-6 bg-zinc-900/90 backdrop-blur-md border border-white/10 p-4 rounded-2xl flex gap-4 shadow-2xl">
        <div className="w-20 h-20 bg-zinc-800 rounded-xl overflow-hidden flex-shrink-0">
          <img 
            src="https://images.unsplash.com/photo-1495379572396-5f27a279ee91?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxoaXN0b3JpYyUyMHRyYWluJTIwc3RhdGlvbiUyMHZpbnRhZ2V8ZW58MXx8fHwxNzgxNTAyNzIxfDA&ixlib=rb-4.1.0&q=80&w=1080" 
            alt="Exhibit"
            className="w-full h-full object-cover opacity-80"
          />
        </div>
        <div className="flex flex-col justify-center">
          <span className="text-[10px] uppercase text-blue-400 font-bold tracking-wider mb-1">Immersive Narrative</span>
          <h3 className="font-semibold text-sm mb-1">The Ghost Station</h3>
          <p className="text-xs text-white/50 line-clamp-2">Listen to the echoes of the 1924 transit line that used to run exactly where...</p>
        </div>
      </div>
    </div>
  );
}

function MapPinMarker({ x, y, title, active = false }: { x: number, y: number, title: string, active?: boolean }) {
  return (
    <div className="absolute flex flex-col items-center" style={{ left: `${x}%`, top: `${y}%`, transform: 'translate(-50%, -100%)' }}>
      <div className="bg-zinc-900/80 backdrop-blur-sm px-2 py-1 rounded-md text-[10px] font-medium border border-white/10 mb-1 shadow-lg whitespace-nowrap">
        {title}
      </div>
      <div className={`w-8 h-8 rounded-full flex items-center justify-center shadow-lg ${active ? 'bg-blue-500 shadow-blue-500/50' : 'bg-zinc-800 border border-white/20'}`}>
        <MapPin className={`w-4 h-4 ${active ? 'text-white' : 'text-white/70'}`} />
      </div>
      {active && (
        <div className="absolute top-full w-1 h-8 bg-gradient-to-b from-blue-500 to-transparent opacity-50" />
      )}
    </div>
  );
}
