import { Client, ClientConfig } from "pg";

export interface ClienteAtivo {
  id: string;
  nome: string;
  email: string;
  ativo: boolean;
}

const buildClientConfig = (): ClientConfig => ({
  host: required("DB_HOST"),
  port: Number(process.env.DB_PORT ?? 5432),
  user: required("DB_USER"),
  password: required("DB_PASSWORD"),
  database: required("DB_NAME"),
  ssl: process.env.DB_SSL === "true" ? { rejectUnauthorized: false } : undefined,
  connectionTimeoutMillis: 3000,
});

const required = (name: string): string => {
  const v = process.env[name];
  if (!v) throw new Error(`Env var ausente: ${name}`);
  return v;
};

export const findClienteByDocumento = async (
  documento: string,
): Promise<ClienteAtivo | null> => {
  const client = new Client(buildClientConfig());
  try {
    await client.connect();
    const result = await client.query<{
      id: string;
      nome: string;
      email: string;
      ativo: boolean;
    }>(
      `SELECT c.id::text AS id, c.nome, c.email, c.ativo
         FROM clientes c
        WHERE c.documento = $1
        LIMIT 1`,
      [documento],
    );
    return result.rows[0] ?? null;
  } finally {
    await client.end().catch(() => undefined);
  }
};
