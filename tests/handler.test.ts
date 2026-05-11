import { describe, it, expect, vi, beforeEach } from "vitest";

vi.mock("../src/repository", () => ({
  findClienteByDocumento: vi.fn(),
}));

import type { APIGatewayProxyEvent, Context } from "aws-lambda";
import { handler } from "../src/handler";
import { findClienteByDocumento } from "../src/repository";

const mockFind = findClienteByDocumento as ReturnType<typeof vi.fn>;

const buildEvent = (body: unknown): APIGatewayProxyEvent =>
  ({
    body: body === undefined ? null : JSON.stringify(body),
    headers: {},
    multiValueHeaders: {},
    httpMethod: "POST",
    isBase64Encoded: false,
    path: "/auth",
    pathParameters: null,
    queryStringParameters: null,
    multiValueQueryStringParameters: null,
    stageVariables: null,
    requestContext: {} as APIGatewayProxyEvent["requestContext"],
    resource: "",
  }) as APIGatewayProxyEvent;

const ctx = {} as Context;

describe("handler", () => {
  beforeEach(() => {
    mockFind.mockReset();
    process.env.SECURITY_JWT_SECRET_KEY = "test-secret-must-be-long-enough-256bit-aaaaaaa";
  });

  it("retorna 400 quando body é JSON inválido", async () => {
    const res = await handler(
      {
        ...buildEvent({}),
        body: "{not-json",
      } as APIGatewayProxyEvent,
      ctx,
    );
    expect(res.statusCode).toBe(400);
    expect(JSON.parse(res.body).code).toBe("AUTH-400-01");
  });

  it("retorna 400 quando cpf ausente", async () => {
    const res = await handler(buildEvent({}), ctx);
    expect(res.statusCode).toBe(400);
    expect(JSON.parse(res.body).code).toBe("AUTH-400-02");
  });

  it("retorna 400 quando cpf inválido", async () => {
    const res = await handler(buildEvent({ cpf: "111.111.111-11" }), ctx);
    expect(res.statusCode).toBe(400);
    expect(JSON.parse(res.body).code).toBe("AUTH-400-03");
  });

  it("retorna 404 quando cliente não encontrado", async () => {
    mockFind.mockResolvedValueOnce(null);
    const res = await handler(buildEvent({ cpf: "529.982.247-25" }), ctx);
    expect(res.statusCode).toBe(404);
    expect(JSON.parse(res.body).code).toBe("AUTH-404-01");
  });

  it("retorna 403 quando cliente inativo", async () => {
    mockFind.mockResolvedValueOnce({
      id: "11111111-1111-1111-1111-111111111111",
      nome: "Fulano",
      email: "fulano@mecanica.com",
      ativo: false,
    });
    const res = await handler(buildEvent({ cpf: "529.982.247-25" }), ctx);
    expect(res.statusCode).toBe(403);
    expect(JSON.parse(res.body).code).toBe("AUTH-403-01");
  });

  it("retorna 200 com JWT quando cliente ativo", async () => {
    mockFind.mockResolvedValueOnce({
      id: "11111111-1111-1111-1111-111111111111",
      nome: "Fulano",
      email: "fulano@mecanica.com",
      ativo: true,
    });
    const res = await handler(buildEvent({ cpf: "529.982.247-25" }), ctx);
    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.body);
    expect(body.token_type).toBe("Bearer");
    expect(body.access_token).toMatch(/^eyJ/);
    expect(body.cliente.nome).toBe("Fulano");
  });
});
