import { ConversationContext } from '../agent/ConversationContext';

export type A2uiTextDeltaListener = (delta: string) => void;

export interface A2uiModel {
  generate(
    userTask: string,
    surfaceId: string,
    conversation?: ConversationContext,
    onTextDelta?: A2uiTextDeltaListener
  ): Promise<string>;
}
