/**
 * Type declarations for supplementary MFE packages.
 * @so360/shell-context types come from the installed package (dist/index.d.ts).
 * Do NOT redeclare @so360/shell-context here — it shadows the real package types.
 */

declare module '@so360/design-system' {
    export const Button: React.FC<Record<string, unknown>>;
    export const Card: React.FC<Record<string, unknown>>;
    export const Input: React.FC<Record<string, unknown>>;
}

declare module '@so360/event-bus' {
    export function emit(event: string, payload: unknown): void;
    export function on(event: string, handler: (payload: unknown) => void): () => void;
    export function off(event: string, handler: (payload: unknown) => void): void;
}
