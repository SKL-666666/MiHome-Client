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
import { MIoTSpecInstance } from '../models/MIotSpecModels';
import { XiaomiAuthError, XiaomiErrorCode } from '../models/XiaomiErrors';
import { XiaomiDevice, XiaomiHome, XiaomiScene, XiaomiUser } from '../models/XiaomiHomeModels';
import { MIoTSpecParser } from '../miot/MIoTSpecParser';
import { SecureAuthStorage } from '../storage/SecureAuthStorage';
import { DeviceController } from '../controllers/DeviceController';
import { DeviceEventBus } from '../events/DeviceEventBus';
import { CloudDeviceTransport } from '../controllers/CloudDeviceTransport';
import { XiaomiHomeSnapshot } from '../models/CacheState';
import { JsonCache } from '../storage/JsonCache';
import { XiaomiHomeRepository } from '../repositories/XiaomiHomeRepository';
import { XiaomiSpecRepository } from '../repositories/XiaomiSpecRepository';
import { MijiaApiClient, MijiaAuthData, MijiaConsumableItem, MijiaMessageItem } from '../cloud/MijiaApiClient';
import { SecureMijiaAuthStorage } from '../storage/SecureMijiaAuthStorage';
import { MijiaDeviceTransport } from '../controllers/MijiaDeviceTransport';
import { MijiaSpecClient } from '../miot/MijiaSpecClient';
import { LanDeviceTransport } from '../lan/LanDeviceTransport';
import { LanDeviceSession } from '../models/LanDeviceSession';

export class XiaomiDataService {
  private mijiaAuth: MijiaAuthData | null = null;
  private mijiaClient: MijiaApiClient | null = null;
  private readonly specParser: MIoTSpecParser = new MIoTSpecParser();
  private readonly mijiaSpecClient: MijiaSpecClient = new MijiaSpecClient();
  private readonly eventBus: DeviceEventBus = new DeviceEventBus();
  private readonly lanTransports: Map<string, LanDeviceTransport> = new Map();
  private readonly lanSessionSignatures: Map<string, string> = new Map();

  async ensureReady(): Promise<void> {
    if (this.mijiaClient !== null && this.mijiaAuth !== null) {
      return;
    }
    const stored = await SecureMijiaAuthStorage.load();
    if (stored === null) {
      throw new XiaomiAuthError(XiaomiErrorCode.AUTH_TOKEN_EXPIRED, 'not authenticated');
    }
    this.mijiaAuth = stored;
    this.mijiaClient = new MijiaApiClient(stored);
  }

  async setMijiaAuth(auth: MijiaAuthData): Promise<void> {
    await SecureMijiaAuthStorage.save(auth);
    this.mijiaAuth = auth;
    this.mijiaClient = new MijiaApiClient(auth);
  }

  async getMijiaAuth(): Promise<MijiaAuthData | null> {
    if (this.mijiaAuth !== null) {
      return this.mijiaAuth;
    }
    return SecureMijiaAuthStorage.load();
  }

  /**
   * UNVERIFIED: the current `sid=mijia` QR login flow does not expose a
   * verified Xiaomi account nickname/avatar endpoint. The upstream OAuth
   * profile endpoint requires an OAuth access token and client id, which this
   * login path intentionally does not use. Keep this method returning null
   * instead of fabricating a request URL or response.
   */
  async getUserProfile(): Promise<XiaomiUser | null> {
    return null;
  }

  async isAuthenticated(): Promise<boolean> {
    return (await this.getMijiaAuth()) !== null;
  }

  async getHomes(): Promise<XiaomiHome[]> {
    await this.ensureReady();
    return this.mijiaClient!.getHomes();
  }

  async getDevices(homeIds?: string[]): Promise<Record<string, XiaomiDevice>> {
    await this.ensureReady();
    return this.mijiaClient!.getDevices(homeIds);
  }

  async getScenes(homeId: string): Promise<XiaomiScene[]> {
    await this.ensureReady();
    return this.mijiaClient!.getScenes(homeId);
  }

