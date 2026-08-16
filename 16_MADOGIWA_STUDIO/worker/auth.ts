import { createRemoteJWKSet, jwtVerify } from "jose";
import { HttpError } from "./http";

export type AdminIdentity = { email: string; source: "access" };

const remoteJwkSets = new Map<string, ReturnType<typeof createRemoteJWKSet>>();

function getRemoteJwkSet(teamDomain: string): ReturnType<typeof createRemoteJWKSet> {
  const existing = remoteJwkSets.get(teamDomain);
  if (existing) return existing;

  const jwks = createRemoteJWKSet(new URL(`${teamDomain}/cdn-cgi/access/certs`));
  remoteJwkSets.set(teamDomain, jwks);
  return jwks;
}

function getAccessToken(request: Request): string {
  const assertion = request.headers.get("cf-access-jwt-assertion");
  if (assertion) return assertion;

  const cookieHeader = request.headers.get("cookie") ?? "";
  for (const cookie of cookieHeader.split(";")) {
    const separator = cookie.indexOf("=");
    if (separator === -1) continue;
    if (cookie.slice(0, separator).trim() === "CF_Authorization") {
      return cookie.slice(separator + 1).trim();
    }
  }
  return "";
}

async function getVerifiedJwtEmail(request: Request, env: Env): Promise<string> {
  const token = getAccessToken(request);
  if (!token) return "";

  try {
    const { payload } = await jwtVerify(token, getRemoteJwkSet(env.TEAM_DOMAIN), {
      issuer: env.TEAM_DOMAIN,
      audience: env.POLICY_AUD,
    });
    return typeof payload.email === "string" ? payload.email.trim() : "";
  } catch {
    return "";
  }
}

export async function getAdminIdentity(
  request: Request,
  env: Env,
  ctx: ExecutionContext,
): Promise<AdminIdentity | null> {
  const accessIdentity = await ctx.access?.getIdentity();
  const email = typeof accessIdentity?.email === "string" ? accessIdentity.email.trim() : "";
  if (email) return { email, source: "access" };

  const jwtEmail = await getVerifiedJwtEmail(request, env);
  if (jwtEmail) return { email: jwtEmail, source: "access" };
  return null;
}

export async function requireAdmin(request: Request, env: Env, ctx: ExecutionContext): Promise<AdminIdentity> {
  const identity = await getAdminIdentity(request, env, ctx);
  if (!identity) {
    throw new HttpError(401, "管理機能を利用するにはCloudflare Accessでログインしてください");
  }
  return identity;
}
