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

import { XiaomiAuthInfo } from '../models/XiaomiAuthInfo';
import {
  XiaomiAuthError,
  XiaomiErrorCode,
  XiaomiTokenExpiredError
} from '../models/XiaomiErrors';
import { XiaomiOAuthClient } from './XiaomiOAuthClient';
import { SecureAuthStorage } from '../storage/SecureAuthStorage';

export class XiaomiCloudAuthProvider {
  private readonly oauthClient: XiaomiOAuthClient;
  private cachedAuthInfo: XiaomiAuthInfo | null = null;

  constructor(oauthClient: XiaomiOAuthClient) {
    this.oauthClient = oauthClient;
  }

  getOAuthClient(): XiaomiOAuthClient {
    return this.oauthClient;
  }

  async login(code: string): Promise<XiaomiAuthInfo> {
    const authInfo = await this.oauthClient.exchangeCode(code);
    await SecureAuthStorage.save(authInfo);
    this.cachedAuthInfo = authInfo;
    return authInfo;
  }

  async refresh(): Promise<XiaomiAuthInfo> {
    const current = await this.loadStoredAuthInfo();
    if (current.refreshToken.trim().length === 0) {
      throw new XiaomiAuthError(XiaomiErrorCode.AUTH_TOKEN_EXPIRED, 'refresh token missing');
    }
    const authInfo = await this.oauthClient.refreshAccessToken(current.refreshToken);
    await SecureAuthStorage.save(authInfo);
    this.cachedAuthInfo = authInfo;
    return authInfo;
  }

  async logout(): Promise<void> {
    this.cachedAuthInfo = null;
    await SecureAuthStorage.clear();
  }

  async getAccessToken(): Promise<string> {
    const current = await this.loadStoredAuthInfo();
    if (this.isTokenExpired(current)) {
      const refreshed = await this.refresh();
      return refreshed.accessToken;
    }
    return current.accessToken;
  }

  async isAuthenticated(): Promise<boolean> {
    const authInfo = await this.loadStoredAuthInfo();
    return authInfo.accessToken.trim().length > 0;
  }

  isTokenExpired(authInfo: XiaomiAuthInfo): boolean {
    return Date.now() >= authInfo.expiresTs;
  }

  private async loadStoredAuthInfo(): Promise<XiaomiAuthInfo> {
    if (this.cachedAuthInfo !== null) {
      return this.cachedAuthInfo;
    }
    const stored = await SecureAuthStorage.load();
    if (stored === null) {
      throw new XiaomiTokenExpiredError('auth info not found');
    }
    this.cachedAuthInfo = stored;
    return stored;
  }
}
