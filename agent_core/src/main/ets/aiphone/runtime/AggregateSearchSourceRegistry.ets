import {
  AggregateSearchSource,
  AggregateSearchSourceContext,
  AggregateSearchSourceMetadata
} from './AggregateSearchTypes';

const SOURCE_METADATA: AggregateSearchSourceMetadata[] = [
  { source: 'youtube', isExternal: true, languages: ['zh-Hans', 'zh-Hant', 'en'], languageFilterMode: 'native', introducedInRegistryVersion: 1, defaultEnabled: true, capabilities: { search: true, interest: true } },
  { source: 'bilibili', isExternal: false, languages: ['zh-Hans', 'zh-Hant'], languageFilterMode: 'intrinsic', introducedInRegistryVersion: 1, defaultEnabled: true, capabilities: { search: true, interest: true } },
  { source: 'x', isExternal: true, languages: ['zh-Hans', 'zh-Hant', 'en'], languageFilterMode: 'native', introducedInRegistryVersion: 1, defaultEnabled: true, capabilities: { search: true, interest: true } },
  { source: 'hackernews', isExternal: true, languages: ['en'], languageFilterMode: 'intrinsic', introducedInRegistryVersion: 1, defaultEnabled: true, capabilities: { search: true, interest: true } },
  { source: 'reddit', isExternal: true, languages: ['zh-Hans', 'zh-Hant', 'en'], languageFilterMode: 'none', introducedInRegistryVersion: 1, defaultEnabled: true, capabilities: { search: true, interest: true } },
  { source: 'zhihu', isExternal: false, languages: ['zh-Hans', 'zh-Hant'], languageFilterMode: 'intrinsic', introducedInRegistryVersion: 1, defaultEnabled: true, capabilities: { search: true, interest: true } },
  { source: 'applepodcasts', isExternal: true, languages: ['zh-Hans', 'zh-Hant', 'en'], languageFilterMode: 'regional', introducedInRegistryVersion: 2, defaultEnabled: true, capabilities: { search: true, interest: true } },
  { source: 'twitch', isExternal: true, languages: ['zh-Hans', 'zh-Hant', 'en'], languageFilterMode: 'post_filter', introducedInRegistryVersion: 2, defaultEnabled: true, capabilities: { search: false, interest: true } }
];

function cloneMetadata(metadata: AggregateSearchSourceMetadata): AggregateSearchSourceMetadata {
  return {
    source: metadata.source,
    isExternal: metadata.isExternal,
    languages: metadata.languages.slice(),
    languageFilterMode: metadata.languageFilterMode,
    introducedInRegistryVersion: metadata.introducedInRegistryVersion,
    defaultEnabled: metadata.defaultEnabled,
    capabilities: {
      search: metadata.capabilities.search,
      interest: metadata.capabilities.interest
    }
  };
}

export function aggregateSearchRegistryMetadata(): AggregateSearchSourceMetadata[] {
  return SOURCE_METADATA.map((metadata: AggregateSearchSourceMetadata): AggregateSearchSourceMetadata =>
    cloneMetadata(metadata));
}

export function aggregateSearchRegistrySourceIds(): AggregateSearchSource[] {
  return SOURCE_METADATA.map((metadata: AggregateSearchSourceMetadata): AggregateSearchSource => metadata.source);
}

export function aggregateSearchSourceIdsForContext(
  context: AggregateSearchSourceContext
): AggregateSearchSource[] {
  return SOURCE_METADATA.filter((metadata: AggregateSearchSourceMetadata): boolean =>
    context === 'search' ? metadata.capabilities.search : metadata.capabilities.interest
  ).map((metadata: AggregateSearchSourceMetadata): AggregateSearchSource => metadata.source);
}

export function aggregateSearchSearchSourceIds(): AggregateSearchSource[] {
  return aggregateSearchSourceIdsForContext('search');
}

export function aggregateSearchInterestSourceIds(): AggregateSearchSource[] {
  return aggregateSearchSourceIdsForContext('interest');
}

export function aggregateSearchRegistryVersion(): number {
  let version = 1;
  SOURCE_METADATA.forEach((metadata: AggregateSearchSourceMetadata): void => {
    version = Math.max(version, metadata.introducedInRegistryVersion);
  });
  return version;
}

export function aggregateSearchDefaultEnabledSourceIdsAfter(
  registryVersion: number = 0
): AggregateSearchSource[] {
  return SOURCE_METADATA.filter((metadata: AggregateSearchSourceMetadata): boolean =>
    metadata.defaultEnabled && metadata.introducedInRegistryVersion > registryVersion
  ).map((metadata: AggregateSearchSourceMetadata): AggregateSearchSource => metadata.source);
}

export function aggregateSearchDefaultEnabledSourceIds(): AggregateSearchSource[] {
  return SOURCE_METADATA.filter((metadata: AggregateSearchSourceMetadata): boolean => metadata.defaultEnabled)
    .map((metadata: AggregateSearchSourceMetadata): AggregateSearchSource => metadata.source);
}

export function aggregateSearchRegistryMetadataFor(
  source: AggregateSearchSource
): AggregateSearchSourceMetadata {
  for (let index = 0; index < SOURCE_METADATA.length; index++) {
    if (SOURCE_METADATA[index].source === source) {
      return cloneMetadata(SOURCE_METADATA[index]);
    }
  }
  return cloneMetadata(SOURCE_METADATA[0]);
}