  async runScene(sceneId: string, homeId: string): Promise<Record<string, Object>> {
    await this.ensureReady();
    return this.mijiaClient!.runScene(sceneId, homeId);
  }

  async getDeviceSpec(urn: string): Promise<MIoTSpecInstance> {
    await this.ensureReady();
    return this.specParser.parse(urn);
  }

  async getDeviceSpecForDevice(device: XiaomiDevice): Promise<MIoTSpecInstance> {
    await this.ensureReady();
    if (device.urn.length > 0) {
      return this.specParser.parse(device.urn);
    }
    return this.mijiaSpecClient.getByModel(device.model);
  }

  async getDeviceSpecCached(
    urn: string,
    context: common.UIAbilityContext,
    forceRefresh: boolean = false
  ): Promise<MIoTSpecInstance> {
    await this.ensureReady();
    const repository = new XiaomiSpecRepository(this.specParser, new JsonCache(context));
    return repository.get(urn, forceRefresh);
  }

  async getHomeSnapshot(
    context: common.UIAbilityContext,
    forceRefresh: boolean = false
  ): Promise<XiaomiHomeSnapshot> {
    await this.ensureReady();
    const repository = new XiaomiHomeRepository(this.mijiaClient!, new JsonCache(context));
    return repository.loadSnapshot(forceRefresh);
  }

  async getDeviceController(device?: XiaomiDevice): Promise<DeviceController> {
    await this.ensureReady();
    const cloudTransport = new MijiaDeviceTransport(this.mijiaClient!);
    if (device !== undefined && device.token.length >= 32 && device.localIp.length > 0) {
      const session: LanDeviceSession = {
        did: device.did,
        address: device.localIp,
        port: 54321,
        tokenHex: device.token,
        keyHex: '',
        ivHex: ''
      };
      const signature = `${device.localIp}:${device.token}`;
      let lanTransport = this.lanTransports.get(device.did);
      if (lanTransport !== undefined && this.lanSessionSignatures.get(device.did) !== signature) {
        await lanTransport.close();
        lanTransport = undefined;
      }
      if (lanTransport === undefined) {
        lanTransport = new LanDeviceTransport();
        lanTransport.connect(session);
        this.lanTransports.set(device.did, lanTransport);
      } else {
        lanTransport.connect(session);
      }
      this.lanSessionSignatures.set(device.did, signature);
      return new DeviceController(cloudTransport, this.eventBus, lanTransport);
    }
    return new DeviceController(cloudTransport, this.eventBus);
  }

  async getDeviceStatistics(
    did: string,
    key: string,
    dataType: string,
    limit: number,
    timeStart: number,
    timeEnd: number
  ): Promise<Object[]> {
    await this.ensureReady();
    return this.mijiaClient!.getStatistics(did, key, dataType, limit, timeStart, timeEnd);
  }

  async checkCloudMessages(beginAt?: number): Promise<Record<string, Object>> {
    await this.ensureReady();
    return this.mijiaClient!.checkNewMsg(beginAt);
  }

  async getCloudMessageList(homeId: string): Promise<MijiaMessageItem[]> {
    await this.ensureReady();
    return this.mijiaClient!.getMessageList(homeId);
  }

  async getConsumableItems(homeId: string): Promise<MijiaConsumableItem[]> {
    await this.ensureReady();
    const ownerUid = await this.mijiaClient!.getHomeOwner(homeId);
    return this.mijiaClient!.getConsumableItems(homeId, ownerUid);
  }

  getEventBus(): DeviceEventBus {
    return this.eventBus;
  }

  async clearSession(): Promise<void> {
    this.mijiaAuth = null;
    this.mijiaClient = null;
    const transports = Array.from(this.lanTransports.values());
    this.lanTransports.clear();
    this.lanSessionSignatures.clear();
    for (let i = 0; i < transports.length; i++) {
      try {
        await transports[i].close();
      } catch (err) {
      }
    }
    await SecureMijiaAuthStorage.clear();
  }
}

export const xiaomiDataService = new XiaomiDataService();
