import http from '@ohos.net.http';
import util from '@ohos.util';
import { ChatMessage, ConversationContext } from '../agent/ConversationContext';
import { LlmProvider } from '../model/LlmProvider';
import { ChatCompletionSseParser } from '../model/ChatCompletionSseParser';
import { mergeOpenAiRequestJson } from '../model/OpenAiRequestJson';
import { AIPHONE_COMPONENT_CATALOG_JSON } from '../aiphone/runtime/A2uiComponentCatalogConst';
import { aiLogInfo } from '../aiphone/runtime/AiphoneLogger';
import { A2UI_VERSION } from './A2uiProtocol';
import { A2uiModel, A2uiTextDeltaListener } from './A2uiModel';

interface ChatRequest {
  model: string;
  messages: ChatMessage[];
  temperature: number;
  stream: boolean;
}

export function buildA2uiChatRequestJson(request: Object, customParametersJson: string): string {
  return mergeOpenAiRequestJson(JSON.stringify(request), customParametersJson);
}

interface ChatChoice {
  message?: ChatMessage;
}

interface ChatResponse {
  choices?: ChatChoice[];
}

interface ChatDelta {
  content?: string | null;
}

interface ChatStreamChoice {
  delta?: ChatDelta;
}

interface ChatStreamResponse {
  choices?: ChatStreamChoice[];
}

