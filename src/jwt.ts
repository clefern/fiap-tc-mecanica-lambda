import jwt, { Algorithm, SignOptions } from "jsonwebtoken";

const ALGORITHM: Algorithm = "HS256";

export interface AccessTokenClaims {
  /** Email do usuário — vira o claim `sub`, igual ao login JWT do Spring (`JwtService` / `CustomUserDetails`). */
  email: string;
  /** UUID do cliente (claim extra `id`). */
  clienteId: string;
  /** Papel para consumo por clientes/APIs; o Spring continua carregando autoridades pelo banco via `sub`. */
  role: "CLIENTE" | "ADMIN" | "ATENDENTE" | "MECANICO";
}

export interface IssuedToken {
  token: string;
  expiresIn: number;
}

/**
 * Mesma convenção do Spring Boot: `security.jwt.secret-key` é Base64 (bytes da chave HMAC).
 * @see com.fiap.mecanica.infra.config.security.JwtService#getSignInKey
 */
const getSecretKeyBytes = (): Buffer => {
  const b64 = process.env.SECURITY_JWT_SECRET_KEY;
  if (!b64) {
    throw new Error(
      "SECURITY_JWT_SECRET_KEY env var ausente — use a MESMA chave Base64 do app (Secret K8s).",
    );
  }
  return Buffer.from(b64, "base64");
};

export const issueAccessToken = (claims: AccessTokenClaims): IssuedToken => {
  const expiresIn = Number(process.env.ACCESS_TOKEN_TTL_SECONDS ?? 3600);
  const secretKey = getSecretKeyBytes();
  const options: SignOptions = {
    algorithm: ALGORITHM,
    expiresIn,
    subject: claims.email,
  };
  const token = jwt.sign(
    {
      auth_grant: "cpf",
      id: claims.clienteId,
      role: claims.role,
    },
    secretKey,
    options,
  );
  return { token, expiresIn };
};
