import { ZodError } from "zod";

export class HttpError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

export function json(data: unknown, init: ResponseInit = {}): Response {
  const headers = new Headers(init.headers);
  headers.set("content-type", "application/json; charset=utf-8");
  return new Response(JSON.stringify(data), { ...init, headers });
}

export async function readJson(request: Request): Promise<unknown> {
  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().includes("application/json")) {
    throw new HttpError(415, "Content-Type must be application/json");
  }
  return request.json();
}

export function errorResponse(error: unknown, path: string): Response {
  if (error instanceof HttpError) {
    return json({ error: error.message }, { status: error.status });
  }
  if (error instanceof ZodError) {
    return json(
      { error: "入力内容を確認してください", details: error.issues },
      { status: 400 },
    );
  }

  const message = error instanceof Error ? error.message : String(error);
  console.error(JSON.stringify({ message: "request failed", error: message, path }));
  return json({ error: "サーバーで問題が発生しました" }, { status: 500 });
}
