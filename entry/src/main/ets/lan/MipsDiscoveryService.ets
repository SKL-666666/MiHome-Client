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

import { common } from '@kit.AbilityKit';
import { mdns } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { MipsServiceInfo } from '../models/MipsServiceInfo';
import { LanConnectionError } from '../models/XiaomiErrors';
import { Logger } from '../utils/Logger';

const MIPS_MDNS_TYPE = '_miot-central._tcp.local.';

export type MipsDiscoveryListener = (services: MipsServiceInfo[]) => void;

export class MipsDiscoveryService {
  private discoveryService: mdns.DiscoveryService | null = null;
  private readonly services: Map<string, MipsServiceInfo> = new Map();
  private listener: MipsDiscoveryListener | null = null;

  start(context: common.UIAbilityContext): void {
    if (this.discoveryService !== null) {
      return;
    }
    const discovery = mdns.createDiscoveryService(context, MIPS_MDNS_TYPE);
    discovery.on('serviceFound', (serviceInfo: mdns.LocalServiceInfo): void => {
      this.handleServiceFound(serviceInfo);
    });
    discovery.on('serviceLost', (serviceInfo: mdns.LocalServiceInfo): void => {
      this.handleServiceLost(serviceInfo);
    });
    discovery.startSearchingMDNS();
    this.discoveryService = discovery;
    Logger.info('mips mDNS discovery started');
  }

  stop(): void {
    if (this.discoveryService === null) {
      return;
    }
    this.discoveryService.stopSearchingMDNS();
    this.discoveryService = null;
    this.services.clear();
    Logger.info('mips mDNS discovery stopped');
  }

  setListener(listener: MipsDiscoveryListener | null): void {
    this.listener = listener;
  }

  getServices(): MipsServiceInfo[] {
    const result: MipsServiceInfo[] = [];
    const keys = Array.from(this.services.keys());
    for (let i = 0; i < keys.length; i++) {
      const service = this.services.get(keys[i]);
      if (service !== undefined) {
        result.push(service);
      }
    }
    return result;
  }

  private handleServiceFound(serviceInfo: mdns.LocalServiceInfo): void {
    try {
      const parsed = parseMipsService(serviceInfo);
      if (parsed.role !== 1 || !parsed.suiteMqtt) {
        return;
      }
      this.services.set(parsed.groupId, parsed);
      this.notify();
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      Logger.warn('invalid mips service, %{public}s', message);
    }
  }

  private handleServiceLost(serviceInfo: mdns.LocalServiceInfo): void {
    const serviceName = serviceInfo.serviceName ?? '';
    const keys = Array.from(this.services.keys());
    for (let i = 0; i < keys.length; i++) {
      const service = this.services.get(keys[i]);
      if (service !== undefined && service.name === serviceName) {
        this.services.delete(keys[i]);
        this.notify();
        return;
      }
    }
  }

  private notify(): void {
    if (this.listener !== null) {
      this.listener(this.getServices());
    }
  }
}

function parseMipsService(serviceInfo: mdns.LocalServiceInfo): MipsServiceInfo {
  const attributes = serviceInfo.serviceAttribute ?? [];
  let profile: Uint8Array | null = null;
  for (let i = 0; i < attributes.length; i++) {
    if (attributes[i].key === 'profile') {
      const text = arrayToString(attributes[i].value);
      profile = new util.Base64Helper().decodeSync(text);
      break;
    }
  }
  if (profile === null || profile.length < 23) {
    throw new LanConnectionError('missing or invalid mips profile');
  }
  return {
    name: serviceInfo.serviceName ?? '',
    serviceType: serviceInfo.serviceType ?? MIPS_MDNS_TYPE,
    addresses: serviceInfo.host !== undefined && serviceInfo.host.address !== undefined
      ? [serviceInfo.host.address]
      : [],
    port: serviceInfo.port ?? 0,
    did: readUint64Decimal(profile, 1),
    groupId: bytesToHex(reverseBytes(profile.slice(9, 17))),
    role: (profile[20] >> 4) & 0x0F,
    suiteMqtt: ((profile[22] >> 1) & 0x01) === 0x01
  };
}

function arrayToString(value: Array<number>): string {
  const bytes = new Uint8Array(value.length);
  for (let i = 0; i < value.length; i++) {
    bytes[i] = value[i];
  }
  return new util.TextDecoder('utf-8').decode(bytes);
}

function readUint64Decimal(value: Uint8Array, offset: number): string {
  const digits: number[] = [0];
  for (let i = 0; i < 8; i++) {
    let carry = value[offset + i] & 0xFF;
    for (let j = 0; j < digits.length; j++) {
      const next = digits[j] * 256 + carry;
      digits[j] = next % 10;
      carry = Math.floor(next / 10);
    }
    while (carry > 0) {
      digits.push(carry % 10);
      carry = Math.floor(carry / 10);
    }
  }
  let result = '';
  for (let i = digits.length - 1; i >= 0; i--) {
    result += digits[i].toString();
  }
  return result;
}

function reverseBytes(value: Uint8Array): Uint8Array {
  const result = new Uint8Array(value.length);
  for (let i = 0; i < value.length; i++) {
    result[i] = value[value.length - 1 - i];
  }
  return result;
}

function bytesToHex(value: Uint8Array): string {
  let result = '';
  for (let i = 0; i < value.length; i++) {
    result += value[i].toString(16).padStart(2, '0');
  }
  return result;
}
