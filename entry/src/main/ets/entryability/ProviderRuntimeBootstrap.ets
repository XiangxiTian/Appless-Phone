import { common } from '@kit.AbilityKit';
import { aiLogInfo, configureComposioConfigFromRawJson,
  configureLocalModelSettingsFromRawJson, configureLocalProviderConfigFromRawJson } from '@loop/agent-core';
import util from '@ohos.util';

const LOCAL_PROVIDER_CONFIG_RAWFILE: string = 'aiphone_provider_config.json';
const COMPOSIO_CONFIG_RAWFILE: string = 'composio_config.json';

function rawfileText(context: common.Context, path: string): string {
  const bytes = context.resourceManager.getRawFileContentSync(path);
  return util.TextDecoder.create('utf-8').decodeToString(bytes);
}

export function loadProviderRuntimeConfig(context: common.Context, loadComposio: boolean = true): void {
  try {
    const rawJson = rawfileText(context, LOCAL_PROVIDER_CONFIG_RAWFILE);
    configureLocalProviderConfigFromRawJson(rawJson);
    configureLocalModelSettingsFromRawJson(rawJson);
    aiLogInfo('[AIPhone][ProviderRuntimeBootstrap] localProviderLoaded=true');
  } catch (_error) {
    aiLogInfo('[AIPhone][ProviderRuntimeBootstrap] localProviderLoaded=false');
  }
  if (!loadComposio) return;
  try {
    configureComposioConfigFromRawJson(rawfileText(context, COMPOSIO_CONFIG_RAWFILE));
    aiLogInfo('[AIPhone][ProviderRuntimeBootstrap] composioLoaded=true');
  } catch (_error) {
    aiLogInfo('[AIPhone][ProviderRuntimeBootstrap] composioLoaded=false');
  }
}
