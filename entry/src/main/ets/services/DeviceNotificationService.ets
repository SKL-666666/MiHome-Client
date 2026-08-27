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
import {
  DeviceEvent,
  DeviceEventBus,
  DeviceEventName
} from '../events/DeviceEventBus';
import { Logger } from '../utils/Logger';

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
    try {
      await notificationManager.publish(request);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      Logger.error('publish device notification failed, %{public}s', message);
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
    return String(name);
  }
}
