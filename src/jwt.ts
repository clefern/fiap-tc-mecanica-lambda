import jwt, { Algorithm } from "jsonwebtoken";

const ALGORITHM: Algorithm = "HS256";
const ISSUER = "mecanica-api";

export interface AccessTokenClaims {
  sub: string;
  email: string;
  role: "CLIENTE" | "ADMIN" | "ATENDENTE" | "MECANICO";
}

export interface IssuedToken {
  token: string;
  expiresIn: number;
}

const getSecret = (): string => {
  const secret = process.env.SECURITY_JWT_SECRET_KEY;
  if (!secret) {
    throw new Error(
      "SECURITY_JWT_SECRET_KEY env var ausente — Lambda deve usar a MESMA secret do app (validação transparente do JwtAuthenticationFilter).",
    );
  }
  return secret;
};

export const issueAccessToken = (claims: AccessTokenClaims): IssuedToken => {
  const expiresIn = Number(process.env.ACCESS_TOKEN_TTL_SECONDS ?? 3600);
  const token = jwt.sign(claims, getSecret(), {
    algorithm: ALGORITHM,
    expiresIn,
    issuer: ISSUER,
  });
  return { token, expiresIn };
};
