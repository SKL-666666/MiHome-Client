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

import { DataSourceState, XiaomiHomeSnapshot } from '../models/CacheState';
import { MijiaApiClient } from '../cloud/MijiaApiClient';
import { JsonCache } from '../storage/JsonCache';
import { Logger } from '../utils/Logger';
import { cloneXiaomiDevice, XiaomiDevice } from '../models/XiaomiHomeModels';

const CACHE_KEY = 'home_snapshot_v1';
const CACHED_MAX_AGE_MS = 10 * 60 * 1000;
const STALE_MAX_AGE_MS = 60 * 60 * 1000;

export class XiaomiHomeRepository {
  private readonly dataSource: MijiaApiClient;
  private readonly cache: JsonCache;

  constructor(dataSource: MijiaApiClient, cache: JsonCache) {
    this.dataSource = dataSource;
    this.cache = cache;
  }

  async loadSnapshot(forceRefresh: boolean = false): Promise<XiaomiHomeSnapshot> {
    try {
      const homes = await this.dataSource.getHomes();
      const devices = await this.dataSource.getDevices();
      const snapshot: XiaomiHomeSnapshot = {
        state: DataSourceState.ONLINE,
        uid: '',
        homesJson: JSON.stringify(homes),
        devicesJson: JSON.stringify(stripDeviceTokens(devices)),
        updatedAt: Date.now()
      };
      this.cache.set(CACHE_KEY, JSON.stringify(snapshot));
      return snapshot;
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      Logger.warn('cloud snapshot failed, use cache, %{public}s', message);
      const cached = this.readCachedSnapshot();
      if (cached === null) {
        throw new Error(message);
      }
      return cached;
    }
  }

  readCachedSnapshot(): XiaomiHomeSnapshot | null {
    const raw = this.cache.get(CACHE_KEY);
    if (raw.length === 0) {
      return null;
    }
    try {
      const parsed = JSON.parse(raw) as XiaomiHomeSnapshot;
      if (parsed.devicesJson.length > 0) {
        try {
          const cachedDevices = JSON.parse(parsed.devicesJson) as Record<string, XiaomiDevice>;
          parsed.devicesJson = JSON.stringify(stripDeviceTokens(cachedDevices));
        } catch (err) {
          parsed.devicesJson = '{}';
        }
      }
      const age = Date.now() - parsed.updatedAt;
      if (age > STALE_MAX_AGE_MS) {
        parsed.state = DataSourceState.STALE;
      } else if (age > CACHED_MAX_AGE_MS) {
        parsed.state = DataSourceState.CACHED;
      } else {
        parsed.state = DataSourceState.CACHED;
      }
      return parsed;
    } catch (err) {
      Logger.warn('invalid cached snapshot');
      return null;
    }
  }
}

function stripDeviceTokens(devices: Record<string, XiaomiDevice>): Record<string, XiaomiDevice> {
  const sanitized: Record<string, XiaomiDevice> = {};
  const ids = Object.keys(devices);
  for (let i = 0; i < ids.length; i++) {
    const source = devices[ids[i]];
    const copy = cloneXiaomiDevice(source);
    copy.token = '';
    copy.subDevices = {};
    sanitized[ids[i]] = copy;
  }
  return sanitized;
}
