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
  MIoTSpecInstance,
  parseMIoTSpecInstance
} from '../models/MIotSpecModels';
import { MIoTParseError } from '../models/XiaomiErrors';
import { XiaomiHttpClient } from '../network/XiaomiHttpClient';

const MIOT_SPEC_INSTANCE_URL = 'https://miot-spec.org/miot-spec-v2/instance';

export class MIoTSpecParser {
  private readonly cache: Map<string, MIoTSpecInstance> = new Map();

  async parse(urn: string, skipCache: boolean = false): Promise<MIoTSpecInstance> {
    const normalizedUrn = urn.trim();
    if (normalizedUrn.length === 0) {
      throw new MIoTParseError('empty miot spec urn');
    }
    if (!skipCache) {
      const cached = this.cache.get(normalizedUrn);
      if (cached !== undefined) {
        return cached;
      }
    }
    const raw = await this.fetchInstance(normalizedUrn);
    const instance = parseMIoTSpecInstance(raw);
    this.cache.set(normalizedUrn, instance);
    return instance;
  }

  async refresh(urnList: string[]): Promise<number> {
    let successCount = 0;
    for (let i = 0; i < urnList.length; i++) {
      try {
        await this.parse(urnList[i], true);
        successCount += 1;
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        throw new MIoTParseError(`spec refresh failed: ${message}`);
      }
    }
    return successCount;
  }

  clearCache(): void {
    this.cache.clear();
  }

  private async fetchInstance(urn: string): Promise<Record<string, Object>> {
    const url = `${MIOT_SPEC_INSTANCE_URL}?type=${encodeURIComponent(urn)}`;
    const response = await XiaomiHttpClient.get(url);
    if (response.status !== 200) {
      throw new MIoTParseError(`miot spec status ${response.status}`);
    }
    let parsed: Object;
    try {
      parsed = JSON.parse(response.body) as Object;
    } catch (err) {
      throw new MIoTParseError('invalid miot spec json');
    }
    if (parsed === null || parsed === undefined) {
      throw new MIoTParseError('empty miot spec response');
    }
    return parsed as Record<string, Object>;
  }
}
