import axios, { AxiosError } from "axios";
import * as z from "zod";
import { config } from "../config";

export const OidcWellKnown = z.object({
  authorization_endpoint: z.string(),
  end_session_endpoint: z.string(),
  issuer: z.string(),
  id_token_signing_alg_values_supported: z.array(z.string()),
  jwks_uri: z.string(),
  response_types_supported: z.array(z.string()),
  revocation_endpoint: z.string(),
  scopes_supported: z.array(z.string()),
  subject_types_supported: z.array(z.string()),
  token_endpoint: z.string(),
  token_endpoint_auth_methods_supported: z.array(z.string()),
  userinfo_endpoint: z.string(),
});
export type OidcWellKnown = z.infer<typeof OidcWellKnown>;

var wellKnown: OidcWellKnown | undefined = undefined;

export async function setup() {
  try {
    const resp = await axios.get(config.openidConfig);
    wellKnown = OidcWellKnown.parse(await resp.data);
  } catch (error) {
    console.error("Getting OpenID Connect configuration failed", error);
    throw error;
  }
}

export function getAuthConfig(): OidcWellKnown | undefined {
  return wellKnown;
}

export function getAuthConfigT(): OidcWellKnown {
  const authConfig = getAuthConfig();
  if (authConfig) {
    return authConfig;
  }

  throw {
    code: 500,
    message: "Authentication configuration is missing",
  };
}

export async function getUserInfoT(accessToken: string): Promise<unknown> {
  const authConfig = getAuthConfigT();

  try {
    const url = `${authConfig.userinfo_endpoint}`;
    const resp = await axios.get(url, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    return await resp.data;
  } catch (error) {
    const e = error as AxiosError;
    throw {
      code: e.status ?? 400,
      message: e.message,
    };
  }
}
