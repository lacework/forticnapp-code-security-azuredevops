export function getRequiredEnvVariable(name: string): string {
  const value = process.env[name];
  if (!value) {
    console.error(`Missing required environment variable: ${name}`);
    process.exit(1);
  }
  return value;
}

export function getOptionalEnvVariable(name: string, defaultValue: string = ""): string {
  return process.env[name] || defaultValue;
}
