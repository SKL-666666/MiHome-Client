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

import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { MijiaAuthData } from '../cloud/MijiaApiClient';
import { XiaomiStorageError } from '../models/XiaomiErrors';
import { Logger } from '../utils/Logger';

const ASSET_ALIAS = 'mijia_auth_v1';

export class SecureMijiaAuthStorage {
  static async save(auth: MijiaAuthData): Promise<void> {
    try {
      await SecureMijiaAuthStorage.clear();
      const secret = new util.TextEncoder().encode(JSON.stringify(auth));
      const first = secret.slice(0, 1024);
      const rest = secret.slice(1024);
      const attributes = new Map<asset.Tag, asset.Value>();
      attributes.set(asset.Tag.ALIAS, new util.TextEncoder().encode(ASSET_ALIAS));
      attributes.set(asset.Tag.SECRET, first);
      if (rest.length > 0) {
        attributes.set(asset.Tag.DATA_LABEL_NORMAL_1, rest);
      }
      attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
      attributes.set(asset.Tag.REQUIRE_PASSWORD_SET, false);
      attributes.set(asset.Tag.AUTH_TYPE, asset.AuthType.NONE);
      attributes.set(asset.Tag.SYNC_TYPE, asset.SyncType.NEVER);
       attributes.set(asset.Tag.IS_PERSISTENT, true);
      attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE);
      await asset.add(attributes);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      Logger.error('mijia auth save failed, %{public}s', message);
      throw new XiaomiStorageError(message);
    }
  }

  static async load(): Promise<MijiaAuthData | null> {
    try {
      const query = new Map<asset.Tag, asset.Value>();
      query.set(asset.Tag.ALIAS, new util.TextEncoder().encode(ASSET_ALIAS));
      query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
      const result = await asset.query(query);
      if (result.length === 0) {
        return null;
      }
      const secret = result[0].get(asset.Tag.SECRET);
      if (secret === undefined || secret === null || typeof secret !== 'object') {
        return null;
      }
      const first = secret as Uint8Array;
      const rest = result[0].get(asset.Tag.DATA_LABEL_NORMAL_1);
      const bytes = rest !== undefined && rest !== null && typeof rest === 'object'
        ? concatBytes(first, rest as Uint8Array)
        : first;
      return JSON.parse(new util.TextDecoder('utf-8').decode(bytes)) as MijiaAuthData;
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      Logger.error('mijia auth load failed, %{public}s', message);
      throw new XiaomiStorageError(message);
    }
  }

  static async clear(): Promise<void> {
    try {
      const query = new Map<asset.Tag, asset.Value>();
      query.set(asset.Tag.ALIAS, new util.TextEncoder().encode(ASSET_ALIAS));
      await asset.remove(query);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      if (!message.includes('24000002')) {
        Logger.warn('mijia auth clear warning, %{public}s', message);
      }
    }
  }
}

function concatBytes(a: Uint8Array, b: Uint8Array): Uint8Array {
  const result = new Uint8Array(a.length + b.length);
  result.set(a, 0);
  result.set(b, a.length);
  return result;
}
