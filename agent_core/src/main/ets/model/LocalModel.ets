import { ConversationContext } from '../agent/ConversationContext';

export type LocalModelTextDeltaListener = (delta: string) => void;

export interface LocalModel {
  complete(
    prompt: string,
    conversation?: ConversationContext,
    systemPrompt?: string,
    onTextDelta?: LocalModelTextDeltaListener
  ): Promise<string>;
}
