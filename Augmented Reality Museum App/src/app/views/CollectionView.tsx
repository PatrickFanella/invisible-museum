import { Library, Clock, Heart, Download } from "lucide-react";

const SAVED_EXHIBITS = [
  {
    id: 1,
    title: "1980s Neon Signs of Downtown",
    type: "Visual Archive",
    date: "Saved 2 days ago",
    image: "https://images.unsplash.com/photo-1546012112-142c81b59a42?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxhYmFuZG9uZWQlMjBzdG9yZWZyb250fGVufDF8fHx8MTc4MTUwMjcyMXww&ixlib=rb-4.1.0&q=80&w=1080",
    downloaded: true,
  },
  {
    id: 2,
    title: "Voices of the Strike (1919)",
    type: "Audio Narrative",
    date: "Saved 1 week ago",
    image: "https://images.unsplash.com/photo-1495379572396-5f27a279ee91?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxoaXN0b3JpYyUyMHRyYWluJTIwc3RhdGlvbiUyMHZpbnRhZ2V8ZW58MXx8fHwxNzgxNTAyNzIxfDA&ixlib=rb-4.1.0&q=80&w=1080",
    downloaded: false,
  }
];

export function CollectionView() {
  return (
    <div className="w-full h-full bg-zinc-950 text-white overflow-y-auto pb-28">
      <div className="px-6 pt-12 pb-6 sticky top-0 bg-zinc-950/80 backdrop-blur-xl z-10 border-b border-white/5">
        <h1 className="text-2xl font-bold mb-4">Your Collection</h1>
        
        <div className="flex gap-2 overflow-x-auto pb-2 scrollbar-hide">
          {["All", "Downloaded", "Audio", "Visual", "3D Objects"].map((tag, i) => (
            <button key={tag} className={`px-4 py-1.5 rounded-full text-sm whitespace-nowrap ${i === 0 ? 'bg-white text-black font-medium' : 'bg-zinc-900 border border-white/10 text-white/70'}`}>
              {tag}
            </button>
          ))}
        </div>
      </div>

      <div className="p-6 space-y-4">
        {SAVED_EXHIBITS.map((exhibit) => (
          <div key={exhibit.id} className="bg-zinc-900 rounded-2xl border border-white/5 overflow-hidden flex flex-col">
            <div className="h-32 w-full relative">
              <img src={exhibit.image} alt={exhibit.title} className="w-full h-full object-cover opacity-80" />
              <div className="absolute inset-0 bg-gradient-to-t from-zinc-900 to-transparent" />
              <div className="absolute top-3 right-3 w-8 h-8 rounded-full bg-black/40 backdrop-blur-md flex items-center justify-center">
                <Heart className="w-4 h-4 text-white fill-white" />
              </div>
            </div>
            <div className="p-4">
              <div className="flex justify-between items-start mb-2">
                <div>
                  <p className="text-blue-400 text-[10px] font-bold uppercase tracking-wider mb-1">{exhibit.type}</p>
                  <h3 className="font-semibold text-sm">{exhibit.title}</h3>
                </div>
                {exhibit.downloaded ? (
                  <div className="bg-green-500/10 text-green-400 p-1.5 rounded-full">
                    <Download className="w-4 h-4" />
                  </div>
                ) : (
                  <div className="bg-zinc-800 text-white/50 p-1.5 rounded-full">
                    <Download className="w-4 h-4" />
                  </div>
                )}
              </div>
              <div className="flex items-center gap-1.5 text-xs text-white/40 mt-3">
                <Clock className="w-3 h-3" /> {exhibit.date}
              </div>
            </div>
          </div>
        ))}

        <div className="mt-8 p-6 rounded-2xl border border-dashed border-white/20 flex flex-col items-center text-center">
          <div className="w-12 h-12 rounded-full bg-zinc-900 flex items-center justify-center mb-3">
            <Library className="w-5 h-5 text-white/50" />
          </div>
          <h4 className="font-medium text-sm mb-1">Discover more exhibits</h4>
          <p className="text-xs text-white/50 mb-4">Explore the map or scan your surroundings to find invisible histories.</p>
          <button className="px-4 py-2 bg-zinc-800 rounded-lg text-sm font-medium">Open Map</button>
        </div>
      </div>
    </div>
  );
}
