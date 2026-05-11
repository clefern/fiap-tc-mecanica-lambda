import { describe, it, expect } from "vitest";
import { validateCpf } from "../src/cpf";

describe("validateCpf", () => {
  it("aceita CPF válido com formatação", () => {
    expect(validateCpf("529.982.247-25")).toBe("52998224725");
  });

  it("aceita CPF válido sem formatação", () => {
    expect(validateCpf("52998224725")).toBe("52998224725");
  });

  it("rejeita CPF com dígito verificador inválido", () => {
    expect(validateCpf("529.982.247-26")).toBeNull();
  });

  it("rejeita CPF com todos dígitos iguais", () => {
    expect(validateCpf("11111111111")).toBeNull();
    expect(validateCpf("00000000000")).toBeNull();
  });

  it("rejeita CPF com tamanho errado", () => {
    expect(validateCpf("123")).toBeNull();
    expect(validateCpf("123456789012")).toBeNull();
  });

  it("rejeita string vazia", () => {
    expect(validateCpf("")).toBeNull();
  });
});
