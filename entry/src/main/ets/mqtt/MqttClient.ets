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

import { XiaomiCloudError } from '../models/XiaomiErrors';

export enum MqttConnectionState {
  DISCONNECTED = 'disconnected',
  CONNECTING = 'connecting',
  CONNECTED = 'connected',
  RECONNECTING = 'reconnecting',
  CLOSED = 'closed',
  ERROR = 'error'
}

export interface MqttClientConfig {
  host: string;
  port: number;
  clientId: string;
  username: string;
  password: string;
  useTls: boolean;
  caCert: string;
  keepAliveSeconds: number;
  reconnectMinMs: number;
  reconnectMaxMs: number;
}

export type MqttMessageListener = (topic: string, payload: Uint8Array) => void;
export type MqttStateListener = (state: MqttConnectionState) => void;

export class XiaomiMqttClient {
  private state: MqttConnectionState = MqttConnectionState.DISCONNECTED;
  private config: MqttClientConfig | null = null;
  private readonly subscriptions: Map<string, MqttMessageListener[]> = new Map();
  private readonly stateListeners: MqttStateListener[] = [];

  configure(config: MqttClientConfig): void {
    this.config = config;
  }

  getState(): MqttConnectionState {
    return this.state;
  }

  subscribe(topic: string, listener: MqttMessageListener): () => void {
    let list = this.subscriptions.get(topic);
    if (list === undefined) {
      list = [];
      this.subscriptions.set(topic, list);
    }
    list.push(listener);
    return (): void => {
      this.unsubscribe(topic, listener);
    };
  }

  unsubscribe(topic: string, listener: MqttMessageListener): void {
    const list = this.subscriptions.get(topic);
    if (list === undefined) {
      return;
    }
    const index = list.indexOf(listener);
    if (index >= 0) {
      list.splice(index, 1);
    }
    if (list.length === 0) {
      this.subscriptions.delete(topic);
    }
  }

  addStateListener(listener: MqttStateListener): void {
    this.stateListeners.push(listener);
  }

  removeStateListener(listener: MqttStateListener): void {
    const index = this.stateListeners.indexOf(listener);
    if (index >= 0) {
      this.stateListeners.splice(index, 1);
    }
  }

  async connect(): Promise<void> {
    if (this.config === null) {
      throw new XiaomiCloudError('mqtt config is UNVERIFIED/BLOCKED');
    }
    if (this.config.host.trim().length === 0) {
      throw new XiaomiCloudError('mqtt host is not configured');
    }
    this.setState(MqttConnectionState.CONNECTING);
    // The private Xiaomi MQTT broker, TLS certificate and packet flow are not
    // implemented from public evidence. The connection intentionally stops here.
    this.setState(MqttConnectionState.ERROR);
    throw new XiaomiCloudError('MQTT transport not implemented: private Xiaomi parameters UNVERIFIED');
  }

  disconnect(): void {
    this.setState(MqttConnectionState.CLOSED);
  }

  markConnectedForMock(): void {
    this.setState(MqttConnectionState.CONNECTED);
  }

  deliverMockMessage(topic: string, payload: Uint8Array): void {
    const list = this.subscriptions.get(topic);
    if (list === undefined) {
      return;
    }
    for (let i = 0; i < list.length; i++) {
      list[i](topic, payload);
    }
  }

  private setState(state: MqttConnectionState): void {
    this.state = state;
    for (let i = 0; i < this.stateListeners.length; i++) {
      this.stateListeners[i](state);
    }
  }
}
