/*
 * 鸿米家（miha）— HarmonyOS NEXT native Xiaomi Home / MIoT control client.
 *
 * Copyright (C) 2026 鸿米家（miha）项目开发者
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import {
  asNumber,
  asString
} from '../models/XiaomiAuthInfo';
import { XiaomiAuthError, XiaomiCloudError, XiaomiErrorCode } from '../models/XiaomiErrors';
import {
  parseXiaomiDevice,
  parseXiaomiHome,
  parseXiaomiScene,
  XiaomiDevice,
  XiaomiHome,
  XiaomiScene
} from '../models/XiaomiHomeModels';
import {
  XiaomiHttpClient,
  XiaomiHttpResponse
} from '../network/XiaomiHttpClient';
import {
  decryptMijiaRc4,
  genMijiaNonce,
  generateMijiaEncParams,
  getSignedMijiaNonce,
  mijiaParamsToForm
} from '../utils/MijiaCrypto';
import { util } from '@kit.ArkTS';
import { calcGroupId } from '../utils/CryptoUtils';
import { Logger } from '../utils/Logger';

export interface MijiaAuthData {
  userId: string;
  cUserId: string;
  passToken: string;
  ssecurity: string;
  serviceToken: string;
  deviceId: string;
  passO: string;
  userAgent: string;
  locale: string;
}

export class MijiaApiClient {
  private readonly baseUrl: string = 'https://api.mijia.tech/app';
  private auth: MijiaAuthData;

  constructor(auth: MijiaAuthData) {
    this.auth = auth;
  }

  updateAuth(auth: MijiaAuthData): void {
    this.auth = auth;
  }

  async request(uri: string, data: Object): Promise<Record<string, Object>> {
    const nonce = genMijiaNonce();
    const signedNonce = getSignedMijiaNonce(this.auth.ssecurity, nonce);
    const params = generateMijiaEncParams(
      uri,
      'POST',
      signedNonce,
      nonce,
      [{ key: 'data', value: JSON.stringify(data) }],
      this.auth.ssecurity
    );
    const form = mijiaParamsToForm(params);
    const response = await XiaomiHttpClient.postForm(`${this.baseUrl}${uri}`, form, {
      headers: this.requestHeaders()
    });
    if (response.status === 401) {
      throw new XiaomiAuthError(
        XiaomiErrorCode.AUTH_TOKEN_EXPIRED,
        '登录状态已失效，请重新扫码登录',
        401
      );
    }
    return this.parseResponse(response, this.auth.ssecurity, nonce) as Record<string, Object>;
  }

  async requestResult(uri: string, data: Object): Promise<Object> {
    const nonce = genMijiaNonce();
    const signedNonce = getSignedMijiaNonce(this.auth.ssecurity, nonce);
    const params = generateMijiaEncParams(
      uri,
      'POST',
      signedNonce,
      nonce,
      [{ key: 'data', value: JSON.stringify(data) }],
      this.auth.ssecurity
    );
    const response = await XiaomiHttpClient.postForm(`${this.baseUrl}${uri}`, mijiaParamsToForm(params), {
      headers: this.requestHeaders()
    });
    if (response.status === 401) {
      throw new XiaomiAuthError(
        XiaomiErrorCode.AUTH_TOKEN_EXPIRED,
        '登录状态已失效，请重新扫码登录',
        401
      );
    }
    return this.parseResponse(response, this.auth.ssecurity, nonce);
  }

  async getStatistics(
    did: string,
    key: string,
    dataType: string,
    limit: number,
    timeStart: number,
    timeEnd: number
  ): Promise<Object[]> {
    const data: MijiaStatisticsRequest = {
      did: did,
      key: key,
      data_type: dataType,
      limit: limit,
      time_start: timeStart,
      time_end: timeEnd
    };
    const result = await this.requestResult('/v2/user/statistics', data);
    if (result instanceof Array) {
      return result as Object[];
    }
    return [];
  }

  async getHomes(): Promise<XiaomiHome[]> {
    const data: MijiaHomeListRequest = {
      fg: true,
      fetch_share: true,
      fetch_share_dev: true,
      fetch_cariot: true,
      limit: 300,
      app_ver: 7,
      plat_form: 0
    };
    const result = await this.request('/v2/homeroom/gethome_merged', data);
    const resultKeys = Object.keys(result);
    const homelistRaw = result['homelist'];
    Logger.info('gethome_merged keys=%{public}s homelist=%{public}s share=%{public}s share2=%{public}s',
      resultKeys.join(','),
      homelistRaw instanceof Array ? `${homelistRaw.length}` : 'n/a',
      result['share_home_list'] instanceof Array ? `${(result['share_home_list'] as Object[]).length}` : 'n/a',
      result['share_homelist'] instanceof Array ? `${(result['share_homelist'] as Object[]).length}` : 'n/a');
    const homes: XiaomiHome[] = [];
    const seenHomeIds: string[] = [];
    const appendHomeList = (value: Object | undefined, source: string): void => {
      if (!(value instanceof Array)) {
        return;
      }
      for (let i = 0; i < value.length; i++) {
        const raw = value[i] as Record<string, Object>;
        const homeId = asString(raw['id']);
        if (homeId.length === 0 || seenHomeIds.indexOf(homeId) >= 0) {
          continue;
        }
        seenHomeIds.push(homeId);
        const uid = asString(raw['uid']);
        homes.push(parseXiaomiHome(raw, source, calcGroupId(uid, homeId)));
      }
    };
    appendHomeList(result['homelist'], 'homelist');
    appendHomeList(result['share_home_list'], 'share_home_list');
    appendHomeList(result['share_homelist'], 'share_homelist');
    return homes;
  }

  async getDevices(homeIds?: string[]): Promise<Record<string, XiaomiDevice>> {
    const allHomes = await this.getHomes();
    const homes: XiaomiHome[] = [];
    for (let i = 0; i < allHomes.length; i++) {
      if (homeIds === undefined || homeIds.indexOf(allHomes[i].homeId) >= 0) {
        homes.push(allHomes[i]);
      }
    }
    const result: Record<string, XiaomiDevice> = {};
    for (let i = 0; i < homes.length; i++) {
      const home = homes[i];
      const homeIdValue = home.homeId;
      const ownerId = home.uid;
      const devices = await this.getHomeDevices(homeIdValue, ownerId);
      for (let j = 0; j < devices.length; j++) {
        const device = devices[j];
        device.homeId = homeIdValue;
        device.homeName = home.name;
        result[device.did] = device;
      }
    }
    return result;
  }

  async getHomeDevices(homeId: string, ownerId: string): Promise<XiaomiDevice[]> {
    const devices: XiaomiDevice[] = [];
    let startDid = '';
    let previousStartDid = '';
    let hasMore = true;
    while (hasMore) {
      const data: MijiaHomeDeviceRequest = {
        home_owner: Number(ownerId),
        home_id: Number(homeId),
        limit: 200,
        start_did: startDid,
        get_split_device: true,
        support_smart_home: true,
        get_cariot_device: true,
        get_third_device: true
      };
      const result = await this.request('/home/home_device_list', data);
      const deviceInfo = result['device_info'];
      if (deviceInfo instanceof Array) {
        for (let i = 0; i < deviceInfo.length; i++) {
          const raw = deviceInfo[i] as Record<string, Object>;
          const normalized: Record<string, Object> = {};
          const keys = Object.keys(raw);
          for (let k = 0; k < keys.length; k++) {
            normalized[keys[k]] = raw[keys[k]];
          }
          normalized['spec_type'] = asString(raw['spec_type']);
          devices.push(parseXiaomiDevice(normalized));
        }
        previousStartDid = startDid;
        startDid = asString(result['max_did']);
        if (startDid.length > 0 && startDid === previousStartDid) {
          throw new XiaomiCloudError(`device pagination cursor did not advance for home ${homeId}`);
        }
        hasMore = result['has_more'] === true && startDid.length > 0;
      } else {
        hasMore = false;
      }
    }
    return devices;
  }

  async getProperties(params: Object[]): Promise<Object[]> {
    const data: MijiaPropertyGetRequest = {
      params: params,
      datasource: 1
    };
    const result = await this.requestResult('/miotspec/prop/get', data);
    if (result instanceof Array) {
      return result as Object[];
    }
    return [];
  }

  async setProperties(params: Object[]): Promise<Object[]> {
    const data: MijiaPropertySetRequest = {
      params: params
    };
    const result = await this.requestResult('/miotspec/prop/set', data);
    if (result instanceof Array) {
      return result as Object[];
    }
    return [];
  }

  async runAction(param: Object): Promise<Record<string, Object> | undefined> {
    const data: MijiaActionRequest = {
      params: param
    };
    const result = await this.requestResult('/miotspec/action', data);
    if (result === null || result === undefined) {
      return undefined;
    }
    return result as Record<string, Object>;
  }

  async checkNewMsg(beginAt: number = Math.floor(Date.now() / 1000) - 3600): Promise<Record<string, Object>> {
    const data: MijiaCheckNewMsgRequest = {
      begin_at: beginAt
    };
    return this.request('/v2/message/v2/check_new_msg', data);
  }

  async getMessageList(homeId: string, limit: number = 30): Promise<MijiaMessageItem[]> {
    const endAt = Math.floor(Date.now() / 1000);
    const data: MijiaMessageListRequest = {
      begin_at: endAt - 7 * 24 * 3600,
      end_at: endAt,
      home_id: Number(homeId),
      limit: limit,
      page_id: 0,
      stick: false
    };
    const result = await this.request('/v2/message/v2/list', data);
    const groupsRaw = result['groups'] instanceof Array
      ? result['groups'] as Object[]
      : (result['messages'] instanceof Array ? result['messages'] as Object[] : []);
    const items: MijiaMessageItem[] = [];
    for (let i = 0; i < groupsRaw.length; i++) {
      const group = groupsRaw[i];
      if (!(group instanceof Object) || group instanceof Array) {
        continue;
      }
      const listRaw = (group as Record<string, Object>)['list'];
      if (!(listRaw instanceof Array)) {
        continue;
      }
      for (let j = 0; j < listRaw.length; j++) {
        const raw: Object = listRaw[j];
        if (!(raw instanceof Object) || raw instanceof Array) {
          continue;
        }
        const entry = raw as Record<string, Object>;
        let title = '';
        let desc = '';
        const contentRaw = entry['content'];
        let contentObj: Record<string, Object> | null = null;
        if (typeof contentRaw === 'string') {
          try {
            const parsed: Object = JSON.parse(contentRaw);
            if (parsed instanceof Object && !(parsed instanceof Array)) {
              contentObj = parsed as Record<string, Object>;
            }
          } catch (err) {
            contentObj = null;
          }
        } else if (contentRaw instanceof Object && !(contentRaw instanceof Array)) {
          contentObj = contentRaw as Record<string, Object>;
        }
        if (contentObj !== null) {
          title = asString(contentObj['title']);
          desc = asString(contentObj['desc']).length > 0
            ? asString(contentObj['desc']) : asString(contentObj['content']);
        }
        const dataRaw = entry['data'];
        if (title.length === 0 && typeof dataRaw === 'string') {
          try {
            const parsed: Object = JSON.parse(dataRaw);
            if (parsed instanceof Object && !(parsed instanceof Array)) {
              const dataObj = parsed as Record<string, Object>;
              title = asString(dataObj['title']);
              desc = desc.length > 0 ? desc : asString(dataObj['desc']);
            }
          } catch (err) {
            title = '';
          }
        }
        const timeVal = entry['time'];
        const createTime = entry['create_time'];
        const time = typeof timeVal === 'number' ? timeVal
          : (typeof createTime === 'number' ? createTime : 0);
        if (title.length === 0 && desc.length === 0) {
          continue;
        }
        items.push({
          messageId: asString(entry['id']),
          title: title.length > 0 ? title : desc,
          desc: title.length > 0 ? desc : '',
          time: time,
          model: asString(entry['model']),
          did: asString(entry['did'])
        });
      }
    }
    return items;
  }

  async getConsumableItems(homeId: string, ownerId: string): Promise<MijiaConsumableItem[]> {
    const data: MijiaConsumableItemsRequest = {
      home_id: Number(homeId),
      owner_id: Number(ownerId),
      filter_ignore: true
    };
    const result = await this.request('/v2/home/standard_consumable_items', data);
    const groupsRaw = result['items'];
    if (!(groupsRaw instanceof Array)) {
      return [];
    }
    const items: MijiaConsumableItem[] = [];
    const seenDids: string[] = [];
    for (let g = 0; g < groupsRaw.length; g++) {
      const groupRaw: Object = groupsRaw[g];
      if (!(groupRaw instanceof Object) || groupRaw instanceof Array) {
        continue;
      }
      const group = groupRaw as Record<string, Object>;
      const consumesRaw = group['consumes_data'];
      if (!(consumesRaw instanceof Array)) {
        continue;
      }
      for (let i = 0; i < consumesRaw.length; i++) {
        this.appendConsumableEntry(consumesRaw[i] as Object, items, seenDids);
      }
    }
    return items;
  }

  private appendConsumableEntry(raw: Object, items: MijiaConsumableItem[], seenDids: string[]): void {
    if (!(raw instanceof Object) || raw instanceof Array) {
      return;
    }
    const entry = raw as Record<string, Object>;
    const did = asString(entry['did']);
    if (did.length > 0 && seenDids.indexOf(did) >= 0) {
      return;
    }
    const detailEntries: Record<string, Object>[] = [];
    const detailsRaw = entry['details'];
    if (detailsRaw instanceof Array) {
      for (let j = 0; j < detailsRaw.length; j++) {
        const detail: Object = detailsRaw[j];
        if (detail instanceof Object && !(detail instanceof Array)) {
          detailEntries.push(detail as Record<string, Object>);
        }
      }
    } else if (detailsRaw instanceof Object) {
      detailEntries.push(detailsRaw as Record<string, Object>);
    }
    const details = parseConsumableDetails(detailEntries);
    if (did.length > 0) {
      seenDids.push(did);
    }
    items.push({
      did: did,
      name: asString(entry['name']),
      model: asString(entry['model']),
      details: details
    });
  }

  async getScenes(homeId: string): Promise<XiaomiScene[]> {
    const ownerUid = await this.getHomeOwner(homeId);
    const data: MijiaSceneListRequest = {
      app_version: 12,
      get_type: 2,
      home_id: homeId,
      owner_uid: ownerUid
    };
    const result = await this.request(
      '/appgateway/miot/appsceneservice/AppSceneService/GetSimpleSceneList', data);
    const scenes: XiaomiScene[] = [];
    const seenSceneIds: string[] = [];
    const appendSceneList = (value: Object | undefined, sceneType: string): void => {
      if (!(value instanceof Array)) {
        return;
      }
      for (let i = 0; i < value.length; i++) {
        const raw = value[i] as Record<string, Object>;
        const scene = parseXiaomiScene(raw, sceneType);
        if (scene.sceneId.length === 0 || seenSceneIds.indexOf(scene.sceneId) >= 0) {
          continue;
        }
        seenSceneIds.push(scene.sceneId);
        scene.homeId = homeId;
        scenes.push(scene);
      }
    };
    appendSceneList(result['manual_scene_info_list'], 'manual');
    appendSceneList(result['auto_scene_info_list'], 'auto');
    return scenes;
  }

  async runScene(sceneId: string, homeId: string): Promise<Record<string, Object>> {
    const ownerUid = await this.getHomeOwner(homeId);
    const data: MijiaSceneRunRequest = {
      scene_id: sceneId,
      scene_type: 1,
      home_id: homeId,
      owner_uid: ownerUid
    };
    return this.request('/appgateway/miot/appsceneservice/AppSceneService/NewRunScene', data);
  }

  async getHomeOwner(homeId: string): Promise<string> {
    const homes = await this.getHomes();
    for (let i = 0; i < homes.length; i++) {
      if (homes[i].homeId === homeId) {
        return homes[i].uid;
      }
    }
    throw new XiaomiCloudError(`home not found: ${homeId}`);
  }

  private requestHeaders(): Record<string, string> {
    const countryCode = this.auth.locale.includes('_')
      ? this.auth.locale.split('_')[1]
      : 'CN';
    return {
      'User-Agent': this.auth.userAgent,
      'accept-encoding': 'identity',
      'Content-Type': 'application/x-www-form-urlencoded',
      'miot-accept-encoding': 'identity',
      'miot-encrypt-algorithm': 'ENCRYPT-RC4',
      'x-xiaomi-protocal-flag-cli': 'PROTOCAL-HTTP2',
      'Cookie': `cUserId=${this.auth.cUserId};` +
        `yetAnotherServiceToken=${this.auth.serviceToken};` +
        `serviceToken=${this.auth.serviceToken};` +
        `channel=MI_APP_STORE;` +
        `countryCode=${countryCode};` +
        `PassportDeviceId=${this.auth.deviceId};` +
        `locale=${this.auth.locale}`
    };
  }

  private parseResponse(
    response: XiaomiHttpResponse,
    ssecurity: string,
    nonce: string
  ): Object {
    if (response.status !== 200) {
      throw new XiaomiCloudError(`mijia api status ${response.status}`, response.status);
    }
    if (response.body.trim().toLowerCase().includes('invalid token')) {
      throw new XiaomiCloudError('Mijia API returned Invalid Token');
    }
    let parsed: Object | undefined;
    try {
      parsed = JSON.parse(response.body) as Object;
    } catch (err) {
      parsed = undefined;
    }
    if (parsed === undefined) {
      const decrypted = decryptMijiaRc4(
        getSignedMijiaNonce(ssecurity, nonce),
        response.body
      );
      const plainText = new util.TextDecoder('utf-8').decode(decrypted);
      if (plainText.trim().toLowerCase().includes('invalid token')) {
        throw new XiaomiCloudError('Mijia API returned Invalid Token');
      }
      try {
        parsed = JSON.parse(plainText) as Object;
      } catch (err) {
        throw new XiaomiCloudError(`Mijia API returned non-JSON response: ${plainText.trim().slice(0, 80)}`);
      }
    }
    if (parsed === null || parsed === undefined) {
      throw new XiaomiCloudError('empty mijia api response');
    }
    const obj = parsed as Record<string, Object>;
    if (asNumber(obj['code']) !== 0 || obj['result'] === undefined) {
      throw new XiaomiCloudError(asString(obj['message'] ?? obj['desc'] ?? 'mijia api error'));
    }
    return obj['result'];
  }
}

interface MijiaHomeDeviceRequest {
  home_owner: number;
  home_id: number;
  limit: number;
  start_did: string;
  get_split_device: boolean;
  support_smart_home: boolean;
  get_cariot_device: boolean;
  get_third_device: boolean;
}

interface MijiaHomeListRequest {
  fg: boolean;
  fetch_share: boolean;
  fetch_share_dev: boolean;
  fetch_cariot: boolean;
  limit: number;
  app_ver: number;
  plat_form: number;
}

interface MijiaPropertyGetRequest {
  params: Object[];
  datasource: number;
}

interface MijiaPropertySetRequest {
  params: Object[];
}

interface MijiaActionRequest {
  params: Object;
}

interface MijiaCheckNewMsgRequest {
  begin_at: number;
}

interface MijiaMessageListRequest {
  begin_at: number;
  end_at: number;
  home_id: number;
  limit: number;
  page_id: number;
  stick: boolean;
}

export interface MijiaMessageItem {
  messageId: string;
  title: string;
  desc: string;
  time: number;
  model: string;
  did: string;
}

interface MijiaConsumableItemsRequest {
  home_id: number;
  owner_id: number;
  filter_ignore: boolean;
}

export interface MijiaConsumableDetail {
  name: string;
  percent: number;
  remainText: string;
}

export interface MijiaConsumableItem {
  did: string;
  name: string;
  model: string;
  details: MijiaConsumableDetail[];
}

function parseConsumableDetailName(obj: Record<string, Object>): string {
  const description = asString(obj['description']);
  if (description.length > 0) {
    return description;
  }
  const consumableType = asString(obj['consumable_type']);
  if (consumableType.length > 0) {
    return consumableType;
  }
  const typeName = asString(obj['type_name']);
  if (typeName.length > 0) {
    return typeName;
  }
  return asString(obj['name']);
}

function parseConsumableNumber(raw: Object | undefined): number {
  if (typeof raw === 'number') {
    return raw;
  }
  if (typeof raw === 'string' && raw.length > 0) {
    const parsed = Number(raw);
    if (!Number.isNaN(parsed)) {
      return parsed;
    }
  }
  return -1;
}

function parseConsumableDetails(entries: Record<string, Object>[]): MijiaConsumableDetail[] {
  const results: MijiaConsumableDetail[] = [];
  for (let i = 0; i < entries.length; i++) {
    const obj = entries[i];
    const name = parseConsumableDetailName(obj);
    if (name.length === 0) {
      continue;
    }
    let percent = parseConsumableNumber(obj['value']);
    if (percent < 0) {
      const percentRaw = obj['left_percent'] !== undefined ? obj['left_percent'] : obj['percent'];
      if (typeof percentRaw === 'number') {
        percent = percentRaw;
      }
    }
    let remainText = '';
    const leftHours = parseConsumableNumber(obj['left_time']);
    const leftDayRaw = obj['left_day'];
    if (leftHours > 0) {
      remainText = `剩余约 ${Math.max(1, Math.round(leftHours / 24))} 天`;
    } else if (typeof leftDayRaw === 'number' && leftDayRaw > 0) {
      remainText = `剩余约 ${leftDayRaw} 天`;
    }
    results.push({
      name: name,
      percent: percent,
      remainText: remainText
    });
  }
  return results;
}

interface MijiaSceneListRequest {
  app_version: number;
  get_type: number;
  home_id: string;
  owner_uid: string;
}

interface MijiaSceneRunRequest {
  scene_id: string;
  scene_type: number;
  home_id: string;
  owner_uid: string;
}

interface MijiaStatisticsRequest {
  did: string;
  key: string;
  data_type: string;
  limit: number;
  time_start: number;
  time_end: number;
}
