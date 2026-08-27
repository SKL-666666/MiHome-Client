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

import { getXiaomiApiHost } from '../models/XiaomiConfig';
import {
  asNumber,
  asString,
  XiaomiAuthInfo
} from '../models/XiaomiAuthInfo';
import {
  cloneXiaomiDevice,
  parseStringArray,
  parseXiaomiDevice,
  parseXiaomiHome,
  parseXiaomiUser,
  XiaomiDevice,
  XiaomiHome,
  XiaomiRoom,
  XiaomiUser
} from '../models/XiaomiHomeModels';
import { XiaomiCloudError } from '../models/XiaomiErrors';
import {
  parseXiaomiJsonResponse,
  XiaomiHttpClient,
  XiaomiHttpResponse
} from '../network/XiaomiHttpClient';
import { calcGroupId } from '../utils/CryptoUtils';

export interface XiaomiPropertyParam {
  did: string;
  siid: number;
  piid: number;
}

export interface XiaomiPropertySetParam {
  did: string;
  siid: number;
  piid: number;
  value: Object;
}

export interface XiaomiPropertyResult {
  did: string;
  siid: number;
  piid: number;
  value: Object | undefined;
}

interface XiaomiHomeListRequest {
  limit: number;
  fetch_share: boolean;
  fetch_share_dev: boolean;
  plat_form: number;
  app_ver: number;
}

interface XiaomiDeviceListRequest {
  limit: number;
  get_split_device: boolean;
  get_third_device: boolean;
  dids: string[];
  start_did?: string;
}

interface XiaomiPropertyGetRequest {
  datasource: number;
  params: XiaomiPropertyParam[];
}

interface XiaomiPropertySetRequest {
  params: XiaomiPropertySetParam[];
}

interface XiaomiActionRequest {
  params: XiaomiActionParams;
}

interface XiaomiActionParams {
  did: string;
  siid: number;
  aiid: number;
  in: Object[];
}

export interface XiaomiHomesResult {
  uid: string;
  homes: XiaomiHome[];
}

export class XiaomiCloudClient {
  private accessToken: string;
  private clientId: string;
  private readonly region: string;
  private readonly host: string;
  private readonly baseUrl: string;

  constructor(authInfo: XiaomiAuthInfo) {
    if (authInfo.accessToken.trim().length === 0) {
      throw new XiaomiCloudError('empty access token');
    }
    this.accessToken = authInfo.accessToken;
    this.clientId = authInfo.clientId;
    this.region = authInfo.region;
    this.host = getXiaomiApiHost(authInfo.region);
    this.baseUrl = `https://${this.host}`;
  }

  updateAccessToken(accessToken: string): void {
    this.accessToken = accessToken;
  }

  async getUserInfo(): Promise<XiaomiUser> {
    const url = `https://open.account.xiaomi.com/user/profile?clientId=${encodeURIComponent(this.clientId)}&token=${encodeURIComponent(this.accessToken)}`;
    const response = await XiaomiHttpClient.get(url, {
      headers: {
        'content-type': 'application/x-www-form-urlencoded'
      }
    });
    const parsed = parseXiaomiJsonResponse(response);
    const data = parsed['data'];
    if (data === undefined || data === null) {
      throw new XiaomiCloudError('user info data missing', response.status);
    }
    return parseXiaomiUser(data as Record<string, Object>);
  }

  async getHomes(): Promise<XiaomiHomesResult> {
    const request: XiaomiHomeListRequest = {
      limit: 150,
      fetch_share: true,
      fetch_share_dev: true,
      plat_form: 0,
      app_ver: 9
    };
    const parsed = await this.post('/app/v2/homeroom/gethome', request);
    const result = parsed['result'];
    if (result === undefined || result === null) {
      throw new XiaomiCloudError('home list result missing');
    }
    const resultObj = result as Record<string, Object>;
    const uid = asString(resultObj['uid']);
    const homes: XiaomiHome[] = [];
    this.appendHomes(resultObj['homelist'], 'homelist', uid, homes);
    this.appendHomes(resultObj['share_home_list'], 'share_home_list', uid, homes);
    return {
      uid: uid,
      homes: homes
    };
  }

  async getRooms(): Promise<XiaomiRoom[]> {
    const homesResult = await this.getHomes();
    const rooms: XiaomiRoom[] = [];
    for (let i = 0; i < homesResult.homes.length; i++) {
      const home = homesResult.homes[i];
      for (let j = 0; j < home.roomList.length; j++) {
        rooms.push(home.roomList[j]);
      }
    }
    return rooms;
  }