export function buildA2uiLayoutSystemPrompt(
  surfaceId: string,
  componentCatalogJson: string,
  decisionNotesEnabled: boolean = false
): string {
  const isUiLabCatalog = componentCatalogJson.indexOf('"name":"HeroBanner"') >= 0;
  const outputExample =
    `{"version":"${A2UI_VERSION}","updateComponents":{"surfaceId":"${surfaceId}","components":[` +
      '{"id":"root","component":"SurfaceRoot","child":"summary"},' +
      '{"id":"summary","component":"Text","dataPath":"/summary/text"}' +
      ']}}';
  const outputExampleSection = isUiLabCatalog ?
    '- Protocol envelope schema skeleton only; replace [...] with the actual component objects and never output the ellipsis literally:\n' +
      `{"version":"${A2UI_VERSION}","updateComponents":{"surfaceId":"${surfaceId}","components":[...]}}\n` :
    '- The following is a complete protocol-shape example only. Copy only its protocol shape; choose components, ' +
      'properties, and dataPath values strictly from the current task and catalog:\n' +
      outputExample + '\n';
  const uiLabRules = isUiLabCatalog ?
    '- For every normal non-error UI Lab result with displayable verified data, you MUST output exactly one ' +
      'HeroBanner. Do not fabricate a HeroBanner summary for an error or no-display-data baseline. HeroBanner is ' +
      'always the first visible element in the main content container. If any other visible component exists, ' +
      'SurfaceRoot.child must reference a Column and the HeroBanner id must be Column.children[0]. Never connect ' +
      'root only to HeroBanner while leaving sibling components disconnected. If HeroBanner is the only visible ' +
      'component, SurfaceRoot.child may reference it directly. HeroBanner requires title, uses text ' +
      'as its kicker and body as a natural synthesis of all verified results, and must not mechanically list toolId values.\n' +
      '- /summary/count and /summary/text describe how many DataResult sets were collected, never the total number ' +
      'of business entities. HeroBanner must not present either value as an entity total. Never infer a total from ' +
      'a sampled array length. A business count may appear only when result.data explicitly labels a scalar as count ' +
      'or total, or when result.data.summary text explicitly supports it.\n' +
      '- Choose chart fields only from each catalog schema. MetricGrid may use legacy dataPath or direct items; ' +
      'SegmentedRingChart accepts one or more comparable categories and may use legacy dataPath, direct segments, or an array ' +
      'dataPath with paired item-relative labelPath/valuePath. In mapping mode the renderer expands the complete source ' +
      'array; direct segments still enumerate every usable category explicitly. One category may render as a 100% ring, ' +
      'and 1-8 categories are usually easiest to read. For more than 8 categories, still pass every category without ' +
      'calculating, merging, or truncating them; the renderer keeps the first 8 and combines the remaining values as Other. ' +
      'Other charts keep their declared legacy dataPath. ' +
      'Choose them from the meaning and shape of the data; output no SVG, path, points, rect, viewBox, coordinates, dimensions, arc ' +
      'geometry, stroke settings, or colors. The renderer owns all chart geometry and styling.\n' +
      '- When originalUserInput explicitly requests a dashboard and the verified data meaningfully supports visualization, ' +
      'make charts the main body of the layout and use as many different chart component types as the data can meaningfully ' +
      'support. Every chart must add a distinct view. Do not repeat the same metric, invent or calculate values, or force ' +
      'a specific chart type.\n' : '';
  const dataPathRules = isUiLabCatalog ?
    '- Derive every binding path only from the exact structure present in dataSnapshot in the user task. The host ' +
      'checks that each path exists in that sampled snapshot. Prefer the narrowest path whose value shape matches ' +
      'the component; never bind a whole result object when a relevant child value is available.\n' :
    '- Bind content only through exact paths explicitly listed in the user task. A listed parent path does not allow ' +
      'an unlisted descendant path. Prefer the narrowest allowed path whose value shape matches the component. Never ' +
      'bind a whole result object when a relevant child array is available.\n';
  const repeatedCollectionRules = isUiLabCatalog ?
    '- For repeated array items, use the official A2UI v0.9 List shape ' +
      '{"children":{"path":"/allowed/array/path","componentId":"item-template"}}. The referenced template is one ' +
      'component rendered once per item; never replace this dynamic children object with a static children array. ' +
      'Every path or dataPath inside that template and all of its descendants is relative to the current array item ' +
      'scope. Never repeat the absolute collection path or append an array index such as /0 inside the template. ' +
      'Use List for repeated named entities. Its optional title may distinguish adjacent collections from different ' +
      'tool results. Choose the simplest template that expresses each entity. Use InfoRows for a single fact table or ' +
      'presentation-ready label/value rows. InfoRows supports two source modes. When dataPath points ' +
      'to an ordinary object, omit labelPath, valuePath, and timePath; the renderer turns that object own fields into rows. ' +
      'Never invent /key or /value for an ordinary object. When dataPath points to an object array, it may be a ' +
      'presentation-ready Array<{label,value,time?}> or use paired labelPath/valuePath plus optional timePath. Mapping ' +
      'paths must start with "/", be relative to each array item rather than the root snapshot, and name fields that ' +
      'actually exist in the sampled items. When one summary or description line is sufficient, use a compact Text ' +
      'template bound only to that field. When an item has multiple selected details and collapsing them materially ' +
      'shortens the page, use ExpandableCard direct rows. Each row label may be literal or path-bound, while each business ' +
      'value must be path-only; all paths remain relative to the item scope. Omitting dataPath must not expose the current ' +
      'item. body and legacy dataPath remain compatible, but do not generate dataPath="/", bind an entire item/provider ' +
      'object, or combine rows with dataPath.\n' :
    '- For repeated array items, use the official A2UI v0.9 List shape ' +
      '{"children":{"path":"/allowed/array/path","componentId":"item-template"}}. The referenced template is one ' +
      'component rendered once per item. For repeated entity results, use List with one ExpandableCard template so ' +
      'each result gets its own card. The template may omit dataPath (or use "/") to read the current item scope. Do not ' +
      'replace this dynamic children object with a static children array.\n';
  const outputContractRules = decisionNotesEnabled && isUiLabCatalog ?
    '- Begin with the exact standalone line <ui_decision_notes>. Write a bounded natural-language UI decision summary ' +
      'on the following line or lines, then write the exact standalone line </ui_decision_notes>. After the closing tag, ' +
      'output exactly one compact A2UI updateComponents JSON line. Do not use markdown, code fences, text outside the ' +
      'tagged block, or extra lines after the protocol.\n' +
      '- The natural-language summary must contain exactly two labeled stages in this order. First, “我拿到了哪些数据”: ' +
      'enumerate every meaningful DataResult field or array grouping, give its exact JSON Pointer, and briefly describe ' +
      'what the data means. Second, “我要把它们放到什么组件里”: map every inventoried path or grouping to the selected ' +
      'component and briefly explain why that component fits. Keep the summary at most 2400 characters and do not copy ' +
      'raw provider values unnecessarily.\n' +
      '- UI decision notes are a bounded presentation summary only. Never provide hidden reasoning, chain-of-thought, ' +
      'private deliberation, or step-by-step analysis.\n' :
    '- Output exactly one compact JSON line. No markdown or explanation.\n';
  return `You plan one constrained A2UI ${A2UI_VERSION} component layout for a mobile UI renderer.\n` +
    'Rules:\n' +
    outputContractRules +
    `- The only envelope is updateComponents for surfaceId "${surfaceId}".\n` +
    '- Never output createSurface, updateDataModel, deleteSurface, provider facts, action IDs, or action args.\n' +
    '- The root component id must be "root" and all children must form one connected acyclic tree.\n' +
    dataPathRules +
    uiLabRules +
    repeatedCollectionRules +
    '- An action slot contains only {"offerId":"an offered id"}; never invent or alter an offer.\n' +
    '- The catalog schema is the only field and value-policy authority. Output only fields declared for that component. ' +
    'For valuePolicy "literal-or-path", output either a literal of the declared type or exactly {"path":"/an/exact/path"}. ' +
    'Visible field example: title:{"path":"/summary/title"} is correct; title:"/summary/title" is wrong. ' +
    'Path declaration fields stay strings: dataPath:"/items", labelPath:"/label", valuePath:"/value", timePath:"/time". ' +
    'For "path-only", output only that exact one-key binding object: never output a numeric literal, numeric string, ' +
    'expression, FunctionCall, or binding with extra keys. For literal arrays and objects, follow their nested fields recursively.\n' +
    '- Component names and properties are direct members of each component object. Use "component", never "type", ' +
    'and never place properties inside a nested "props" or "properties" object.\n' +
    outputExampleSection +
    '- Keep at most 24 components. Use only this catalog:\n' +
    componentCatalogJson;
}

