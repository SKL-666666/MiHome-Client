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

import { DeviceEventBus, DeviceEventName, DeviceEventListener } from '../events/DeviceEventBus';
import { XiaomiDeviceOfflineError } from '../models/XiaomiErrors';
import { XiaomiCloudClient } from '../cloud/XiaomiCloudClient';
import { CloudDeviceTransport } from './CloudDeviceTransport';
import { FeedbackLogService } from '../services/FeedbackLogService';
import {
  DevicePropertyParam,
  DevicePropertyResult,
  SelectableDeviceTransport
} from './DeviceTransport';

export class DeviceController {
  private readonly transports: SelectableDeviceTransport[];
  private readonly eventBus: DeviceEventBus;

  constructor(
    cloudTransport: SelectableDeviceTransport,
    eventBus: DeviceEventBus = new DeviceEventBus(),
    lanTransport?: SelectableDeviceTransport,
    mqttTransport?: SelectableDeviceTransport
  ) {
    this.transports = [cloudTransport];
    if (lanTransport !== undefined) {
      this.transports.push(lanTransport);
    }
    if (mqttTransport !== undefined) {
      this.transports.push(mqttTransport);
    }
    this.eventBus = eventBus;
  }

  static fromCloudClient(
    cloudClient: XiaomiCloudClient
  ): DeviceController {
    return new DeviceController(new CloudDeviceTransport(cloudClient));
  }

  async getProperty(did: string, siid: number, piid: number): Promise<Object | undefined> {
    FeedbackLogService.recordOperation('DEVICE', `读取属性 did=${did} siid=${siid} piid=${piid}`);
    const result = await this.runWithFallback<Object | undefined>(async (transport: SelectableDeviceTransport) => {
      return transport.getProperty(did, siid, piid);
    });
    FeedbackLogService.recordOperation('DEVICE',
      `读取属性结果 did=${did} siid=${siid} piid=${piid} value=${result === undefined ? 'undefined' : JSON.stringify(result)}`);
    return result;
  }

  async getProperties(did: string, params: DevicePropertyParam[]): Promise<DevicePropertyResult[]> {
    FeedbackLogService.recordOperation('DEVICE', `批量读取属性 did=${did} count=${params.length}`);
    const result = await this.runWithFallback<DevicePropertyResult[]>(async (transport: SelectableDeviceTransport) => {
      return transport.getProperties(did, params);
    });
    FeedbackLogService.recordOperation('DEVICE',
      `批量读取属性结果 did=${did} count=${result.length} values=${JSON.stringify(result)}`);
    return result;
  }

  async setProperty(
    did: string,
    siid: number,
    piid: number,
    value: Object
  ): Promise<Object | undefined> {
    FeedbackLogService.recordOperation('DEVICE', `设置属性 did=${did} siid=${siid} piid=${piid}`);
    const result = await this.runWithFallback<Object | undefined>(async (transport: SelectableDeviceTransport) => {
      return transport.setProperty(did, siid, piid, value);
    });
    FeedbackLogService.recordOperation('DEVICE',
      `设置属性结果 did=${did} siid=${siid} piid=${piid} result=${result === undefined ? 'undefined' : JSON.stringify(result)}`);
    return result;
  }

  async callAction(
    did: string,
    siid: number,
    aiid: number,
    inList: Object[]
  ): Promise<Record<string, Object> | undefined> {
    FeedbackLogService.recordOperation('DEVICE', `调用动作 did=${did} siid=${siid} aiid=${aiid}`);
    const result = await this.runWithFallback<Record<string, Object> | undefined>(async (transport: SelectableDeviceTransport) => {
      return transport.callAction(did, siid, aiid, inList);
    });
    FeedbackLogService.recordOperation('DEVICE',
      `调用动作结果 did=${did} siid=${siid} aiid=${aiid} result=${result === undefined ? 'undefined' : JSON.stringify(result)}`);
    return result;
  }

  subscribeEvent(type: DeviceEventName, listener: DeviceEventListener): () => void {
    return this.eventBus.subscribe(type, listener);
  }

  publishEvent(type: DeviceEventName, did: string, payload: Record<string, Object>): void {
    this.eventBus.publish(type, did, payload);
  }

  async ensureOnline(did: string, online: boolean): Promise<void> {
    if (!online) {
      throw new XiaomiDeviceOfflineError(did);
    }
  }

  private async runWithFallback<T>(
    operation: (transport: SelectableDeviceTransport) => Promise<T>
  ): Promise<T> {
    let lastError: Error | undefined = undefined;
    for (let i = 0; i < this.transports.length; i++) {
      const transport = this.transports[i];
      try {
        if (await transport.isAvailable()) {
          return await operation(transport);
        }
      } catch (err) {
        lastError = err instanceof Error ? err : new Error(String(err));
        FeedbackLogService.recordError('DEVICE', `传输通道 ${transport.kind} 失败: ${lastError.message}`);
        const payload = new TransportErrorPayload(lastError.message, transport.kind);
        this.eventBus.publish('error', '', payload, transport.kind);
      }
    }
    if (lastError !== undefined) {
      throw lastError;
    }
    throw new Error('no available device transport');
  }
}

class TransportErrorPayload {
  readonly message: string;
  readonly transport: string;

  constructor(message: string, transport: string) {
    this.message = message;
    this.transport = transport;
  }
}
