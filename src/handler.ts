import type {
  APIGatewayProxyEvent,
  APIGatewayProxyResult,
  Context,
} from "aws-lambda";
import { validateCpf } from "./cpf";
import { findClienteByDocumento, ClienteAtivo } from "./repository";
import { issueAccessToken } from "./jwt";

interface AuthRequest {
  cpf?: string;
}

interface AuthResponse {
  access_token: string;
  token_type: "Bearer";
  expires_in: number;
  cliente: {
    id: string;
    nome: string;
    email: string;
  };
}

interface ErrorResponse {
  code: string;
  message: string;
}

const json = <T>(statusCode: number, body: T): APIGatewayProxyResult => ({
  statusCode,
  headers: {
    "Content-Type": "application/json",
    "Cache-Control": "no-store",
  },
  body: JSON.stringify(body),
});

export const handler = async (
  event: APIGatewayProxyEvent,
  _context: Context,
): Promise<APIGatewayProxyResult> => {
  let parsed: AuthRequest;
  try {
    parsed = event.body ? JSON.parse(event.body) : {};
  } catch {
    return json<ErrorResponse>(400, {
      code: "AUTH-400-01",
      message: "Body inválido — JSON malformado.",
    });
  }

  const rawCpf = parsed.cpf?.trim();
  if (!rawCpf) {
    return json<ErrorResponse>(400, {
      code: "AUTH-400-02",
      message: "Campo 'cpf' é obrigatório.",
    });
  }

  const normalized = validateCpf(rawCpf);
  if (!normalized) {
    return json<ErrorResponse>(400, {
      code: "AUTH-400-03",
      message: "CPF inválido.",
    });
  }

  let cliente: ClienteAtivo | null;
  try {
    cliente = await findClienteByDocumento(normalized);
  } catch (err) {
    console.error("[handler] db error", err);
    return json<ErrorResponse>(503, {
      code: "AUTH-503-01",
      message: "Falha ao consultar base de clientes.",
    });
  }

  if (!cliente) {
    return json<ErrorResponse>(404, {
      code: "AUTH-404-01",
      message: "Cliente não encontrado.",
    });
  }

  if (!cliente.ativo) {
    return json<ErrorResponse>(403, {
      code: "AUTH-403-01",
      message: "Cliente inativo.",
    });
  }

  const { token, expiresIn } = issueAccessToken({
    email: cliente.email,
    clienteId: cliente.id,
    role: "CLIENTE",
  });

  return json<AuthResponse>(200, {
    access_token: token,
    token_type: "Bearer",
    expires_in: expiresIn,
    cliente: {
      id: cliente.id,
      nome: cliente.nome,
      email: cliente.email,
    },
  });
};
