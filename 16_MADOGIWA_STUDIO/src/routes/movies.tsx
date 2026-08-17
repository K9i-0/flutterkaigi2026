import { createFileRoute, redirect } from "@tanstack/react-router";

export const Route = createFileRoute("/movies")({ beforeLoad: () => { throw redirect({ to: "/episodes", statusCode: 301 }); } });
