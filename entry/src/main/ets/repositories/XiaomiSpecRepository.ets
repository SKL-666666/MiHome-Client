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

import { MIoTSpecInstance, parseMIoTSpecInstance } from '../models/MIotSpecModels';
import { MIoTSpecParser } from '../miot/MIoTSpecParser';
import { JsonCache } from '../storage/JsonCache';
import { Logger } from '../utils/Logger';

const PREFIX = 'miot_spec_v1_';

export class XiaomiSpecRepository {
  private readonly parser: MIoTSpecParser;
  private readonly cache: JsonCache;

  constructor(parser: MIoTSpecParser, cache: JsonCache) {
    this.parser = parser;
    this.cache = cache;
  }

  async get(urn: string, forceRefresh: boolean = false): Promise<MIoTSpecInstance> {
    if (!forceRefresh) {
      const cached = this.readCache(urn);
      if (cached !== null) {
        return cached;
      }
    }
    const spec = await this.parser.parse(urn, true);
    this.cache.set(`${PREFIX}${urn}`, JSON.stringify(spec));
    return spec;
  }

  readCache(urn: string): MIoTSpecInstance | null {
    const raw = this.cache.get(`${PREFIX}${urn}`);
    if (raw.length === 0) {
      return null;
    }
    try {
      return parseMIoTSpecInstance(JSON.parse(raw) as Record<string, Object>);
    } catch (err) {
      Logger.warn('invalid cached spec, %{public}s', urn);
      return null;
    }
  }
}
