import * as Router from "koa-router"

export const rootRouter = new Router()

rootRouter.get("/", (ctx, next) => {
  ctx.body = `
<body>
<h1>Hello</h1>
<p>Nothing really to see here</p>
</body>`
  next()
})
