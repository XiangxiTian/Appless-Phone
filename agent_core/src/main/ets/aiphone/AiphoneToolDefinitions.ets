import {
  BackendAvailability,
  BackendResolution,
  cloneToolDefinition,
  ToolAuthMode,
  ToolBackendType,
  ToolDefinition,
  ToolRiskLevel
} from './runtime/ToolDefinitionTypes';
import {
  allToolDefinitions as runtimeToolDefinitions,
  backendLabel,
  GMAIL_TOOL_IDS,
  isCalendarToolId,
  isGmailToolId,
  isKnownDomainToolId,
  isLocalAdapterToolId,
  isMapsToolId,
  isReleaseToolId,
  isYouTubeToolId,
  resolveBackendForTool,
  toolDefinitionForToolId
} from './runtime/ToolDefinitionRegistry';

export {
  BackendAvailability,
  BackendResolution,
  cloneToolDefinition,
  ToolAuthMode,
  ToolBackendType,
  ToolDefinition,
  ToolRiskLevel,
  backendLabel,
  GMAIL_TOOL_IDS,
  isCalendarToolId,
  isGmailToolId,
  isKnownDomainToolId,
  isLocalAdapterToolId,
  isMapsToolId,
  isYouTubeToolId,
  resolveBackendForTool,
  toolDefinitionForToolId
};

export function allToolDefinitions(): ToolDefinition[] {
  return runtimeToolDefinitions().filter(
    (definition: ToolDefinition): boolean => isReleaseToolId(definition.toolId)
  );
}

export function isRegisteredAiphoneToolId(toolId: string): boolean {
  return isReleaseToolId(toolId);
}

export function aiphoneToolDefinitionCount(): number {
  return allToolDefinitions().length;
}