export class OpenAiA2uiModel implements A2uiModel {
  private provider: LlmProvider;
  private componentCatalogJson: string;
  private decisionNotesEnabled: () => boolean;

  constructor(
    provider: LlmProvider,
    componentCatalogJson: string = AIPHONE_COMPONENT_CATALOG_JSON,
    decisionNotesEnabled: () => boolean = (): boolean => false
  ) {
    this.provider = provider;
    this.componentCatalogJson = componentCatalogJson;
    this.decisionNotesEnabled = decisionNotesEnabled;
  }

  async generate(
    userTask: string,
    surfaceId: string,
    conversation?: ConversationContext,
    onTextDelta?: A2uiTextDeltaListener
  ): Promise<string> {
    if (!this.provider.isConfigured()) {
      throw new Error('LLM provider is not configured.');
    }

    const httpRequest = http.createHttp();
    const decoder = util.TextDecoder.create('utf-8');
    const sseParser = new ChatCompletionSseParser();
    const rawChunks: string[] = [];
    const contentParts: string[] = [];
    let streamParseError: Error | null = null;
    let streamEndResolve: () => void = () => {};
    const streamEnd = new Promise<void>((resolve: () => void) => {
      streamEndResolve = resolve;
    });
    httpRequest.on('dataReceive', (data: ArrayBuffer) => {
      const chunk = decoder.decodeToString(new Uint8Array(data), { stream: true });
      rawChunks.push(chunk);
      if (streamParseError === null) {
        try {
          this.consumeSsePayloads(sseParser.feed(chunk), contentParts, onTextDelta);
        } catch (error) {
          streamParseError = new Error(this.describeThrown(error));
        }
      }
    });
    httpRequest.on('dataEnd', () => {
      streamEndResolve();
    });
    try {
      const statusCode = await httpRequest.requestInStream(this.provider.chatCompletionsUrl(), {
        method: http.RequestMethod.POST,
        header: {
          'Authorization': `Bearer ${this.provider.apiKey}`,
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'text/event-stream'
        },
        extraData: buildA2uiChatRequestJson(
          this.buildRequest(userTask, surfaceId, conversation),
          this.provider.customParametersJson
        ),
        connectTimeout: 20000,
        readTimeout: 120000
      });
      streamEndResolve();
      await streamEnd;
      const decoderTail: string = decoder.decodeToString(new Uint8Array(0), { stream: false });
      if (decoderTail.length > 0) {
        rawChunks.push(decoderTail);
      }
      if (streamParseError === null) {
        try {
          this.consumeSsePayloads(sseParser.feed(decoderTail), contentParts, onTextDelta);
          this.consumeSsePayloads(sseParser.finish(), contentParts, onTextDelta);
        } catch (error) {
          streamParseError = new Error(this.describeThrown(error));
        }
      }

      const body = rawChunks.join('');
      if (statusCode < 200 || statusCode >= 300) {
        throw new Error(`LLM request failed with HTTP ${statusCode}: ${body}`);
      }
      if (streamParseError !== null) {
        throw streamParseError;
      }

      let content = contentParts.join('').trim();
      if (content.length === 0) {
        content = this.parseContent(body).trim();
        if (content.length > 0 && onTextDelta !== undefined) {
          onTextDelta(content);
        }
      }
      aiLogInfo('[A2uiLayoutRaw] surface=' + surfaceId + ' output=' + JSON.stringify(content));
      return content;
    } catch (error) {
      const message = error instanceof Error ? error.message : `${error}`;
      throw new Error(`A2UI LLM request failed: ${message}`);
    } finally {
      httpRequest.destroy();
    }
  }