  async getDevices(homeIds?: string[]): Promise<Record<string, XiaomiDevice>> {
    const homesResult = await this.getHomes();
    const homes = homesResult.homes;
    const locationByDid: Record<string, XiaomiDeviceLocation> = {};
    const dids: string[] = [];
    for (let i = 0; i < homes.length; i++) {
      const home = homes[i];
      if (homeIds !== undefined && homeIds.indexOf(home.homeId) < 0) {
        continue;
      }
      for (let j = 0; j < home.dids.length; j++) {
        const did = home.dids[j];
        if (locationByDid[did] === undefined) {
          dids.push(did);
          locationByDid[did] = {
            homeId: home.homeId,
            homeName: home.name,
            roomId: home.homeId,
            roomName: home.name,
            groupId: home.groupId
          };
        }
      }
      for (let j = 0; j < home.roomList.length; j++) {
        const room = home.roomList[j];
        for (let k = 0; k < room.dids.length; k++) {
          const did = room.dids[k];
          if (locationByDid[did] === undefined) {
            dids.push(did);
          }
          locationByDid[did] = {
            homeId: home.homeId,
            homeName: home.name,
            roomId: room.roomId,
            roomName: room.name,
            groupId: home.groupId
          };
        }
      }
    }
    const deviceMap = await this.getDevicesWithDids(dids);
    const deviceDids = Object.keys(deviceMap);
    for (let i = 0; i < deviceDids.length; i++) {
      const key = deviceDids[i];
      const device = deviceMap[key];
      const location = locationByDid[key];
      if (location === undefined) {
        continue;
      }
      device.homeId = location.homeId;
      device.homeName = location.homeName;
      device.roomId = location.roomId;
      device.roomName = location.roomName;
      device.groupId = location.groupId;
    }
    return deviceMap;
  }

  async getDeviceInfo(did: string): Promise<XiaomiDevice | null> {
    const devices = await this.getDevicesWithDids([did]);
    return devices[did] ?? null;
  }

  async getDeviceProperties(params: XiaomiPropertyParam[]): Promise<XiaomiPropertyResult[]> {
    const request: XiaomiPropertyGetRequest = {
      datasource: 1,
      params: params
    };
    const parsed = await this.post('/app/v2/miotspec/prop/get', request);
    return this.parsePropertyResults(parsed['result']);
  }

  async setDeviceProperty(
    did: string,
    siid: number,
    piid: number,
    value: Object
  ): Promise<XiaomiPropertyResult[]> {
    const request: XiaomiPropertySetRequest = {
      params: [{
        did: did,
        siid: siid,
        piid: piid,
        value: value
      }]
    };
    const parsed = await this.post('/app/v2/miotspec/prop/set', request);
    return this.parsePropertyResults(parsed['result']);
  }

  async setDeviceProperties(params: XiaomiPropertySetParam[]): Promise<XiaomiPropertyResult[]> {
    const request: XiaomiPropertySetRequest = {
      params: params
    };
    const parsed = await this.post('/app/v2/miotspec/prop/set', request);
    return this.parsePropertyResults(parsed['result']);
  }

  async callDeviceAction(
    did: string,
    siid: number,
    aiid: number,
    inList: Object[]
  ): Promise<Record<string, Object> | undefined> {
    const request: XiaomiActionRequest = {
      params: {
        did: did,
        siid: siid,
        aiid: aiid,
        in: inList
      }
    };
    const parsed = await this.post('/app/v2/miotspec/action', request);
    return parsed['result'] as Record<string, Object> | undefined;
  }

  async getDevicesWithDids(dids: string[]): Promise<Record<string, XiaomiDevice>> {
    const result: Record<string, XiaomiDevice> = {};
    if (dids.length === 0) {
      return result;
    }
    const batchSize = 150;
    for (let start = 0; start < dids.length; start += batchSize) {
      const batch = dids.slice(start, start + batchSize);
      let page = await this.getDeviceListPage(batch, undefined);
      const pageDevices = page.devices;
      const pageDids = Object.keys(pageDevices);
      for (let i = 0; i < pageDids.length; i++) {
        const did = pageDids[i];
        result[did] = pageDevices[did];
      }
      let startDid = page.nextStartDid;
      while (page.hasMore && startDid.length > 0) {
        page = await this.getDeviceListPage(batch, startDid);
        const pageDids = Object.keys(page.devices);
        for (let i = 0; i < pageDids.length; i++) {
          const did = pageDids[i];
          result[did] = page.devices[did];
        }
        startDid = page.nextStartDid;
      }
    }
    return this.normalizeSubDevices(result);
  }

