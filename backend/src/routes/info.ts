import * as Router from "koa-router";
import { getUserInfoT } from "../openid-connect";
import { HttpError } from "../utils/error";
import { getAccessTokenT } from "../utils/tokens";

export const infoRouter = new Router();

infoRouter.get("/info/user", async (ctx, next) => {
  try {
    const token = getAccessTokenT(ctx);
    const userInfo = await getUserInfoT(token);
    ctx.body = userInfo;
    ctx.set("Content-Type", "application/json");
  } catch (error) {
    const e = error as HttpError;
    console.log("Userinfo request failed", e.message);
    ctx.status = e.code;
    ctx.body = e.message;
  }

  next();
});
