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
import { ASSET_ALIAS_AUTH_INFO } from '../models/XiaomiConfig';
import { XiaomiAuthInfo } from '../models/XiaomiAuthInfo';
import { XiaomiStorageError } from '../models/XiaomiErrors';
import { Logger } from '../utils/Logger';

function encode(value: string): Uint8Array {
  return new util.TextEncoder().encode(value);
}

function decode(value: Uint8Array): string {
  return new util.TextDecoder('utf-8').decode(value);
}

export class SecureAuthStorage {
  static async save(authInfo: XiaomiAuthInfo): Promise<void> {
    try {
      await SecureAuthStorage.clear();
      const attributes = new Map<asset.Tag, asset.Value>();
      attributes.set(asset.Tag.ALIAS, encode(ASSET_ALIAS_AUTH_INFO));
      attributes.set(asset.Tag.SECRET, encode(JSON.stringify(authInfo)));
      attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
      attributes.set(asset.Tag.REQUIRE_PASSWORD_SET, false);
      attributes.set(asset.Tag.AUTH_TYPE, asset.AuthType.NONE);
      attributes.set(asset.Tag.SYNC_TYPE, asset.SyncType.NEVER);
      attributes.set(asset.Tag.IS_PERSISTENT, true);
      attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE);
      await asset.add(attributes);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      Logger.error('secure storage save failed, %{public}s', message);
      throw new XiaomiStorageError(message);
    }
  }

  static async load(): Promise<XiaomiAuthInfo | null> {
    try {
      const query = new Map<asset.Tag, asset.Value>();
      query.set(asset.Tag.ALIAS, encode(ASSET_ALIAS_AUTH_INFO));
      query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
      const result = await asset.query(query);
      if (result.length === 0) {
        return null;
      }
      const secret = result[0].get(asset.Tag.SECRET);
      if (secret === undefined || secret === null || typeof secret !== 'object') {
        return null;
      }
      const bytes = secret as Uint8Array;
      return JSON.parse(decode(bytes)) as XiaomiAuthInfo;
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      Logger.error('secure storage load failed, %{public}s', message);
      throw new XiaomiStorageError(message);
    }
  }

  static async clear(): Promise<void> {
    try {
      const query = new Map<asset.Tag, asset.Value>();
      query.set(asset.Tag.ALIAS, encode(ASSET_ALIAS_AUTH_INFO));
      await asset.remove(query);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      if (message.includes('24000002')) {
        return;
      }
      Logger.warn('secure storage clear warning, %{public}s', message);
    }
  }
}
