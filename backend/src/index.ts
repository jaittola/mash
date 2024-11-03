import * as Koa from "koa";

import * as json from "koa-json";
import * as logger from "koa-logger";

import { setup as oidcSetup } from "./openid-connect";
import { authRouter } from "./routes/auth";
import { infoRouter } from "./routes/info";
import { rootRouter } from "./routes/root";

main().catch((error) => {
  console.error("Starting app failed", error);
});

async function main() {
  const app = new Koa();

  app.use(json());
  app.use(logger());

  app.use(rootRouter.routes()).use(rootRouter.allowedMethods());
  app.use(authRouter.routes()).use(authRouter.allowedMethods());
  app.use(infoRouter.routes()).use(infoRouter.allowedMethods());

  await oidcSetup();
  app.listen(3000, () => {
    console.log("Started");
  });
}
