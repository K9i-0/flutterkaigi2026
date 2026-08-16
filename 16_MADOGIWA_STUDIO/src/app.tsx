import { createBrowserRouter, RouterProvider } from "react-router-dom";
import { Toaster } from "sonner";
import { Layout } from "@/components/layout";
import { ImageLightboxProvider } from "@/components/image-lightbox";
import { AdminPage } from "@/pages/admin-page";
import { EpisodePage } from "@/pages/episode-page";
import { HomePage } from "@/pages/home-page";
import { MoviesPage } from "@/pages/movies-page";
import { NotFoundPage } from "@/pages/not-found-page";

const router = createBrowserRouter([
  {
    element: <Layout />,
    children: [
      { path: "/", element: <HomePage /> },
      { path: "/movies", element: <MoviesPage /> },
      { path: "/episodes/:slug", element: <EpisodePage /> },
      { path: "/admin", element: <AdminPage /> },
      { path: "*", element: <NotFoundPage /> },
    ],
  },
]);

export function App() {
  return <ImageLightboxProvider><RouterProvider router={router} /><Toaster theme="dark" richColors position="bottom-right" /></ImageLightboxProvider>;
}
