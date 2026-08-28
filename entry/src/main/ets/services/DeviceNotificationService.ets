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

import { notificationManager } from '@kit.NotificationKit';
import { wantAgent, Want, WantAgent } from '@kit.AbilityKit';
import {
  DeviceEvent,
  DeviceEventBus,
  DeviceEventName
} from '../events/DeviceEventBus';
import { Logger } from '../utils/Logger';
import { translateMiotText } from '../components/CapabilityRenderer';

const ENTRY_ABILITY_BUNDLE: string = 'com.miju.client';
const ENTRY_ABILITY_NAME: string = 'EntryAbility';

export class DeviceNotificationService {
  private readonly eventBus: DeviceEventBus;
  private nextId: number = 1000;

  constructor(eventBus: DeviceEventBus) {
    this.eventBus = eventBus;
  }

  start(): void {
    this.eventBus.subscribe('device_offline', (event: DeviceEvent): void => {
      this.publishForEvent(event);
    });
    this.eventBus.subscribe('device_online', (event: DeviceEvent): void => {
      this.publishForEvent(event);
    });
    this.eventBus.subscribe('event', (event: DeviceEvent): void => {
      this.publishForEvent(event);
    });
    this.eventBus.subscribe('action_result', (event: DeviceEvent): void => {
      this.publishForEvent(event);
    });
  }

  async publishForEvent(event: DeviceEvent): Promise<void> {
    const text = this.formatEvent(event);
    const request: notificationManager.NotificationRequest = {
      id: this.nextId,
      content: {
        contentType: 0,
        normal: {
          title: '米家控制',
          text: text,
          additionalText: event.did
        }
      }
    };
    this.nextId += 1;
    // 点击通知直达设备详情：为通知绑定携带 did 的 wantAgent
    const agent = await this.buildDeviceWantAgent(event.did);
    if (agent !== null) {
      request.wantAgent = agent;
    }
    try {
      await notificationManager.publish(request);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      Logger.error('publish device notification failed, %{public}s', message);
    }
  }

  private async buildDeviceWantAgent(did: string): Promise<WantAgent | null> {
    if (did.length === 0) {
      return null;
    }
    const parameters: Record<string, Object> = { 'deviceDid': did };
    const target: Want = {
      bundleName: ENTRY_ABILITY_BUNDLE,
      abilityName: ENTRY_ABILITY_NAME,
      parameters: parameters
    };
    const info: wantAgent.WantAgentInfo = {
      wants: [target],
      operationType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    try {
      return await wantAgent.getWantAgent(info);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      Logger.error('build device want agent failed, %{public}s', message);
      return null;
    }
  }

  private formatEvent(event: DeviceEvent): string {
    if (event.type === 'device_online') {
      return '设备上线';
    }
    if (event.type === 'device_offline') {
      return '设备离线';
    }
    if (event.type === 'action_result') {
      return '设备动作已完成';
    }
    const payload = event.payload as Record<string, Object>;
    const name = payload['name'] ?? payload['description'] ?? '设备事件';
    return translateMiotText(String(name));
  }
}
