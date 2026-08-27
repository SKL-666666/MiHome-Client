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

import { XiaomiCloudClient } from '../cloud/XiaomiCloudClient';
import {
  DevicePropertyParam,
  DevicePropertyResult,
  SelectableDeviceTransport
} from './DeviceTransport';

export class CloudDeviceTransport implements SelectableDeviceTransport {
  private readonly cloudClient: XiaomiCloudClient;
  readonly kind: string = 'cloud';

  constructor(cloudClient: XiaomiCloudClient) {
    this.cloudClient = cloudClient;
  }

  async getProperty(did: string, siid: number, piid: number): Promise<Object | undefined> {
    const results = await this.cloudClient.getDeviceProperties([{
      did: did,
      siid: siid,
      piid: piid
    }]);
    if (results.length === 0) {
      return undefined;
    }
    return results[0].value;
  }

  async getProperties(did: string, params: DevicePropertyParam[]): Promise<DevicePropertyResult[]> {
    const results = await this.cloudClient.getDeviceProperties(params);
    const mapped: DevicePropertyResult[] = [];
    for (let i = 0; i < results.length; i++) {
      mapped.push({
        did: results[i].did,
        siid: results[i].siid,
        piid: results[i].piid,
        value: results[i].value
      });
    }
    return mapped;
  }

  async setProperty(did: string, siid: number, piid: number, value: Object): Promise<Object | undefined> {
    const results = await this.cloudClient.setDeviceProperty(did, siid, piid, value);
    if (results.length === 0) {
      return undefined;
    }
    return results[0].value;
  }

  async callAction(did: string, siid: number, aiid: number, inList: Object[]): Promise<Record<string, Object> | undefined> {
    return this.cloudClient.callDeviceAction(did, siid, aiid, inList);
  }

  async isAvailable(): Promise<boolean> {
    return true;
  }
}
