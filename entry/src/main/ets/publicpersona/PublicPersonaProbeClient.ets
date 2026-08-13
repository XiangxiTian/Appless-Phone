import http from '@ohos.net.http';
import { aiLogInfo } from '@loop/agent-core';
import {
  PublicPersonaIdentity,
  PublicPersonaProbe,
  PublicPersonaProbeState,
  classifyPublicPersonaProbe,
  parsePublicProfileUrl,
  publicPersonaProfileUrl,
  publicPersonaUsernameFromProfileUrl
} from './PublicPersonaModel';

const MAX_PROFILE_BODY_CHARS: number = 500000;
const MAX_LINKED_PROFILES: number = 10;
const MOBILE_USER_AGENT: string =
  'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 Chrome/124.0 Mobile Safari/537.36';
const X_PUBLIC_WEB_BEARER: string =
  'Bearer AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D' +
  '1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA';

type PublicPersonaProbeRecord = Record<string, Object | string | number | boolean | null>;

export interface PublicPersonaRequestHeaders {
  'Accept': string;
  'User-Agent': string;
  'Referer'?: string;
  'Content-Type'?: string;
  'Cookie'?: string;
  'Authorization'?: string;
  'x-guest-token'?: string;
}

export interface PublicPersonaHttpResult {
  statusCode: number;
  body: string;
}

interface LeetCodeVariables {
  username: string;
}

interface LeetCodeRequest {
  query: string;
  variables: LeetCodeVariables;
}

interface LeetCodeCnVariables {
  userSlug: string;
}

interface LeetCodeCnRequest {
  query: string;
  variables: LeetCodeCnVariables;
}

export type PublicPersonaHttpCaller = (
  url: string,
  headers?: Record<string, string>
) => Promise<PublicPersonaHttpResult>;
export type PublicPersonaRawHttpCaller = (
  url: string,
  method: string,
  headers: PublicPersonaRequestHeaders,
  body: string
) => Promise<PublicPersonaHttpResult>;

export interface PublicPersonaNativeProbeResult {
  state: PublicPersonaProbeState;
  identity: PublicPersonaIdentity | null;
  bio: string;
  sourceUrls: string[];
}

function httpResult(statusCode: number, body: string): PublicPersonaHttpResult {
  return { statusCode: statusCode, body: body };
}

function requestHeaders(url: string): PublicPersonaRequestHeaders {
  if (url.indexOf('douban.com/people/') >= 0) {
    return { 'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
      'User-Agent': 'Mozilla/5.0 Chrome/124.0' };
  }
  if (url.indexOf('behance.net/') >= 0) {
    return { 'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8', 'User-Agent': 'Curl' };
  }
  if (url.indexOf('weibo.com/ajax/') >= 0) {
    return { 'Accept': 'application/json', 'User-Agent': MOBILE_USER_AGENT, 'Referer': 'https://weibo.com/' };
  }
  if (url.indexOf('api.github.com/') >= 0) {
    return { 'Accept': 'application/vnd.github+json', 'User-Agent': MOBILE_USER_AGENT };
  }
  return { 'Accept': 'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8',
    'User-Agent': MOBILE_USER_AGENT };
}

function mergedHeaders(
  base: PublicPersonaRequestHeaders,
  overrides: Record<string, string> | undefined
): PublicPersonaRequestHeaders {
  if (overrides === undefined) return base;
  const baseRecord = base as Object as PublicPersonaProbeRecord;
  const overrideRecord = overrides as Object as PublicPersonaProbeRecord;
  const accept = recordText(overrideRecord, 'Accept');
  const userAgent = recordText(overrideRecord, 'User-Agent');
  const referer = recordText(overrideRecord, 'Referer');
  const contentType = recordText(overrideRecord, 'Content-Type');
  const cookie = recordText(overrideRecord, 'Cookie');
  const authorization = recordText(overrideRecord, 'Authorization');
  const guestToken = recordText(overrideRecord, 'x-guest-token');
  return {
    'Accept': accept.length > 0 ? accept : recordText(baseRecord, 'Accept'),
    'User-Agent': userAgent.length > 0 ? userAgent : recordText(baseRecord, 'User-Agent'),
    'Referer': referer.length > 0 ? referer : recordText(baseRecord, 'Referer'),
    'Content-Type': contentType.length > 0 ? contentType : recordText(baseRecord, 'Content-Type'),
    'Cookie': cookie.length > 0 ? cookie : recordText(baseRecord, 'Cookie'),
    'Authorization': authorization.length > 0 ? authorization : recordText(baseRecord, 'Authorization'),
    'x-guest-token': guestToken.length > 0 ? guestToken : recordText(baseRecord, 'x-guest-token')
  };
}

async function requestProfileUrl(
  url: string,
  method: string = 'GET',
  headers: PublicPersonaRequestHeaders = requestHeaders(url),
  body: string = ''
): Promise<PublicPersonaHttpResult> {
  const request = http.createHttp();
  try {
    const response = await request.request(url, {
      method: method === 'POST' ? http.RequestMethod.POST : http.RequestMethod.GET,
      header: headers,
      extraData: body.length > 0 ? body : undefined,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 10000,
      readTimeout: 20000
    });
    const responseBody = typeof response.result === 'string' ? response.result : String(response.result);
    return httpResult(response.responseCode, responseBody.substring(0, MAX_PROFILE_BODY_CHARS));
  } finally {
    request.destroy();
  }
}

