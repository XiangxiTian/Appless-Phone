import { common } from '@kit.AbilityKit';
import { aiLogInfo } from '@loop/agent-core';
import { BGE_SMALL_ZH_MODEL_RAWFILE } from './BgeMindSporeEmbeddingPort';

export interface PhoneLocalMemoryAvailabilityPort {
  isAvailable(): boolean;
}

export type PhoneLocalMemoryAvailabilityProbe = () => boolean;
export type PhoneLocalMemoryAvailabilityLogger = (message: string) => void;

/**
 * Process-lifetime gate. The probe and one sanitized disabled log are both run at most once.
 */
export class CachedPhoneLocalMemoryAvailability implements PhoneLocalMemoryAvailabilityPort {
  private readonly probe: PhoneLocalMemoryAvailabilityProbe;
  private readonly logger: PhoneLocalMemoryAvailabilityLogger;
  private checked: boolean = false;
  private available: boolean = false;

  constructor(
    probe: PhoneLocalMemoryAvailabilityProbe,
    logger?: PhoneLocalMemoryAvailabilityLogger
  ) {
    this.probe = probe;
    this.logger = logger === undefined ? (message: string): void => aiLogInfo(message) : logger;
  }

  isAvailable(): boolean {
    if (this.checked) return this.available;
    this.checked = true;
    try {
      this.available = this.probe();
    } catch (_error) {
      this.available = false;
    }
    if (!this.available) {
      this.logger('[AIPhone][PhoneLocalMemoryAvailability] status=disabled reason=model_rawfile_unavailable');
    }
    return this.available;
  }
}

/** Checks the packaged model descriptor without reading the 94 MB model into memory. */
export function phoneLocalMemoryAvailabilityForContext(
  context: common.Context,
  logger?: PhoneLocalMemoryAvailabilityLogger
): PhoneLocalMemoryAvailabilityPort {
  return new CachedPhoneLocalMemoryAvailability((): boolean => {
    let opened: boolean = false;
    try {
      const descriptor = context.resourceManager.getRawFdSync(BGE_SMALL_ZH_MODEL_RAWFILE);
      opened = true;
      return descriptor.fd >= 0 && descriptor.length > 0;
    } finally {
      if (opened) context.resourceManager.closeRawFdSync(BGE_SMALL_ZH_MODEL_RAWFILE);
    }
  }, logger);
}
