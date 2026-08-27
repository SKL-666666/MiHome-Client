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
  DevicePropertyParam,
  DevicePropertyResult,
  SelectableDeviceTransport
} from '../controllers/DeviceTransport';
import { LanDeviceSession } from '../models/LanDeviceSession';
import { LanConnectionError } from '../models/XiaomiErrors';
import { LanUdpSocket } from './LanUdpSocket';
import { buildLanPacket, decryptLanPacket } from './LanCrypto';

export class LanDeviceTransport implements SelectableDeviceTransport {
  readonly kind: string = 'lan';
  private session: LanDeviceSession | null = null;
  private readonly udp: LanUdpSocket = new LanUdpSocket();
  private msgId: number = Math.floor(Math.random() * 0x7FFFFFFF);

  connect(session: LanDeviceSession): void {
    this.session = session;
  }

  disconnect(): void {
    this.session = null;
  }

  async isAvailable(): Promise<boolean> {
    return this.session !== null && this.session.address.length > 0;
  }

  async getProperty(did: string, siid: number, piid: number): Promise<Object | undefined> {
    this.ensureSession(did);
    const fullMsg: LanGetMessage = {
      id: this.nextMsgId(),
      from: 'xiaomi_home_harmony',
      method: 'get_properties',
      params: [{ did: did, siid: siid, piid: piid }]
    };
    const result = await this.request(did, fullMsg);
    const resultList = result['result'];
    if (resultList instanceof Array && resultList.length === 1) {
      return (resultList[0] as Record<string, Object>)['value'];
    }
    return undefined;
  }

  async getProperties(did: string, params: DevicePropertyParam[]): Promise<DevicePropertyResult[]> {
    this.ensureSession(did);
    const requestParams: LanPropertyParam[] = [];
    for (let i = 0; i < params.length; i++) {
      requestParams.push({
        did: params[i].did,
        siid: params[i].siid,
        piid: params[i].piid
      });
    }
    const fullMsg: LanGetMessage = {
      id: this.nextMsgId(),
      from: 'xiaomi_home_harmony',
      method: 'get_properties',
      params: requestParams
    };
    const result = await this.request(did, fullMsg);
    const resultList = result['result'];
    const byKey = new Map<string, Object | undefined>();
    if (resultList instanceof Array) {
      for (let i = 0; i < resultList.length; i++) {
        const raw = resultList[i] as Record<string, Object>;
        byKey.set(`${String(raw['did'])}.${String(raw['siid'])}.${String(raw['piid'])}`, raw['value']);
      }
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
    this.ensureSession(did);
    const fullMsg: LanSetMessage = {
      id: this.nextMsgId(),
      from: 'xiaomi_home_harmony',
      method: 'set_properties',
      params: [{ did: did, siid: siid, piid: piid, value: value }]
    };
    const result = await this.request(did, fullMsg);
    const resultList = result['result'];
    if (resultList instanceof Array && resultList.length === 1) {
      return resultList[0] as Object;
    }
    return result;
  }

  async callAction(did: string, siid: number, aiid: number, inList: Object[]): Promise<Record<string, Object> | undefined> {
    this.ensureSession(did);
    const fullMsg: LanActionMessage = {
      id: this.nextMsgId(),
      from: 'xiaomi_home_harmony',
      method: 'action',
      params: {
        did: did,
        siid: siid,
        aiid: aiid,
        in: inList
      }
    };
    const result = await this.request(did, fullMsg);
    return result;
  }

  async sendRaw(payload: Uint8Array, retries: number = 1): Promise<void> {
    if (this.session === null) {
      throw new LanConnectionError('lan session not configured');
    }
    await this.udp.start();
    let lastError: Error | undefined;
    for (let i = 0; i <= retries; i++) {
      try {
        await this.udp.send(this.session.address, this.session.port, payload);
        return;
      } catch (err) {
        lastError = err instanceof Error ? err : new Error(String(err));
      }
    }
    throw lastError ?? new LanConnectionError('udp send failed');
  }

  async close(): Promise<void> {
    await this.udp.close();
  }

  private ensureSession(did: string): void {
    if (this.session === null || this.session.did !== did) {
      throw new LanConnectionError('lan session unavailable');
    }
  }

  private async request(did: string, msg: Object): Promise<Record<string, Object>> {
    if (this.session === null) {
      throw new LanConnectionError('lan session not configured');
    }
    const token = hexToBytes(this.session.tokenHex);
    const packet = await buildLanPacket(token, did, msg, 0);
    const responseBytes = await this.udp.request(
      this.session.address,
      this.session.port,
      packet,
      10000
    );
    return decryptLanPacket(token, responseBytes);
  }

  private nextMsgId(): number {
    this.msgId += 1;
    if (this.msgId > 0x7FFFFFFF) {
      this.msgId = 1;
    }
    return this.msgId;
  }
}

interface LanPropertyParam {
  did: string;
  siid: number;
  piid: number;
}

interface LanSetPropertyParam extends LanPropertyParam {
  value: Object;
}

interface LanGetMessage {
  id: number;
  from: string;
  method: string;
  params: LanPropertyParam[];
}

interface LanSetMessage {
  id: number;
  from: string;
  method: string;
  params: LanSetPropertyParam[];
}

interface LanActionParams {
  did: string;
  siid: number;
  aiid: number;
  in: Object[];
}

interface LanActionMessage {
  id: number;
  from: string;
  method: string;
  params: LanActionParams;
}

function hexToBytes(hex: string): Uint8Array {
  const clean = hex.replace(/\s/g, '');
  const result = new Uint8Array(Math.floor(clean.length / 2));
  for (let i = 0; i < result.length; i++) {
    result[i] = parseInt(clean.substring(i * 2, i * 2 + 2), 16);
  }
  return result;
}
