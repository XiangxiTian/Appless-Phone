import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export function syncAuthConfig(root, source) {
  const output = join(root, 'entry/src/main/resources/rawfile/agconnect-services.json');
  const input = source || (existsSync(output) ? output : join(homedir(), '.config/appless/agconnect-services.json'));
  if (!existsSync(input)) throw new Error('Missing AGC client config. Set AIPHONE_AGC_CONFIG_PATH to the private agconnect-services.json before building.');
  const text = readFileSync(input, 'utf8');
  const config = JSON.parse(text);
  const bundle = readFileSync(join(root, 'AppScope/app.json5'), 'utf8').match(/"bundleName"\s*:\s*"([^"]+)"/)?.[1];
  const appId = readFileSync(join(root, 'entry/src/main/module.json5'), 'utf8').match(/"name"\s*:\s*"client_id"\s*,\s*"value"\s*:\s*"([^"]+)"/)?.[1];
  if (!bundle || !appId || config.client?.package_name !== bundle || config.client?.app_id !== appId ||
      !config.client?.project_id || !config.client?.product_id || !config.client?.api_key) {
    throw new Error('AGC client config does not match this application or is incomplete.');
  }
  mkdirSync(dirname(output), { recursive: true });
  if (!existsSync(output) || readFileSync(output, 'utf8') !== text) writeFileSync(output, text, { mode: 0o600 });
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  syncAuthConfig(dirname(dirname(fileURLToPath(import.meta.url))), process.env.AIPHONE_AGC_CONFIG_PATH?.trim());
  console.log('[Appless] AGC client config validated.');
}
