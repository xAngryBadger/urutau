const safeError = (context, error) => {
  if (import.meta.env.DEV) {
    console.error(`[${context}]`, error);
    return;
  }
  const msg = error instanceof Error ? error.message : String(error || '');
  const stack = error instanceof Error ? error.stack?.split('\n').slice(0, 3).join('\n') : '';
  console.error(`[${context}] ${msg}\n${stack}`);
};

export default safeError;
