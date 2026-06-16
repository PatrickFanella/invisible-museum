import { Settings, Award, Edit3, Grid, List } from "lucide-react";

export function ProfileView() {
  return (
    <div className="w-full h-full bg-zinc-950 text-white overflow-y-auto pb-28">
      <div className="p-6 pt-12 flex justify-between items-start">
        <h1 className="text-2xl font-bold">Profile</h1>
        <button className="p-2 bg-zinc-900 rounded-full">
          <Settings className="w-5 h-5 text-white/70" />
        </button>
      </div>

      <div className="px-6 flex flex-col items-center">
        <div className="w-24 h-24 rounded-full bg-gradient-to-tr from-blue-500 to-purple-600 p-1 mb-4">
          <div className="w-full h-full rounded-full bg-zinc-900 border-2 border-black overflow-hidden">
            <img src="https://images.unsplash.com/photo-1546012112-142c81b59a42?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxhYmFuZG9uZWQlMjBzdG9yZWZyb250fGVufDF8fHx8MTc4MTUwMjcyMXww&ixlib=rb-4.1.0&q=80&w=200" alt="Avatar" className="w-full h-full object-cover" />
          </div>
        </div>
        <h2 className="text-xl font-bold">Alex Curator</h2>
        <p className="text-sm text-white/50 mb-6">Urban Historian • Seattle, WA</p>
        
        <div className="flex gap-4 w-full">
          <div className="flex-1 bg-zinc-900 rounded-2xl p-4 text-center border border-white/5">
            <p className="text-2xl font-bold text-blue-400 mb-1">12</p>
            <p className="text-[10px] uppercase tracking-wider text-white/50">Contributions</p>
          </div>
          <div className="flex-1 bg-zinc-900 rounded-2xl p-4 text-center border border-white/5">
            <p className="text-2xl font-bold text-purple-400 mb-1">45</p>
            <p className="text-[10px] uppercase tracking-wider text-white/50">Discovered</p>
          </div>
        </div>
      </div>

      <div className="mt-8 px-6">
        <div className="flex items-center justify-between mb-4">
          <h3 className="font-semibold">Your Contributions</h3>
          <div className="flex gap-2">
            <button className="p-1.5 bg-zinc-800 rounded-md text-white"><Grid className="w-4 h-4" /></button>
            <button className="p-1.5 bg-transparent rounded-md text-white/50"><List className="w-4 h-4" /></button>
          </div>
        </div>

        <div className="grid grid-cols-2 gap-3">
          <div className="aspect-square bg-zinc-900 rounded-xl border border-white/5 relative overflow-hidden group">
            <img src="https://images.unsplash.com/photo-1495379572396-5f27a279ee91?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxoaXN0b3JpYyUyMHRyYWluJTIwc3RhdGlvbiUyMHZpbnRhZ2V8ZW58MXx8fHwxNzgxNTAyNzIxfDA&ixlib=rb-4.1.0&q=80&w=400" className="w-full h-full object-cover opacity-60 group-hover:opacity-80 transition" />
            <div className="absolute inset-0 bg-gradient-to-t from-black/80 to-transparent flex flex-col justify-end p-3">
              <span className="text-xs font-semibold">1924 Tickets</span>
              <span className="text-[10px] text-white/60">Audio • 2 days ago</span>
            </div>
          </div>
          <div className="aspect-square bg-zinc-900 rounded-xl border border-dashed border-white/20 flex flex-col items-center justify-center text-white/50 hover:text-white hover:bg-zinc-800 transition cursor-pointer">
            <Edit3 className="w-6 h-6 mb-2" />
            <span className="text-xs font-medium">Add New Story</span>
          </div>
        </div>
      </div>
      
      <div className="mt-8 px-6">
        <div className="bg-gradient-to-r from-blue-900/40 to-purple-900/40 border border-blue-500/20 rounded-2xl p-4 flex items-center gap-4">
          <div className="w-12 h-12 bg-black/40 rounded-full flex items-center justify-center flex-shrink-0">
            <Award className="w-6 h-6 text-yellow-500" />
          </div>
          <div>
            <h4 className="font-semibold text-sm">Neighborhood Guide</h4>
            <p className="text-xs text-white/60 mt-1">You've unlocked this badge for mapping 10 local stories in your area.</p>
          </div>
        </div>
      </div>
    </div>
  );
}
