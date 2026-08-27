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

export type DeviceEventName =
  | 'property_changed'
  | 'device_online'
  | 'device_offline'
  | 'event'
  | 'action_result'
  | 'transport_state'
  | 'error';

export interface DeviceEvent {
  type: DeviceEventName;
  did: string;
  payload: Object;
  source?: string;
  timestamp: number;
}

export type DeviceEventListener = (event: DeviceEvent) => void;

export class DeviceEventBus {
  private readonly listeners: Map<DeviceEventName, DeviceEventListener[]> = new Map();

  subscribe(type: DeviceEventName, listener: DeviceEventListener): () => void {
    let list = this.listeners.get(type);
    if (list === undefined) {
      list = [];
      this.listeners.set(type, list);
    }
    list.push(listener);
    return (): void => {
      this.unsubscribe(type, listener);
    };
  }

  unsubscribe(type: DeviceEventName, listener: DeviceEventListener): void {
    const list = this.listeners.get(type);
    if (list === undefined) {
      return;
    }
    const index = list.indexOf(listener);
    if (index >= 0) {
      list.splice(index, 1);
    }
    if (list.length === 0) {
      this.listeners.delete(type);
    }
  }

  publish(type: DeviceEventName, did: string, payload: Object, source?: string): void {
    const list = this.listeners.get(type);
    if (list === undefined) {
      return;
    }
    const event: DeviceEvent = {
      type: type,
      did: did,
      payload: payload,
      source: source,
      timestamp: Date.now()
    };
    for (let i = 0; i < list.length; i++) {
      list[i](event);
    }
  }
}
