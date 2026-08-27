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

import { asBoolean, asNumber, asString } from './XiaomiAuthInfo';

export const ALL_HOMES_ID: string = '__all_homes__';
export const ALL_HOMES_NAME: string = '全部设备';

export interface XiaomiUser {
  uid: string;
  nickname: string;
  avatarUrl: string;
}

export interface XiaomiRoom {
  roomId: string;
  name: string;
  dids: string[];
}

export interface XiaomiHome {
  homeId: string;
  name: string;
  uid: string;
  groupId: string;
  source: string;
  dids: string[];
  roomList: XiaomiRoom[];
  cityId: string;
  longitude: number;
  latitude: number;
  address: string;
}

export interface XiaomiDevice {
  did: string;
  uid: string;
  name: string;
  urn: string;
  model: string;
  manufacturer: string;
  connectType: number;
  token: string;
  online: boolean;
  homeId: string;
  homeName: string;
  roomId: string;
  roomName: string;
  groupId: string;
  icon: string;
  parentId: string;
  localIp: string;
  ssid: string;
  bssid: string;
  pid: string;
  orderTime: number;
  fwVersion: string;
  rssi: number;
  subDevices: Record<string, XiaomiDevice>;
}

export interface InfoExcludeOption {
  did: string;
  name: string;
  roomName: string;
}

export interface XiaomiScene {
  sceneId: string;
  name: string;
  icon: string;
  isEnabled: boolean;
  homeId: string;
}

/** 本地智能中的单条设备动作 */
export interface LocalSceneAction {
  did: string;
  deviceName: string;
  siid: number;
  piid: number;
  label: string;
  value: Object;
  /** 动作值的展示文本（枚举已译为中文；旧数据缺省时回退 String(value)） */
  valueText?: string;
}

/** 用户在本应用内自建的本地智能（仅本地执行，不同步米家云端） */
export interface LocalScene {
  sceneId: string;
  name: string;
  actions: LocalSceneAction[];
}

export function parseXiaomiScene(raw: Record<string, Object>): XiaomiScene {
  const enableRaw = asString(raw['enable'] ?? raw['is_enable'] ?? raw['enabled']);
  return {
    sceneId: asString(raw['scene_id'] ?? raw['id'] ?? raw['us_id']),
    name: asString(raw['name']),
    icon: asString(raw['icon'] ?? raw['icon_url']),
    isEnabled: enableRaw === '1' || enableRaw === 'true' || enableRaw === 'True',
    homeId: asString(raw['home_id'])
  };
}

export function parseXiaomiUser(data: Record<string, Object>): XiaomiUser {
  return {
    uid: asString(data['userId'] ?? data['uid']),
    nickname: asString(data['miliaoNick']),
    avatarUrl: asString(data['miliaoIcon'] ?? data['avatar'])
  };
}

export function parseXiaomiRoom(raw: Record<string, Object>): XiaomiRoom {
  return {
    roomId: asString(raw['id']),
    name: asString(raw['name']),
    dids: parseStringArray(raw['dids'])
  };
}

export function parseXiaomiHome(
  raw: Record<string, Object>,
  source: string,
  groupId: string
): XiaomiHome {
  const roomList: XiaomiRoom[] = [];
  const rawRoomList = raw['roomlist'];
  if (rawRoomList instanceof Array) {
    for (let i = 0; i < rawRoomList.length; i++) {
      const room = rawRoomList[i] as Record<string, Object>;
      roomList.push(parseXiaomiRoom(room));
    }
  }
  return {
    homeId: asString(raw['id']),
    name: asString(raw['name']),
    uid: asString(raw['uid']),
    groupId: groupId,
    source: source,
    dids: parseStringArray(raw['dids']),
    roomList: roomList,
    cityId: asString(raw['city_id']),
    longitude: asNumber(raw['longitude']),
    latitude: asNumber(raw['latitude']),
    address: asString(raw['address'])
  };
}

export function parseXiaomiDevice(raw: Record<string, Object>): XiaomiDevice {
  const model = asString(raw['model']);
  const extra = raw['extra'];
  const fwVersion = extra === undefined || extra === null
    ? ''
    : asString((extra as Record<string, Object>)['fw_version']);
  return {
    did: asString(raw['did']),
    uid: asString(raw['uid']),
    name: asString(raw['name']),
    urn: asString(raw['spec_type']),
    model: model,
    manufacturer: model.split('.')[0],
    connectType: asNumber(raw['pid']),
    token: asString(raw['token']),
    online: asBoolean(raw['isOnline']),
    homeId: asString(raw['home_id']),
    homeName: asString(raw['home_name']),
    roomId: asString(raw['room_id']),
    roomName: asString(raw['room_name']),
    groupId: asString(raw['group_id']),
    icon: asString(raw['icon']),
    parentId: asString(raw['parent_id']),
    localIp: asString(raw['local_ip']),
    ssid: asString(raw['ssid']),
    bssid: asString(raw['bssid']),
    pid: asString(raw['pid']),
    orderTime: asNumber(raw['orderTime']),
    fwVersion: fwVersion,
    rssi: asNumber(raw['rssi']),
    subDevices: {}
  };
}

export function parseStringArray(value: Object | undefined): string[] {
  if (!(value instanceof Array)) {
    return [];
  }
  const result: string[] = [];
  for (let i = 0; i < value.length; i++) {
    result.push(String(value[i]));
  }
  return result;
}

export function cloneXiaomiDevice(value: XiaomiDevice): XiaomiDevice {
  return {
    did: value.did,
    uid: value.uid,
    name: value.name,
    urn: value.urn,
    model: value.model,
    manufacturer: value.manufacturer,
    connectType: value.connectType,
    token: value.token,
    online: value.online,
    homeId: value.homeId,
    homeName: value.homeName,
    roomId: value.roomId,
    roomName: value.roomName,
    groupId: value.groupId,
    icon: value.icon,
    parentId: value.parentId,
    localIp: value.localIp,
    ssid: value.ssid,
    bssid: value.bssid,
    pid: value.pid,
    orderTime: value.orderTime,
    fwVersion: value.fwVersion,
    rssi: value.rssi,
    subDevices: value.subDevices
  };
}
