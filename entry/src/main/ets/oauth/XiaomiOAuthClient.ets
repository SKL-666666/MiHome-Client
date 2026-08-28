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
  defaultOAuthClientConfig,
  getXiaomiApiHost,
  OAuthClientConfig
} from '../models/XiaomiConfig';
import {
  asNumber,
  asString,
  createAuthInfoFromTokenResult,
  XiaomiAuthInfo
} from '../models/XiaomiAuthInfo';
import { XiaomiAuthError, XiaomiErrorCode } from '../models/XiaomiErrors';
import { XiaomiHttpClient } from '../network/XiaomiHttpClient';
import { buildOauthState } from '../utils/CryptoUtils';

export class XiaomiOAuthClient {
  private readonly config: OAuthClientConfig;
  private readonly deviceId: string;
  private readonly state: string;

  constructor(config: OAuthClientConfig) {
    if (config.clientId.trim().length === 0 || config.redirectUri.trim().length === 0) {
      throw new XiaomiAuthError(XiaomiErrorCode.AUTH_INVALID_PARAMETER, 'invalid oauth config');
    }
    this.config = config;
    this.deviceId = `ha.${config.uuid}`;
    this.state = buildOauthState(config.uuid);
  }

  getState(): string {
    return this.state;
  }

  getDeviceId(): string {
    return this.deviceId;
  }

  getRedirectUri(): string {
    return this.config.redirectUri;
  }

  buildAuthorizationUrl(): string {
    const params: string[] = [
      `redirect_uri=${encodeURIComponent(this.config.redirectUri)}`,
      `client_id=${encodeURIComponent(this.config.clientId)}`,
      'response_type=code',
      `device_id=${encodeURIComponent(this.deviceId)}`,
      `state=${encodeURIComponent(this.state)}`,
      'skip_confirm=false'
    ];
    return `${this.config.authUrl}?${params.join('&')}`;
  }

  async exchangeCode(code: string): Promise<XiaomiAuthInfo> {
    if (code.trim().length === 0) {
      throw new XiaomiAuthError(XiaomiErrorCode.AUTH_INVALID_PARAMETER, 'empty authorization code');
    }
    const data: TokenRequestData = {
      client_id: this.config.clientId,
      redirect_uri: this.config.redirectUri,
      code: code,
      device_id: this.deviceId
    };
    return this.getToken(data);
  }

  async refreshAccessToken(refreshToken: string): Promise<XiaomiAuthInfo> {
    if (refreshToken.trim().length === 0) {
      throw new XiaomiAuthError(XiaomiErrorCode.AUTH_INVALID_PARAMETER, 'empty refresh token');
    }
    const data: TokenRequestData = {
      client_id: this.config.clientId,
      redirect_uri: this.config.redirectUri,
      refresh_token: refreshToken
    };
    return this.getToken(data);
  }

  private async getToken(data: TokenRequestData): Promise<XiaomiAuthInfo> {
    const host = getXiaomiApiHost(this.config.region);
    const url = `https://${host}/app/v2/ha/oauth/get_token?data=${encodeURIComponent(buildTokenDataJson(data))}`;
    const response = await XiaomiHttpClient.get(url, {
      headers: {
        'content-type': 'application/x-www-form-urlencoded'
      }
    });
    if (response.status === 401) {
      throw new XiaomiAuthError(XiaomiErrorCode.AUTH_TOKEN_EXCHANGE_FAILED, 'unauthorized', 401);
    }
    if (response.status !== 200) {
      throw new XiaomiAuthError(
        XiaomiErrorCode.AUTH_TOKEN_EXCHANGE_FAILED,
        `token endpoint status ${response.status}`,
        response.status
      );
    }
    let parsed: Record<string, Object>;
    try {
      parsed = JSON.parse(response.body) as Record<string, Object>;
    } catch (err) {
      throw new XiaomiAuthError(
        XiaomiErrorCode.AUTH_TOKEN_EXCHANGE_FAILED,
        'invalid token response'
      );
    }
    const rawCode = parsed['code'];
    const result = parsed['result'];
    if ((rawCode !== undefined && asNumber(rawCode) !== 0) || result === undefined || result === null) {
      const detail = asString(parsed['message'])
        || asString(parsed['error_description'])
        || response.body
        || 'token exchange failed';
      throw new XiaomiAuthError(
        XiaomiErrorCode.AUTH_TOKEN_EXCHANGE_FAILED,
        detail,
        response.status
      );
    }
    return createAuthInfoFromTokenResult(
      result as Record<string, Object>,
      this.config.region,
      this.config.redirectUri,
      this.config.clientId,
      Date.now()
    );
  }
}

interface TokenRequestData {
  client_id: string;
  redirect_uri: string;
  code?: string;
  device_id?: string;
  refresh_token?: string;
}

function buildTokenDataJson(data: TokenRequestData): string {
  const clientId = data.client_id.trim();
  const clientIdJson = /^\d+$/.test(clientId) ? clientId : JSON.stringify(clientId);
  const parts: string[] = [`"client_id":${clientIdJson}`];
  parts.push(`"redirect_uri":${JSON.stringify(data.redirect_uri)}`);
  if (data.code !== undefined) {
    parts.push(`"code":${JSON.stringify(data.code)}`);
  }
  if (data.device_id !== undefined) {
    parts.push(`"device_id":${JSON.stringify(data.device_id)}`);
  }
  if (data.refresh_token !== undefined) {
    parts.push(`"refresh_token":${JSON.stringify(data.refresh_token)}`);
  }
  return `{${parts.join(',')}}`;
}

export function createOAuthClient(region: string, uuid: string, redirectUri?: string): XiaomiOAuthClient {
  const config = defaultOAuthClientConfig(region, uuid);
  if (redirectUri !== undefined && redirectUri.trim().length > 0) {
    config.redirectUri = redirectUri.trim();
  }
  return new XiaomiOAuthClient(config);
}
