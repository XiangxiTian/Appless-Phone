import { common } from '@kit.AbilityKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { http } from '@kit.NetworkKit';
import { systemShare } from '@kit.ShareKit';

const WATERFALL_SHARE_ENDPOINT: string = 'https://jiuwenappless.com/v1/waterfall/shares';

type ShareValue = Object | string | number | boolean | null | undefined;

interface RawWaterfallShareRequest {
  title?: ShareValue;
  summary?: ShareValue;
  source?: ShareValue;
  author?: ShareValue;
  coverUrl?: ShareValue;
  mediaType?: ShareValue;
  mediaUrl?: ShareValue;
  format?: ShareValue;
  originalUrl?: ShareValue;
  publishedAt?: ShareValue;
}

interface RawWaterfallShareResponse {
  ok?: ShareValue;
  url?: ShareValue;
}

export interface WaterfallShareRequest {
  title: string;
  summary: string;
  source: string;
  author: string;
  coverUrl: string;
  mediaType: string;
  mediaUrl: string;
  format: string;
  originalUrl: string;
  publishedAt: string;
}

export type WaterfallShareStatus = 'ready' | 'fallback';

function text(value: ShareValue, limit: number): string {
  if (typeof value !== 'string') return '';
  return value.trim().substring(0, limit);
}

function publicUrl(value: ShareValue, cover: boolean = false): string {
  const url = text(value, 2048);
  if (url.startsWith('https://') || (!cover && url.startsWith('http://'))) return url;
  return '';
}

export function parseWaterfallShareRequest(raw: string): WaterfallShareRequest | null {
  try {
    const value = JSON.parse(raw) as RawWaterfallShareRequest;
    const source = text(value.source, 80);
    const mediaType = text(value.mediaType, 24);
    const format = text(value.format, 24);
    const request: WaterfallShareRequest = {
      title: text(value.title, 160) || (source.length > 0 ? source + ' 内容' : '分享内容'),
      summary: text(value.summary, 600),
      source,
      author: text(value.author, 120),
      coverUrl: publicUrl(value.coverUrl, true),
      mediaType: ['video', 'image_text', 'post'].indexOf(mediaType) >= 0 ? mediaType : '',
      mediaUrl: publicUrl(value.mediaUrl),
      format: ['landscape_video', 'portrait_video', 'image_text', 'text'].indexOf(format) >= 0 ? format : '',
      originalUrl: publicUrl(value.originalUrl),
      publishedAt: text(value.publishedAt, 40)
    };
    return request.originalUrl.length > 0 ? request : null;
  } catch (_error) {
    return null;
  }
}

export function waterfallShareLinkFromResponse(raw: string): string {
  try {
    const response = JSON.parse(raw) as RawWaterfallShareResponse;
    const link = text(response.url, 256);
    return response.ok === true && /^https:\/\/jiuwenappless\.com\/s\/[A-Za-z0-9_-]{12}$/.test(link) ? link : '';
  } catch (_error) {
    return '';
  }
}

async function createWaterfallShareLink(snapshot: WaterfallShareRequest): Promise<string> {
  const request = http.createHttp();
  try {
    const response = await request.request(WATERFALL_SHARE_ENDPOINT, {
      method: http.RequestMethod.POST,
      header: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
      extraData: JSON.stringify(snapshot),
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 5000,
      readTimeout: 7000
    });
    if (response.responseCode < 200 || response.responseCode >= 300) return '';
    return waterfallShareLinkFromResponse(typeof response.result === 'string' ? response.result : '');
  } finally {
    request.destroy();
  }
}

export async function shareWaterfallCard(
  context: common.UIAbilityContext,
  raw: string
): Promise<WaterfallShareStatus> {
  const snapshot = parseWaterfallShareRequest(raw);
  if (snapshot === null) throw new Error('waterfall_share_invalid_card');
  let link = '';
  try {
    link = await createWaterfallShareLink(snapshot);
  } catch (_error) {
  }
  const status: WaterfallShareStatus = link.length > 0 ? 'ready' : 'fallback';
  const sharedData = new systemShare.SharedData({
    utd: utd.UniformDataType.HYPERLINK,
    content: link.length > 0 ? link : snapshot.originalUrl,
    title: snapshot.title,
    description: snapshot.summary
  });
  const controller = new systemShare.ShareController(sharedData);
  await controller.show(context, {
    selectionMode: systemShare.SelectionMode.SINGLE,
    previewMode: systemShare.SharePreviewMode.DETAIL
  });
  return status;
}