export async function requestPublicPersonaProfile(
  url: string,
  rawHttpCaller: PublicPersonaRawHttpCaller = requestProfileUrl,
  headerOverrides?: Record<string, string>
): Promise<PublicPersonaHttpResult> {
  const leetCodeCnMarker = 'https://leetcode.cn/graphql/?userSlug=';
  if (url.indexOf(leetCodeCnMarker) === 0) {
    const userSlug = url.substring(leetCodeCnMarker.length);
    const headers: PublicPersonaRequestHeaders = mergedHeaders({
      'Accept': 'application/json',
      'User-Agent': MOBILE_USER_AGENT,
      'Content-Type': 'application/json'
    }, headerOverrides);
    const request: LeetCodeCnRequest = {
      query: 'query userPublicProfile($userSlug: String!) {' +
        ' userProfilePublicProfile(userSlug: $userSlug) {' +
        ' username profile { realName userAvatar aboutMe } } }',
      variables: { userSlug: userSlug }
    };
    return rawHttpCaller('https://leetcode.cn/graphql/', 'POST', headers, JSON.stringify(request));
  }
  const leetCodeMarker = 'https://leetcode.com/graphql/?username=';
  if (url.indexOf(leetCodeMarker) === 0) {
    const username = url.substring(leetCodeMarker.length);
    const headers: PublicPersonaRequestHeaders = mergedHeaders({
      'Accept': 'application/json',
      'User-Agent': MOBILE_USER_AGENT,
      'Content-Type': 'application/json'
    }, headerOverrides);
    const request: LeetCodeRequest = {
      query: 'query userPublicProfile($username: String!) {' +
        ' matchedUser(username: $username) { username profile { realName userAvatar aboutMe } } }',
      variables: { username: username }
    };
    const body = JSON.stringify(request);
    return rawHttpCaller('https://leetcode.com/graphql/', 'POST', headers, body);
  }
  if (url.indexOf('twitter.com/i/api/graphql/') >= 0) {
    const activationHeaders: PublicPersonaRequestHeaders = mergedHeaders({
      'Accept': 'application/json',
      'User-Agent': MOBILE_USER_AGENT,
      'Authorization': X_PUBLIC_WEB_BEARER
    }, headerOverrides);
    const activation = await rawHttpCaller(
      'https://api.twitter.com/1.1/guest/activate.json', 'POST', activationHeaders, '');
    const root = jsonRecord(activation.body);
    const guestToken = root === null ? '' : recordText(root, 'guest_token');
    if (guestToken.length === 0) {
      return activation;
    }
    const profileHeaders: PublicPersonaRequestHeaders = mergedHeaders({
      'Accept': 'application/json',
      'User-Agent': MOBILE_USER_AGENT,
      'Authorization': X_PUBLIC_WEB_BEARER,
      'x-guest-token': guestToken
    }, headerOverrides);
    const profile = await rawHttpCaller(url, 'GET', profileHeaders, '');
    if (profile.statusCode !== 403 || profile.body.toLowerCase().indexOf('bad guest token') < 0) {
      return profile;
    }
    const refreshedActivation = await rawHttpCaller(
      'https://api.twitter.com/1.1/guest/activate.json', 'POST', activationHeaders, '');
    const refreshedRoot = jsonRecord(refreshedActivation.body);
    const refreshedGuestToken = refreshedRoot === null ? '' : recordText(refreshedRoot, 'guest_token');
    if (refreshedGuestToken.length === 0) {
      return refreshedActivation;
    }
    return rawHttpCaller(url, 'GET', {
      'Accept': 'application/json',
      'User-Agent': MOBILE_USER_AGENT,
      'Authorization': X_PUBLIC_WEB_BEARER,
      'x-guest-token': refreshedGuestToken
    }, '');
  }
  if (url.indexOf('weibo.com/ajax/') >= 0) {
    const activationHeaders: PublicPersonaRequestHeaders = {
      'Accept': 'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8',
      'User-Agent': MOBILE_USER_AGENT,
      'Content-Type': 'application/x-www-form-urlencoded'
    };
    const activation = await rawHttpCaller(
      'https://passport.weibo.com/visitor/genvisitor2',
      'POST',
      activationHeaders,
      'cb=visitor_gray_callback&tid=&from=weibo'
    );
    const jsonMatch = /\{[\s\S]*\}/.exec(activation.body);
    const root = jsonMatch === null ? null : jsonRecord(jsonMatch[0]);
    const data = root === null ? null : childRecord(root, 'data');
    const sub = data === null ? '' : recordText(data, 'sub');
    const subp = data === null ? '' : recordText(data, 'subp');
    if (sub.length === 0 || subp.length === 0) {
      return httpResult(activation.statusCode, activation.body);
    }
    const profileHeaders: PublicPersonaRequestHeaders = mergedHeaders({
      'Accept': 'application/json',
      'User-Agent': MOBILE_USER_AGENT,
      'Referer': 'https://weibo.com/',
      'Cookie': 'SUB=' + sub + '; SUBP=' + subp
    }, headerOverrides);
    return rawHttpCaller(url, 'GET', profileHeaders, '');
  }
  return rawHttpCaller(url, 'GET', mergedHeaders(requestHeaders(url), headerOverrides), '');
}

