export type Operator = '+' | '-' | '×' | '÷';
export const OPERATORS: Operator[] = ['+', '-', '×', '÷'];
export type Calculation = { value: number; error?: never } | { error: string; value?: never };
export function calculate(a: number, op: Operator, b: number): Calculation {
  if (op === '-' && a <= b) return { error: 'Result must be positive' };
  if (op === '÷' && (b === 0 || a % b !== 0)) return { error: 'Must divide evenly' };
  const value = op === '+' ? a + b : op === '-' ? a - b : op === '×' ? a * b : a / b;
  if (!Number.isSafeInteger(value)) return { error: 'Result is too large' };
  return { value };
}
