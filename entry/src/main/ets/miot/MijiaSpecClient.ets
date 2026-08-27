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
  parseMijiaSpecPageJson
} from '../models/MIotSpecModels';
import { MIoTParseError } from '../models/XiaomiErrors';
import { XiaomiHttpClient } from '../network/XiaomiHttpClient';

const MIJIA_SPEC_BASE_URL = 'https://home.miot-spec.com/spec/';

export class MijiaSpecClient {
  async getByModel(model: string): Promise<MIoTSpecInstance> {
    const encodedModel = encodeURIComponent(model);
    const response = await XiaomiHttpClient.get(`${MIJIA_SPEC_BASE_URL}${encodedModel}`);
    if (response.status !== 200) {
      throw new MIoTParseError(`mijia spec status ${response.status}`);
    }
    const json = extractPageJson(response.body);
    if (json.length === 0) {
      throw new MIoTParseError('mijia spec page json not found');
    }
    try {
      return parseMijiaSpecPageJson(JSON.parse(json) as Record<string, Object>);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      throw new MIoTParseError(`parse mijia spec failed: ${message}`);
    }
  }
}

function extractPageJson(html: string): string {
  const pattern = /<script data-page="app" type="application\/json">([\s\S]*?)<\/script>/;
  const match = pattern.exec(html);
  if (match === null) {
    return '';
  }
  return match[1].trim();
}
