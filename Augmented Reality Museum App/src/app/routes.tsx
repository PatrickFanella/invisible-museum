import { createBrowserRouter } from "react-router";
import { MobileContainer } from "./components/MobileContainer";
import { ARView } from "./views/ARView";
import { MapView } from "./views/MapView";
import { CollectionView } from "./views/CollectionView";
import { ProfileView } from "./views/ProfileView";

export const router = createBrowserRouter([
  {
    path: "/",
    Component: MobileContainer,
    children: [
      { index: true, Component: ARView },
      { path: "map", Component: MapView },
      { path: "collection", Component: CollectionView },
      { path: "profile", Component: ProfileView },
    ],
  },
]);
