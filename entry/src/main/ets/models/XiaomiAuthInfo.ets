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

import { TOKEN_EXPIRES_TS_RATIO } from './XiaomiConfig';

export interface XiaomiAuthInfo {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  expiresTs: number;
  region: string;
  redirectUri: string;
  clientId: string;
  updatedAt: number;
}

export function createAuthInfoFromTokenResult(
  result: Record<string, Object>,
  region: string,
  redirectUri: string,
  clientId: string,
  nowMs: number
): XiaomiAuthInfo {
  const accessToken = asString(result['access_token']);
  const refreshToken = asString(result['refresh_token']);
  const expiresIn = asNumber(result['expires_in']);
  if (accessToken.length === 0 || refreshToken.length === 0 || expiresIn <= 0) {
    throw new Error('invalid token result');
  }
  const expiresSeconds = Math.floor(expiresIn * TOKEN_EXPIRES_TS_RATIO);
  return {
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresIn: expiresIn,
    expiresTs: nowMs + expiresSeconds * 1000,
    region: region,
    redirectUri: redirectUri,
    clientId: clientId,
    updatedAt: nowMs
  };
}

export function asString(value: Object | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  return String(value);
}

export function asNumber(value: Object | undefined): number {
  if (value === undefined || value === null) {
    return 0;
  }
  const num = Number(value);
  if (Number.isNaN(num)) {
    return 0;
  }
  return num;
}

export function asBoolean(value: Object | undefined): boolean {
  if (value === undefined || value === null) {
    return false;
  }
  return value === true || value === 1 || value === 'true' || value === '1';
}
