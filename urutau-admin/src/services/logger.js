const safeError = (context, error) => {
  if (import.meta.env.DEV) {
    console.error(context, error);
    return;
  }
  console.error(`[${context}]`);
};

export default safeError;
