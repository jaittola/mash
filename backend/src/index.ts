import * as Koa from "koa"

import * as logger from "koa-logger"
import * as json from "koa-json"

import { rootRouter } from './routes/root'
import { authRouter } from './routes/auth'
import { setup as oidcSetup } from './openid-connect'

main().catch(error => { console.error("Starting app failed", error) })

async function main() {
  const app = new Koa()

  app.use(json())
  app.use(logger())

  app.use(rootRouter.routes()).use(rootRouter.allowedMethods())
  app.use(authRouter.routes()).use(authRouter.allowedMethods())

  await oidcSetup()
  app.listen(3000, () => {
    console.log("Started")
  })
}