export async function publicPersonaHttpCaller(
  url: string,
  headers?: Record<string, string>
): Promise<PublicPersonaHttpResult> {
  return requestPublicPersonaProfile(url, requestProfileUrl, headers);
}

function emptyProbeResult(state: PublicPersonaProbeState): PublicPersonaNativeProbeResult {
  return { state: state, identity: null, bio: '', sourceUrls: [] };
}

function requestErrorCategory(error: Object | string | null | undefined): string {
  const text = typeof error === 'string' ? error.toLowerCase() :
    typeof error === 'object' && error !== null ?
      String((error as Record<string, Object>)['code'] ?? '') + ' ' +
        String((error as Record<string, Object>)['message'] ?? '') : String(error ?? '');
  const normalized = text.toLowerCase();
  if (normalized.indexOf('42') >= 0 || normalized.indexOf('abort') >= 0) return 'aborted';
  if (normalized.indexOf('timeout') >= 0 || normalized.indexOf('timed out') >= 0) return 'timeout';
  if (normalized.indexOf('dns') >= 0 || normalized.indexOf('resolve') >= 0) return 'dns';
  if (normalized.indexOf('tls') >= 0 || normalized.indexOf('ssl') >= 0 ||
    normalized.indexOf('certificate') >= 0) return 'tls';
  return 'client_error';
}

function htmlAttribute(tag: string, name: string): string {
  const quoted = new RegExp('(?:^|\\s)' + name + '\\s*=\\s*(["\\\'])(.*?)\\1', 'i').exec(tag);
  if (quoted !== null && quoted.length > 2) {
    return quoted[2].trim().replace(/&amp;/g, '&');
  }
  const bare = new RegExp('(?:^|\\s)' + name + '\\s*=\\s*([^\\s>]+)', 'i').exec(tag);
  return bare === null || bare.length < 2 ? '' : bare[1].trim().replace(/&amp;/g, '&');
}

function metaContent(html: string, key: string): string {
  const tags = html.match(/<meta\b[^>]*>/gi) ?? [];
  const normalizedKey = key.toLowerCase();
  for (let index = 0; index < tags.length; index++) {
    const name = htmlAttribute(tags[index], 'property').toLowerCase();
    const fallbackName = htmlAttribute(tags[index], 'name').toLowerCase();
    if (name === normalizedKey || fallbackName === normalizedKey) {
      return htmlAttribute(tags[index], 'content');
    }
  }
  return '';
}

function canonicalUrl(html: string): string {
  const tags = html.match(/<link\b[^>]*>/gi) ?? [];
  for (let index = 0; index < tags.length; index++) {
    if (htmlAttribute(tags[index], 'rel').toLowerCase() === 'canonical') {
      return htmlAttribute(tags[index], 'href');
    }
  }
  return '';
}

function htmlTitle(html: string): string {
  const match = /<title\b[^>]*>([\s\S]*?)<\/title>/i.exec(html);
  return match === null || match.length < 2 ? '' : match[1].replace(/<[^>]+>/g, '').trim();
}

function validHttpsImage(value: string): string {
  const trimmed = value.trim();
  return trimmed.startsWith('https://') && trimmed.indexOf(' ') < 0 ? trimmed : '';
}

