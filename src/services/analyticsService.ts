export function trackEvent(name: string, properties: Record<string, unknown> = {}) { console.log(`[Target] ${name}`, properties); }
