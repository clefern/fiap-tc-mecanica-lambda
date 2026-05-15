const onlyDigits = (raw: string): string => raw.replace(/\D/g, "");

const allSameDigit = (digits: string): boolean => /^(\d)\1+$/.test(digits);

const calcVerifier = (digits: string, factor: number): number => {
  let total = 0;
  for (let i = 0; i < digits.length; i++) {
    total += parseInt(digits[i], 10) * (factor - i);
  }
  const rest = (total * 10) % 11;
  return rest === 10 ? 0 : rest;
};

export const validateCpf = (raw: string): string | null => {
  const digits = onlyDigits(raw);
  if (digits.length !== 11) return null;
  if (allSameDigit(digits)) return null;

  const d1 = calcVerifier(digits.substring(0, 9), 10);
  if (d1 !== parseInt(digits[9], 10)) return null;

  const d2 = calcVerifier(digits.substring(0, 10), 11);
  if (d2 !== parseInt(digits[10], 10)) return null;

  return digits;
};