function qqProbeResult(
  body: string,
  displayUrl: string,
  username: string
): PublicPersonaNativeProbeResult | null {
  const match = new RegExp('"' + username + '"\\s*:\\s*\\[\\s*"([^"]+)"[\\s\\S]*,"([^"]*)",0\\s*\\]').exec(body);
  if (match === null || match.length < 3) return null;
  const expectedPath = '/qzone/' + username + '/' + username + '/';
  let avatarUrl = match[1].replace(/\\\//g, '/');
  if (match[2].trim().length === 0) return emptyProbeResult('not_found');
  if (avatarUrl.startsWith('http://') && avatarUrl.indexOf('.store.qq.com' + expectedPath) > 0) {
    avatarUrl = 'https://' + avatarUrl.substring('http://'.length);
  }
  avatarUrl = validHttpsImage(avatarUrl);
  if (avatarUrl.length === 0 || avatarUrl.indexOf(expectedPath) < 0) return null;
  return {
    state: 'found',
    identity: {
      displayName: match[2].trim() || username,
      username: username,
      avatarUrl: avatarUrl,
      canonicalUrl: displayUrl,
      linkedUrls: []
    },
    bio: '',
    sourceUrls: [displayUrl]
  };
}

function xmlElement(body: string, name: string): string {
  const match = new RegExp('<' + name + '>(?:<!\\[CDATA\\[)?([\\s\\S]*?)(?:\\]\\]>)?<\\/' + name + '>', 'i').exec(body);
  return match === null || match.length < 2 ? '' : match[1].trim().replace(/&amp;/g, '&');
}

function mediumProbeResult(
  body: string,
  requestedUsername: string
): PublicPersonaNativeProbeResult | null {
  const rawLink = xmlElement(body, 'link');
  const queryIndex = rawLink.indexOf('?');
  const canonical = queryIndex < 0 ? rawLink : rawLink.substring(0, queryIndex);
  const parsed = parsePublicProfileUrl(canonical);
  const username = parsed === null ? '' : publicPersonaUsernameFromProfileUrl(parsed.url);
  const avatarUrl = validHttpsImage(xmlElement(body, 'url'));
  if (parsed?.platform !== 'medium' || username.toLowerCase() !== requestedUsername.toLowerCase() ||
    avatarUrl.length === 0) return null;
  const title = xmlElement(body, 'title');
  const nameMatch = /^Stories by (.+) on Medium$/i.exec(title);
  return {
    state: 'found',
    identity: {
      displayName: nameMatch === null ? username : nameMatch[1].trim(),
      username: username,
      avatarUrl: avatarUrl,
      canonicalUrl: parsed.url,
      linkedUrls: []
    },
    bio: xmlElement(body, 'description'),
    sourceUrls: [parsed.url]
  };
}

function jsonRecord(body: string): PublicPersonaProbeRecord | null {
  try {
    const parsed = JSON.parse(body) as Object;
    return typeof parsed === 'object' && parsed !== null && !Array.isArray(parsed) ?
      parsed as PublicPersonaProbeRecord : null;
  } catch (_error) {
    return null;
  }
}

function jsonRecords(body: string): PublicPersonaProbeRecord[] | null {
  try {
    const parsed = JSON.parse(body) as Object;
    if (!Array.isArray(parsed)) return null;
    const raw = parsed as Object[];
    const records: PublicPersonaProbeRecord[] = [];
    for (let index = 0; index < raw.length; index++) {
      if (typeof raw[index] === 'object' && raw[index] !== null && !Array.isArray(raw[index])) {
        records.push(raw[index] as PublicPersonaProbeRecord);
      }
    }
    return records;
  } catch (_error) {
    return null;
  }
}

function recordText(record: PublicPersonaProbeRecord, key: string): string {
  const value = record[key];
  return typeof value === 'string' ? value.trim() : '';
}

function childRecord(record: PublicPersonaProbeRecord, key: string): PublicPersonaProbeRecord | null {
  const value = record[key];
  return typeof value === 'object' && value !== null && !Array.isArray(value) ?
    value as PublicPersonaProbeRecord : null;
}

function firstChildRecord(record: PublicPersonaProbeRecord, key: string): PublicPersonaProbeRecord | null {
  const value = record[key];
  if (!Array.isArray(value) || value.length === 0) return null;
  const values = value as Object[];
  const first: Object = values[0];
  return typeof first === 'object' && first !== null && !Array.isArray(first) ?
    first as PublicPersonaProbeRecord : null;
}

function npmProbeResult(
  body: string,
  requestedUsername: string
): PublicPersonaNativeProbeResult | null {
  const root = jsonRecord(body);
  const rawObjects = root === null ? null : root['objects'];
  if (!Array.isArray(rawObjects)) return null;
  if (rawObjects.length === 0) return emptyProbeResult('not_found');
  const expected = requestedUsername.toLowerCase();
  const objects = rawObjects as Object[];
  for (let index = 0; index < objects.length; index++) {
    if (typeof objects[index] !== 'object' || objects[index] === null || Array.isArray(objects[index])) continue;
    const item = objects[index] as PublicPersonaProbeRecord;
    const packageRecord = childRecord(item, 'package');
    if (packageRecord === null) continue;
    const publisher = childRecord(packageRecord, 'publisher');
    let matches = publisher !== null && recordText(publisher, 'username').toLowerCase() === expected;
    const maintainers = packageRecord['maintainers'];
    if (!matches && Array.isArray(maintainers)) {
      const values = maintainers as Object[];
      for (let maintainerIndex = 0; maintainerIndex < values.length; maintainerIndex++) {
        if (typeof values[maintainerIndex] !== 'object' || values[maintainerIndex] === null ||
          Array.isArray(values[maintainerIndex])) continue;
        if (recordText(values[maintainerIndex] as PublicPersonaProbeRecord, 'username').toLowerCase() === expected) {
          matches = true;
          break;
        }
      }
    }
    if (!matches) continue;
    const canonical = 'https://www.npmjs.com/~' + requestedUsername;
    return {
      state: 'found',
      identity: {
        displayName: requestedUsername,
        username: requestedUsername,
        avatarUrl: '',
        canonicalUrl: canonical,
        linkedUrls: []
      },
      bio: recordText(packageRecord, 'description'),
      sourceUrls: [canonical]
    };
  }
  return body.indexOf('"total":0') >= 0 ? emptyProbeResult('not_found') : emptyProbeResult('unknown');
}

function jsonPathValue(
  root: Object,
  path: string[]
): Object | string | number | boolean | null {
  let value: Object | string | number | boolean | null = root;
  for (let index = 0; index < path.length; index++) {
    if (Array.isArray(value)) {
      const values = value as Object[];
      const arrayIndex = Number(path[index]);
      if (!Number.isInteger(arrayIndex) || arrayIndex < 0 || arrayIndex >= values.length) return null;
      value = values[arrayIndex];
    } else if (typeof value === 'object' && value !== null) {
      value = (value as PublicPersonaProbeRecord)[path[index]] ?? null;
    } else {
      return null;
    }
  }
  return value;
}

function jsonPathText(root: Object, path: string[]): string {
  const value = jsonPathValue(root, path);
  return typeof value === 'string' ? value.trim() : '';
}

function genericJsonProbeResult(
  probe: PublicPersonaProbe,
  body: string,
  displayUrl: string,
  requestedUsername: string
): PublicPersonaNativeProbeResult | null {
  const identity = probe.jsonIdentity;
  const root = jsonRecord(body);
  if (identity === undefined || root === null) return null;
  const payloadValue = jsonPathValue(root, identity.rootPath);
  if (typeof payloadValue !== 'object' || payloadValue === null || Array.isArray(payloadValue)) return null;
  const payload = payloadValue as PublicPersonaProbeRecord;
  const responseUsername = probe.platform === 'matrix' ? requestedUsername :
    jsonPathText(payload, identity.usernamePath);
  const expectedUsername = requestedUsername + (identity.usernameSuffix ?? '');
  const sameUsername = probe.caseSensitiveUsername ? responseUsername === expectedUsername :
    responseUsername.toLowerCase() === expectedUsername.toLowerCase();
  if (!sameUsername) return null;
  let avatarUrl = jsonPathText(payload, identity.avatarPath);
  if (probe.platform === 'tieba' && avatarUrl.indexOf('tb.') === 0) {
    avatarUrl = 'https://himg.bdimg.com/sys/portrait/item/' + avatarUrl;
  }
  if (probe.platform === 'matrix' && avatarUrl.indexOf('mxc://') === 0) {
    avatarUrl = 'https://matrix-client.matrix.org/_matrix/media/v3/download/' +
      avatarUrl.substring('mxc://'.length);
  }
  if (identity.upgradePicsartAvatar === true && avatarUrl.indexOf('http://cdn') === 0 &&
    avatarUrl.indexOf('.picsart.com/') > 0) {
    avatarUrl = 'https://' + avatarUrl.substring('http://'.length);
  }
  avatarUrl = validHttpsImage(avatarUrl);
  if (avatarUrl.length === 0) return null;
  let canonical = displayUrl;
  if (identity.canonicalUrlPath !== undefined) {
    const parsedCanonical = parsePublicProfileUrl(jsonPathText(payload, identity.canonicalUrlPath));
    if (parsedCanonical?.platform === probe.platform) canonical = parsedCanonical.url;
  }
  return {
    state: 'found',
    identity: {
      displayName: jsonPathText(payload, identity.displayNamePath) || requestedUsername,
      username: requestedUsername,
      avatarUrl: avatarUrl,
      canonicalUrl: canonical,
      linkedUrls: []
    },
    bio: jsonPathText(payload, identity.bioPath),
    sourceUrls: [canonical]
  };
}

function firstBodyUrl(body: string, pattern: RegExp): string {
  const match = pattern.exec(body.replace(/&amp;/g, '&').replace(/\\\//g, '/'));
  return match === null || match.length < 2 ? '' : validHttpsImage(match[1]);
}

function tuchongSite(body: string): PublicPersonaProbeRecord | null {
  const match = /window\.site\s*=\s*(\{[\s\S]*?\});/.exec(body);
  return match === null || match.length < 2 ? null : jsonRecord(match[1]);
}

function htmlAccountAvatar(probe: PublicPersonaProbe, body: string): string {
  if (probe.platform === 'douban') {
    const images = body.match(/<img\b[^>]*>/gi) ?? [];
    for (let index = 0; index < images.length; index++) {
      if (htmlAttribute(images[index], 'class').split(/\s+/).indexOf('userface') >= 0) {
        return validHttpsImage(htmlAttribute(images[index], 'src'));
      }
    }
    return '';
  }
  if (probe.platform === 'gitee') {
    return firstBodyUrl(body, /(https:\/\/foruda\.gitee\.com\/avatar\/[A-Za-z0-9_?&=./%-]+)/i);
  }
  if (probe.platform === 'v2ex') {
    return firstBodyUrl(body, /(https:\/\/cdn\.v2ex\.com\/avatar\/[A-Za-z0-9_?&=./%-]+_large\.png[^"'<>\s]*)/i);
  }
  if (probe.platform === 'tuchong') {
    const site = tuchongSite(body);
    return site === null ? '' : validHttpsImage(recordText(site, 'icon'));
  }
  if (probe.platform === 'behance') {
    return firstBodyUrl(body,
      /(https:\/\/pps\.services\.adobe\.com\/api\/profile\/image\/[A-Za-z0-9_?&=./%-]+)/i);
  }
  if (probe.platform === 'steam') {
    return firstBodyUrl(body, /(https:\/\/[^"'<>\s]+\/[a-f0-9]{40}_full\.jpg)/i);
  }
  return validHttpsImage(metaContent(body, 'og:image'));
}

function youtubeHandleEvidence(body: string, username: string): boolean {
  const expected = ('https://www.youtube.com/@' + username).toLowerCase();
  const canonical = (canonicalUrl(body) || metaContent(body, 'og:url')).toLowerCase();
  if (canonical === expected || canonical === expected + '/about') return true;
  const normalized = body.replace(/\\x22/g, '"').replace(/\\\//g, '/');
  const escaped = username.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const handle = new RegExp('(?:canonicalBaseUrl|vanityChannelUrl|canonicalChannelUrl)\\s*["\\\']?\\s*:\\s*["\\\']' +
    '(?:https?:\\/\\/(?:www\\.)?youtube\\.com)?\\/@' + escaped + '(?:["\\\'/?]|$)', 'i');
  return handle.test(normalized);
}

function htmlProbeResult(
  probe: PublicPersonaProbe,
  body: string,
  displayUrl: string,
  username: string
): PublicPersonaNativeProbeResult | null {
  const site = probe.platform === 'tuchong' ? tuchongSite(body) : null;
  const title = metaContent(body, 'og:title') || htmlTitle(body);
  const normalizedTitle = title.toLowerCase();
  const usernameLower = username.toLowerCase();
  if (probe.platform === 'x' && metaContent(body, 'profile:username').toLowerCase() !== usernameLower) {
    return null;
  }
  const nativeCanonicalProof = probe.platform === 'v2ex' && normalizedTitle.indexOf('› ' + usernameLower) >= 0 ||
    probe.platform === 'tuchong' && site !== null &&
      recordText(site, 'domain').toLowerCase() === usernameLower + '.tuchong.com' ||
    probe.platform === 'telegram' && metaContent(body, 'og:title').toLowerCase() === usernameLower ||
    probe.platform === 'behance' && body.toLowerCase().indexOf('behance.net/' + usernameLower) >= 0 ||
    probe.platform === 'steam' && body.toLowerCase().indexOf(displayUrl.toLowerCase()) >= 0 ||
    probe.platform === 'douban' && body.indexOf(displayUrl) >= 0 ||
    probe.platform === 'keybase' && normalizedTitle.indexOf(usernameLower) === 0 ||
    probe.platform === 'youtube' && youtubeHandleEvidence(body, username);
  const rawCanonical = probe.platform === 'youtube' && youtubeHandleEvidence(body, username) ?
    displayUrl : canonicalUrl(body) || metaContent(body, 'og:url') ||
    (nativeCanonicalProof ? displayUrl : '');
  const canonicalCandidate = parsePublicProfileUrl(rawCanonical);
  const avatarUrl = htmlAccountAvatar(probe, body);
  const canonicalUsername = canonicalCandidate === null ? '' :
    publicPersonaUsernameFromProfileUrl(canonicalCandidate.url);
  const sameUsername = probe.caseSensitiveUsername ? canonicalUsername === username :
    canonicalUsername.toLowerCase() === usernameLower;
  if (avatarUrl.length === 0 || canonicalCandidate === null ||
    canonicalCandidate.platform !== probe.platform || !sameUsername) return null;
  const displayName = site === null ? title : recordText(site, 'name') || title;
  const canonical = canonicalCandidate.url;
  return {
    state: 'found',
    identity: {
      displayName: displayName || username,
      username: username,
      avatarUrl: avatarUrl,
      canonicalUrl: canonical,
      linkedUrls: linkedProfiles(body, canonical)
    },
    bio: metaContent(body, 'og:description') || metaContent(body, 'description'),
    sourceUrls: [canonical]
  };
}

function jsonProbeResult(
  probe: PublicPersonaProbe,
  body: string,
  displayUrl: string,
  requestedUsername: string
): PublicPersonaNativeProbeResult | null {
  if (probe.jsonIdentity !== undefined) {
    return genericJsonProbeResult(probe, body, displayUrl, requestedUsername);
  }
  let root = jsonRecord(body);
  let payload: PublicPersonaProbeRecord;
  if (probe.platform === 'gitlab') {
    const records = jsonRecords(body);
    if (records === null || records.length === 0) return null;
    payload = records[0];
    root = payload;
  } else {
    if (root === null) return null;
    payload = root;
  }
  const rootRecord = root as PublicPersonaProbeRecord;
  let username = requestedUsername;
  let displayName = '';
  let avatarUrl = '';
  let bio = '';
  let canonical = displayUrl;
  const linkedUrls: string[] = [];
  if (probe.platform === 'github') {
    username = recordText(payload, 'login');
    displayName = recordText(payload, 'name');
    avatarUrl = recordText(payload, 'avatar_url');
    bio = recordText(payload, 'bio');
    const candidate = parsePublicProfileUrl(recordText(payload, 'html_url'));
    canonical = candidate === null ? displayUrl : candidate.url;
    const blog = recordText(payload, 'blog');
    if (parsePublicProfileUrl(blog) !== null) linkedUrls.push(blog);
    const twitter = recordText(payload, 'twitter_username');
    if (twitter.length > 0) linkedUrls.push('https://x.com/' + twitter);
  } else if (probe.platform === 'bilibili') {
    const data = childRecord(rootRecord, 'data');
    const card = data === null ? null : childRecord(data, 'card');
    if (card === null) return null;
    payload = card;
    displayName = recordText(payload, 'name');
    avatarUrl = recordText(payload, 'face');
    bio = recordText(payload, 'sign');
  } else if (probe.platform === 'zhihu') {
    username = recordText(payload, 'url_token');
    displayName = recordText(payload, 'name');
    avatarUrl = recordText(payload, 'avatar_url');
    bio = recordText(payload, 'headline');
  } else if (probe.platform === 'weibo') {
    const data = childRecord(rootRecord, 'data');
    const user = data === null ? null : childRecord(data, 'user');
    if (user === null) return null;
    payload = user;
    username = recordText(payload, 'screen_name');
    displayName = recordText(payload, 'screen_name');
    avatarUrl = recordText(payload, 'avatar_hd') || recordText(payload, 'profile_image_url');
    bio = recordText(payload, 'description');
  } else if (probe.platform === 'x') {
    const data = childRecord(rootRecord, 'data');
    const user = data === null ? null : childRecord(data, 'user');
    const result = user === null ? null : childRecord(user, 'result');
    const legacy = user === null ? null :
      (result === null ? childRecord(user, 'legacy') : childRecord(result, 'legacy'));
    if (legacy === null) return null;
    payload = legacy;
    username = recordText(payload, 'screen_name');
    displayName = recordText(payload, 'name');
    avatarUrl = recordText(payload, 'profile_image_url_https');
    bio = recordText(payload, 'description');
    canonical = 'https://x.com/' + username;
  } else if (probe.platform === 'gitlab') {
    username = recordText(payload, 'username');
    displayName = recordText(payload, 'name');
    avatarUrl = recordText(payload, 'avatar_url');
    bio = recordText(payload, 'bio');
    canonical = recordText(payload, 'web_url') || displayUrl;
  } else if (probe.platform === 'bitbucket') {
    username = recordText(payload, 'slug');
    displayName = recordText(payload, 'name');
    const links = childRecord(payload, 'links');
    const avatar = links === null ? null : childRecord(links, 'avatar');
    const html = links === null ? null : childRecord(links, 'html');
    avatarUrl = avatar === null ? '' : recordText(avatar, 'href');
    canonical = html === null ? displayUrl : recordText(html, 'href') || displayUrl;
  } else if (probe.platform === 'dockerhub') {
    username = recordText(payload, 'username');
    displayName = recordText(payload, 'full_name');
    avatarUrl = recordText(payload, 'avatar_url') || recordText(payload, 'gravatar_url');
  } else if (probe.platform === 'stackoverflow') {
    const rawItems = payload['items'];
    if (!Array.isArray(rawItems)) return null;
    const items = rawItems as Object[];
    let item: PublicPersonaProbeRecord | null = null;
    for (let index = 0; index < items.length; index++) {
      if (typeof items[index] !== 'object' || items[index] === null || Array.isArray(items[index])) continue;
      const candidate = items[index] as PublicPersonaProbeRecord;
      if (recordText(candidate, 'display_name').toLowerCase() === requestedUsername.toLowerCase()) {
        item = candidate;
        break;
      }
    }
    if (item === null) return null;
    payload = item;
    username = recordText(payload, 'display_name');
    displayName = username;
    avatarUrl = recordText(payload, 'profile_image');
    canonical = recordText(payload, 'link');
    bio = recordText(payload, 'about_me');
  } else if (probe.platform === 'keybase') {
    const account = firstChildRecord(payload, 'them');
    if (account === null) return null;
    const basics = childRecord(account, 'basics');
    const profile = childRecord(account, 'profile');
    const pictures = childRecord(account, 'pictures');
    const primary = pictures === null ? null : childRecord(pictures, 'primary');
    if (basics === null) return null;
    username = recordText(basics, 'username');
    displayName = profile === null ? recordText(basics, 'username_cased') : recordText(profile, 'full_name');
    avatarUrl = primary === null ? '' : recordText(primary, 'url');
    bio = profile === null ? '' : recordText(profile, 'bio');
  } else {
    return null;
  }
  avatarUrl = validHttpsImage(avatarUrl);
  const sameUsername = probe.caseSensitiveUsername ? username === requestedUsername :
    username.toLowerCase() === requestedUsername.toLowerCase();
  if (!sameUsername || avatarUrl.length === 0) {
    return null;
  }
  return {
    state: 'found',
    identity: {
      displayName: displayName || username,
      username: username,
      avatarUrl: avatarUrl,
      canonicalUrl: canonical,
      linkedUrls: linkedUrls
    },
    bio: bio,
    sourceUrls: [canonical]
  };
}

function linkedProfiles(html: string, canonical: string): string[] {
  const matches = html.match(/https:\/\/[^\s"'<>]+/g) ?? [];
  const result: string[] = [];
  for (let index = 0; index < matches.length && result.length < MAX_LINKED_PROFILES; index++) {
    const value = matches[index].replace(/&amp;/g, '&').replace(/[),.;]+$/, '');
    const queryIndex = value.indexOf('?');
    const hashIndex = value.indexOf('#');
    let end = value.length;
    if (queryIndex >= 0) {
      end = queryIndex;
    }
    if (hashIndex >= 0 && hashIndex < end) {
      end = hashIndex;
    }
    const parsed = parsePublicProfileUrl(value.substring(0, end));
    if (parsed !== null && parsed.url.toLowerCase() !== canonical.toLowerCase() && result.indexOf(parsed.url) < 0) {
      result.push(parsed.url);
    }
  }
  return result;
}

export async function probePublicPersonaProfile(
  probe: PublicPersonaProbe,
  username: string,
  httpCaller: PublicPersonaHttpCaller = publicPersonaHttpCaller
): Promise<PublicPersonaNativeProbeResult> {
  const displayUrl = publicPersonaProfileUrl(probe, username);
  if (displayUrl === null) return emptyProbeResult('unknown');
  const probeUrl = probe.platform === 'weibo' && /^[0-9]+$/.test(username) ?
    'https://weibo.com/ajax/profile/info?uid=' + username : probe.probeUrlTemplate.replace('{username}', username);
  let response: PublicPersonaHttpResult;
  try {
    response = await httpCaller(probeUrl, probe.requestHeaders);
  } catch (_error) {
    const category = requestErrorCategory(typeof _error === 'string' ? _error : _error as Object);
    aiLogInfo(`[AIPhone][PublicPersonaProbeDetail] platform=${probe.platform} stage=request ` +
      `error=${category} state=unknown`);
    return emptyProbeResult('unknown');
  }
  const body = response.body.substring(0, MAX_PROFILE_BODY_CHARS);
  const state = classifyPublicPersonaProbe(probe, response.statusCode, body);
  aiLogInfo(`[AIPhone][PublicPersonaProbeDetail] platform=${probe.platform} stage=classify ` +
    `status=${response.statusCode} state=${state}`);
  if (probe.platform === 'github' && response.statusCode === 403 &&
    body.toLowerCase().indexOf('rate limit') >= 0) {
    try {
      const fallback = await httpCaller(displayUrl, probe.requestHeaders);
      if (fallback.statusCode === 404) return emptyProbeResult('not_found');
      if (fallback.statusCode >= 200 && fallback.statusCode < 300) {
        const fallbackResult = htmlProbeResult(
          probe, fallback.body.substring(0, MAX_PROFILE_BODY_CHARS), displayUrl, username);
        if (fallbackResult !== null) return fallbackResult;
      }
    } catch (_error) {
      const category = requestErrorCategory(typeof _error === 'string' ? _error : _error as Object);
      aiLogInfo(`[AIPhone][PublicPersonaProbeDetail] platform=${probe.platform} stage=html-fallback ` +
        `error=${category} state=unknown`);
    }
    return emptyProbeResult('unknown');
  }
  if (state !== 'found') {
    return emptyProbeResult(state);
  }
  if (probe.platform === 'qq') {
    return qqProbeResult(body, displayUrl, username) ?? emptyProbeResult('unknown');
  }
  if (probe.platform === 'npm') {
    return npmProbeResult(body, username) ?? emptyProbeResult('unknown');
  }
  if (probe.platform === 'medium') {
    return mediumProbeResult(body, username) ?? emptyProbeResult('unknown');
  }
  if (probe.jsonIdentity !== undefined || probe.platform === 'github' || probe.platform === 'bilibili' ||
    probe.platform === 'zhihu' ||
    probe.platform === 'weibo' || probe.platform === 'x' || probe.platform === 'gitlab' ||
    probe.platform === 'bitbucket' || probe.platform === 'dockerhub' || probe.platform === 'stackoverflow' ||
    probe.platform === 'keybase') {
    const result = jsonProbeResult(probe, body, displayUrl, username);
    if (result !== null) {
      aiLogInfo(`[AIPhone][PublicPersonaProbeDetail] platform=${probe.platform} stage=identity state=found`);
      return result;
    }
    aiLogInfo(`[AIPhone][PublicPersonaProbeDetail] platform=${probe.platform} stage=identity state=unknown`);
  }
  let identityBody = body;
  if (probeUrl !== displayUrl) {
    try {
      const displayResponse = await httpCaller(displayUrl, probe.requestHeaders);
      if (displayResponse.statusCode < 200 || displayResponse.statusCode >= 300) return emptyProbeResult('unknown');
      identityBody = displayResponse.body.substring(0, MAX_PROFILE_BODY_CHARS);
      for (let index = 0; index < probe.errorMarkers.length; index++) {
        if (identityBody.toLowerCase().indexOf(probe.errorMarkers[index].toLowerCase()) >= 0) {
          return emptyProbeResult('unknown');
        }
      }
    } catch (_error) {
      const category = requestErrorCategory(typeof _error === 'string' ? _error : _error as Object);
      aiLogInfo(`[AIPhone][PublicPersonaProbeDetail] platform=${probe.platform} stage=identity ` +
        `error=${category} state=unknown`);
      return emptyProbeResult('unknown');
    }
  }
  return htmlProbeResult(probe, identityBody, displayUrl, username) ?? emptyProbeResult('unknown');
}