  private buildRequest(userTask: string, surfaceId: string, conversation?: ConversationContext): ChatRequest {
    const systemPrompt = buildA2uiLayoutSystemPrompt(
      surfaceId,
      this.componentCatalogJson,
      this.decisionNotesEnabled()
    );

    const messages: ChatMessage[] = [
      { role: 'system', content: systemPrompt }
    ];

    if (conversation !== undefined) {
      const history = conversation.toChatMessages();
      for (const turn of history) {
        messages.push(turn);
      }
    }

    messages.push({
      role: 'user',
      content: userTask
    });

    return {
      model: this.provider.model,
      messages,
      temperature: 0.2,
      stream: true
    };
  }

  private consumeSsePayloads(
    payloads: string[],
    contentParts: string[],
    onTextDelta?: A2uiTextDeltaListener
  ): void {
    for (let index = 0; index < payloads.length; index++) {
      const payload: string = payloads[index];
      if (payload.length === 0 || payload === '[DONE]') {
        continue;
      }
      const event = JSON.parse(payload) as ChatStreamResponse;
      const choices = event.choices;
      if (choices === undefined || choices.length === 0 || choices[0].delta === undefined) {
        continue;
      }
      const deltaContent = choices[0].delta?.content;
      if (typeof deltaContent === 'string' && deltaContent.length > 0) {
        contentParts.push(deltaContent);
        if (onTextDelta !== undefined) {
          onTextDelta(deltaContent);
        }
      }
    }
  }

  private describeThrown(error: Error | Object | string | number | boolean | null | undefined): string {
    if (error instanceof Error) {
      return error.message;
    }
    if (error === undefined || error === null) {
      return `${error}`;
    }
    try {
      const json = JSON.stringify(error);
      if (json !== undefined && json.length > 0 && json !== '{}') {
        return json;
      }
    } catch (_jsonError) {
    }
    return `${error}`;
  }

  private parseContent(body: string): string {
    const trimmed = body.trim();
    if (trimmed.startsWith('{')) {
      return this.parseJsonContent(trimmed);
    }

    const contentParts: string[] = [];
    const parser = new ChatCompletionSseParser();
    this.consumeSsePayloads(parser.feed(body), contentParts);
    this.consumeSsePayloads(parser.finish(), contentParts);
    const content = contentParts.join('');
    if (content.length === 0) {
      throw new Error('No streaming message content returned.');
    }
    return content;
  }

  private parseJsonContent(body: string): string {
    const json = JSON.parse(body) as ChatResponse;
    const choices = json.choices;
    if (choices === undefined || choices.length === 0) {
      throw new Error('No choices returned.');
    }

    const message = choices[0].message;
    if (message === undefined || message.content === undefined) {
      throw new Error('No message content returned.');
    }
    return message.content;
  }
}
