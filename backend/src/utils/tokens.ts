import * as Koa from "koa";

const authHeaderRegexp = /^Bearer (.+)$/;

export function getAccessTokenT(ctx: Koa.BaseContext): string {
  const authHeader = ctx.get("Authorization");
  const m = authHeader.match(authHeaderRegexp);
  if (!authHeader || !m || !m[1]) {
    throw {
      code: 403,
      message: "Unauthorized",
    };
  }

  return m[1];
}
