import * as z from 'zod'

const configJson = require("../../config.json")

const Config = z.object({
  openidConfig: z.string()
})
export type Config = z.infer<typeof Config>

export const config = (() => {
  try {
    return Config.parse(configJson)
  } catch (error) {
    console.error("Parsing configuration failed", error)
    throw error
  }
})()

