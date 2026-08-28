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

/**
 * Clean-room Xiaomi Home integration constants.
 *
 * Values that are directly observable in the public ha_xiaomi_home source are
 * sourced from that repository. Values that are not verified for a standalone
 * HarmonyOS app are marked UNVERIFIED.
 */

export const OAUTH2_CLIENT_ID: string = '2882303761520251711';
export const OAUTH2_AUTH_URL: string = 'https://account.xiaomi.com/oauth2/authorize';
export const DEFAULT_OAUTH2_API_HOST: string = 'ha.api.io.mi.com';
export const DEFAULT_CLOUD_SERVER: string = 'cn';

/**
 * Registered in the upstream Home Assistant integration and accepted by the
 * Xiaomi authorize page for client_id 2882303761520251711. The app only uses
 * it to pass the authorize page validation; the actual mijia cloud login
 * relies on the web session cookie (userId + passToken) captured in the
 * in-app browser, not on this redirect being reachable.
 */
export const SOURCE_OAUTH_REDIRECT_URL: string = 'http://homeassistant.local:8123';

export const APP_OAUTH_REDIRECT_URI: string = SOURCE_OAUTH_REDIRECT_URL;

export const TOKEN_EXPIRES_TS_RATIO: number = 0.7;
export const DEFAULT_HTTP_TIMEOUT_MS: number = 30000;
export const ASSET_ALIAS_AUTH_INFO: string = 'xiaomi_home_auth_info_v1';

export enum XiaomiRegion {
  CN = 'cn',
  DE = 'de',
  I2 = 'i2',
  RU = 'ru',
  SG = 'sg',
  US = 'us'
}

export function normalizeRegion(region: string): string {
  const value = region.trim().toLowerCase();
  if (value === 'cn' || value === 'de' || value === 'i2' || value === 'ru' ||
    value === 'sg' || value === 'us') {
    return value;
  }
  return DEFAULT_CLOUD_SERVER;
}

export function getXiaomiApiHost(region: string): string {
  const normalized = normalizeRegion(region);
  if (normalized === XiaomiRegion.CN) {
    return DEFAULT_OAUTH2_API_HOST;
  }
  return `${normalized}.${DEFAULT_OAUTH2_API_HOST}`;
}

export interface OAuthClientConfig {
  clientId: string;
  redirectUri: string;
  region: string;
  uuid: string;
  authUrl: string;
}

export function defaultOAuthClientConfig(region: string, uuid: string): OAuthClientConfig {
  return {
    clientId: OAUTH2_CLIENT_ID,
    redirectUri: APP_OAUTH_REDIRECT_URI,
    region: normalizeRegion(region),
    uuid: uuid,
    authUrl: OAUTH2_AUTH_URL
  };
}
