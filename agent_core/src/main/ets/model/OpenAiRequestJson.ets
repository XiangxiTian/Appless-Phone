/**
 * Merges provider-specific top-level parameters into an OpenAI-compatible
 * request while preserving the request's transport and identity contract.
 * Invalid, non-object, empty, or protected-field custom JSON is ignored.
 */
export function mergeOpenAiRequestJson(baseJson: string, customParametersJson: string): string {
  const customJson = customParametersJson.trim();
  if (customJson.length === 0) return baseJson;
  try {
    const parsed = JSON.parse(customJson) as Object;
    if (parsed === undefined || parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) return baseJson;
    const keys: string[] = Object.keys(parsed);
    for (let index = 0; index < keys.length; index++) {
      const key = keys[index];
      if (key === 'model' || key === 'messages' || key === 'stream') return baseJson;
    }
    const normalizedCustomJson = JSON.stringify(parsed);
    if (normalizedCustomJson.length <= 2) return baseJson;
    return baseJson.substring(0, baseJson.length - 1) + ',' + normalizedCustomJson.substring(1);
  } catch (_error) {
    return baseJson;
  }
}
