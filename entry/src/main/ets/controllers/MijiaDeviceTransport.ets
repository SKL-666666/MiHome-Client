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

import { MijiaApiClient } from '../cloud/MijiaApiClient';
import {
  DevicePropertyParam,
  DevicePropertyResult,
  SelectableDeviceTransport
} from './DeviceTransport';

export class MijiaDeviceTransport implements SelectableDeviceTransport {
  readonly kind: string = 'mijia';
  private readonly client: MijiaApiClient;

  constructor(client: MijiaApiClient) {
    this.client = client;
  }

  async isAvailable(): Promise<boolean> {
    return true;
  }

  async getProperty(did: string, siid: number, piid: number): Promise<Object | undefined> {
    const params: MijiaPropertyParam[] = [{
      did: did,
      siid: siid,
      piid: piid
    }];
    const results = await this.client.getProperties(params);
    if (results.length === 0) {
      return undefined;
    }
    return (results[0] as Record<string, Object>)['value'];
  }

  async getProperties(did: string, params: DevicePropertyParam[]): Promise<DevicePropertyResult[]> {
    const request: MijiaPropertyParam[] = [];
    for (let i = 0; i < params.length; i++) {
      request.push({
        did: params[i].did,
        siid: params[i].siid,
        piid: params[i].piid
      });
    }
    const results = await this.client.getProperties(request);
    const byKey = new Map<string, Object | undefined>();
    for (let i = 0; i < results.length; i++) {
      const raw = results[i] as Record<string, Object>;
      const code = raw['code'];
      let value: Object | undefined = raw['value'];
      if (code !== undefined) {
        const numeric = Number(code);
        if (!Number.isNaN(numeric) && numeric !== 0) {
          value = undefined;
        }
      }
      byKey.set(`${String(raw['did'])}.${String(raw['siid'])}.${String(raw['piid'])}`, value);
    }
    const mapped: DevicePropertyResult[] = [];
    for (let i = 0; i < params.length; i++) {
      const key = `${params[i].did}.${params[i].siid}.${params[i].piid}`;
      mapped.push({
        did: params[i].did,
        siid: params[i].siid,
        piid: params[i].piid,
        value: byKey.get(key)
      });
    }
    return mapped;
  }

  async setProperty(did: string, siid: number, piid: number, value: Object): Promise<Object | undefined> {
    const params: MijiaSetPropertyParam[] = [{
      did: did,
      siid: siid,
      piid: piid,
      value: value
    }];
    const results = await this.client.setProperties(params);
    if (results.length === 0) {
      return undefined;
    }
    return results[0];
  }

  async callAction(did: string, siid: number, aiid: number, inList: Object[]): Promise<Record<string, Object> | undefined> {
    const param: MijiaActionParam = {
      did: did,
      siid: siid,
      aiid: aiid,
      in: inList
    };
    return this.client.runAction(param);
  }
}

interface MijiaPropertyParam {
  did: string;
  siid: number;
  piid: number;
}

interface MijiaSetPropertyParam extends MijiaPropertyParam {
  value: Object;
}

interface MijiaActionParam {
  did: string;
  siid: number;
  aiid: number;
  in: Object[];
}