  private async getDeviceListPage(
    dids: string[],
    startDid: string | undefined
  ): Promise<DeviceListPage> {
    const request: XiaomiDeviceListRequest = {
      limit: 200,
      get_split_device: true,
      get_third_device: true,
      dids: dids
    };
    if (startDid !== undefined) {
      request.start_did = startDid;
    }
    const parsed = await this.post('/app/v2/home/device_list_page', request);
    const result = parsed['result'];
    if (result === undefined || result === null) {
      throw new XiaomiCloudError('device list result missing');
    }
    const resultObj = result as Record<string, Object>;
    const devices: Record<string, XiaomiDevice> = {};
    const list = resultObj['list'];
    if (list instanceof Array) {
      for (let i = 0; i < list.length; i++) {
        const raw = list[i] as Record<string, Object>;
        const device = parseXiaomiDevice(raw);
        if (device.did.length > 0 && device.name.length > 0 && device.urn.length > 0 &&
          device.model.length > 0) {
          devices[device.did] = device;
        }
      }
    }
    const hasMore = resultObj['has_more'] === true;
    const nextStartDid = asString(resultObj['next_start_did']);
    return {
      devices: devices,
      hasMore: hasMore,
      nextStartDid: nextStartDid
    };
  }

  private normalizeSubDevices(
    devices: Record<string, XiaomiDevice>
  ): Record<string, XiaomiDevice> {
    const result: Record<string, XiaomiDevice> = {};
    const dids = Object.keys(devices);
    for (let i = 0; i < dids.length; i++) {
      const did = dids[i];
      const match = /\.s\d+$/.exec(did);
      if (match === null) {
        result[did] = devices[did];
        continue;
      }
      const parentDid = did.slice(0, did.length - match[0].length);
      const parent = result[parentDid] ?? devices[parentDid];
      if (parent === undefined) {
        continue;
      }
      const subIndex = match[0].substring(1);
      const child = devices[did];
      const parentCopy = cloneXiaomiDevice(parent);
      parentCopy.subDevices[subIndex] = child;
      result[parentDid] = parentCopy;
    }
    return result;
  }

  private appendHomes(
    value: Object | undefined,
    source: string,
    uid: string,
    homes: XiaomiHome[]
  ): void {
    if (!(value instanceof Array)) {
      return;
    }
    for (let i = 0; i < value.length; i++) {
      const raw = value[i] as Record<string, Object>;
      const homeId = asString(raw['id']);
      if (homeId.length === 0) {
        continue;
      }
      homes.push(parseXiaomiHome(raw, source, calcGroupId(uid, homeId)));
    }
  }

  private parsePropertyResults(value: Object | undefined): XiaomiPropertyResult[] {
    if (!(value instanceof Array)) {
      return [];
    }
    const results: XiaomiPropertyResult[] = [];
    for (let i = 0; i < value.length; i++) {
      const raw = value[i] as Record<string, Object>;
      results.push({
        did: asString(raw['did']),
        siid: asNumber(raw['siid']),
        piid: asNumber(raw['piid']),
        value: raw['value']
      });
    }
    return results;
  }

  private async post(
    path: string,
    body: Object
  ): Promise<Record<string, Object>> {
    const response = await XiaomiHttpClient.postJson(`${this.baseUrl}${path}`, body, {
      headers: this.apiHeaders()
    });
    return parseXiaomiJsonResponse(response);
  }

  private apiHeaders(): Record<string, string> {
    return {
      'Host': this.host,
      'X-Client-BizId': 'haapi',
      'Content-Type': 'application/json',
      'Authorization': `Bearer${this.accessToken}`,
      'X-Client-AppId': this.clientId
    };
  }
}

interface XiaomiDeviceLocation {
  homeId: string;
  homeName: string;
  roomId: string;
  roomName: string;
  groupId: string;
}

interface DeviceListPage {
  devices: Record<string, XiaomiDevice>;
  hasMore: boolean;
  nextStartDid: string;
}
