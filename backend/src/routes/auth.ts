
import * as Router from "koa-router"
import { getAuthConfig } from "../openid-connect"

export const authRouter = new Router()

const authPaths = new Router()

authPaths.get('/config', (ctx, next) => {
  ctx.body = getAuthConfig()
  next()
})

authRouter.use('/auth', authPaths.routes(), authPaths.allowedMethods())
