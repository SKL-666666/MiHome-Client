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

import { url } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { MijiaAuthData } from '../cloud/MijiaApiClient';
import { XiaomiCloudError, XiaomiAuthError, XiaomiErrorCode } from '../models/XiaomiErrors';
import { XiaomiHttpClient, XiaomiHttpResponse } from '../network/XiaomiHttpClient';

export interface MijiaQrLoginTicket {
  loginUrl: string;
  qr: string;
  lp: string;
}

interface LoginJson {
  code?: number;
  location?: string;
  loginUrl?: string;
  qr?: string;
  lp?: string;
  ssecurity?: string;
  psecurity?: string;
  nonce?: string;
  passToken?: string;
  userId?: string;
  cUserId?: string;
}

export class MijiaQrLoginService {
  private readonly locale: string = 'zh_CN';
  private readonly deviceId: string = randomHex(16);
  private readonly passO: string = randomHex(16);
  private readonly userAgent: string = this.buildUserAgent();
  private cookies: string = '';

  async buildLoginTicket(): Promise<MijiaQrLoginTicket> {
    const locationData = await this.getServiceLoginLocation();
    const loginUrl = new url.URL('https://account.xiaomi.com/longPolling/loginUrl');
    const query = loginUrl.searchParams;
    query.set('theme', '');
    query.set('bizDeviceType', '');
    query.set('_hasLogo', 'false');
    query.set('_qrsize', '240');
    query.set('_dc', Date.now().toString());
    const keys = Object.keys(locationData);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const value = locationData[key];
      if (typeof value === 'string') {
        query.set(key, value);
      }
    }
    const response = await XiaomiHttpClient.get(loginUrl.toString(), {
      headers: this.loginHeaders()
    });
    this.updateCookies(response);
    const data = parseLoginJson(response.body);
    if (data.loginUrl === undefined || data.qr === undefined || data.lp === undefined) {
      throw new XiaomiAuthError(XiaomiErrorCode.AUTH_TOKEN_EXCHANGE_FAILED, 'invalid qr login response');
    }
    return {
      loginUrl: data.loginUrl,
      qr: data.qr,
      lp: data.lp
    };
  }

  async pollTicket(ticket: MijiaQrLoginTicket): Promise<MijiaAuthData> {
    const response = await XiaomiHttpClient.get(ticket.lp, {
      headers: this.loginHeaders(),
      timeoutMs: 120000
    });
    this.updateCookies(response);
    const data = parseLoginJson(response.body);
    if (data.psecurity === undefined || data.ssecurity === undefined ||
      data.passToken === undefined || data.userId === undefined ||
      data.cUserId === undefined) {
      throw new XiaomiAuthError(XiaomiErrorCode.AUTH_TOKEN_EXCHANGE_FAILED, 'invalid qr poll response');
    }
    if (data.location !== undefined && data.location.length > 0) {
      const callback = await XiaomiHttpClient.get(data.location, {
        headers: this.loginHeaders()
      });
      this.updateCookies(callback);
    }
    const serviceToken = this.extractServiceToken(this.cookies);
    return {
      userId: data.userId,
      cUserId: data.cUserId,
      passToken: data.passToken,
      ssecurity: data.ssecurity,
      serviceToken: serviceToken,
      deviceId: this.deviceId,
      passO: this.passO,
      userAgent: this.userAgent,
      locale: this.locale
    };
  }

  private async getServiceLoginLocation(): Promise<Record<string, Object>> {
    const serviceUrl = `https://account.xiaomi.com/pass/serviceLogin?_json=true&sid=mijia&_locale=${this.locale}`;
    const response = await XiaomiHttpClient.get(serviceUrl, {
      headers: this.loginHeaders()
    });
    this.updateCookies(response);
    const text = response.body.replace('&&&START&&&', '');
    const data = parseLoginJson(text);
    if (data.location === undefined) {
      throw new XiaomiAuthError(XiaomiErrorCode.AUTH_TOKEN_EXCHANGE_FAILED, 'missing service login location');
    }
    const parsed = new url.URL(data.location);
    const result: Record<string, Object> = {};
    const keys = Array.from(parsed.searchParams.keys());
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      result[key] = parsed.searchParams.get(key) ?? '';
    }
    return result;
  }

  private loginHeaders(): Record<string, string> {
    const baseCookie = `deviceId=${this.deviceId};pass_o=${this.passO};uLocale=${this.locale}`;
    const cookie = this.cookies.length > 0
      ? `${baseCookie};${this.cookies}`
      : baseCookie;
    const headers: Record<string, string> = {
      'User-Agent': this.userAgent,
      'Accept-Encoding': 'identity',
      'Content-Type': 'application/x-www-form-urlencoded',
      'Connection': 'keep-alive'
    };
    headers['Cookie'] = cookie;
    return headers;
  }

  private updateCookies(response: XiaomiHttpResponse): void {
    const rawSetCookie = response.headers['set-cookie'] ?? response.headers['Set-Cookie'] ?? '';
    if (rawSetCookie.length === 0) {
      return;
    }
    const parts = rawSetCookie.split(/,(?=\s*[^=;]+=)/);
    for (let i = 0; i < parts.length; i++) {
      const pair = parts[i].split(';')[0].trim();
      if (pair.length === 0) {
        continue;
      }
      this.cookies = mergeCookie(this.cookies, pair);
    }
  }

  private extractServiceToken(cookies: string): string {
    const parts = cookies.split(';');
    for (let i = 0; i < parts.length; i++) {
      const pair = parts[i].trim();
      if (pair.startsWith('serviceToken=')) {
        return pair.substring('serviceToken='.length);
      }
    }
    return '';
  }

  private buildUserAgent(): string {
    return `Android-15-11.0.701-Xiaomi-23046RP50C-OS2.0.212.0.VMYCNXM-${randomHex(40)}-CN-${randomHex(32)}-${randomHex(32)}-SmartHome-MI_APP_STORE-${randomHex(40)}|${randomHex(40)}|${this.passO}-64`;
  }
}

function parseLoginJson(body: string): LoginJson {
  try {
    return JSON.parse(body.replace('&&&START&&&', '')) as LoginJson;
  } catch (err) {
    const preview = body.trim().slice(0, 120);
    if (preview.toLowerCase().includes('invalid token')) {
      throw new XiaomiAuthError(
        XiaomiErrorCode.AUTH_TOKEN_EXCHANGE_FAILED,
        '服务端返回 Invalid Token，请重新生成二维码'
      );
    }
    throw new XiaomiAuthError(
      XiaomiErrorCode.AUTH_TOKEN_EXCHANGE_FAILED,
      `登录响应不是有效 JSON: ${preview}`
    );
  }
}

function randomHex(length: number): string {
  const byteLength = Math.ceil(length / 2);
  const bytes = cryptoFramework.createRandom().generateRandomSync(byteLength).data;
  let result = '';
  for (let i = 0; i < bytes.length; i++) {
    result += bytes[i].toString(16).padStart(2, '0');
  }
  return result.slice(0, length);
}

function mergeCookie(current: string, pair: string): string {
  const eq = pair.indexOf('=');
  if (eq <= 0) {
    return current;
  }
  const name = pair.substring(0, eq);
  const parts = current.split(';');
  const next: string[] = [];
  for (let i = 0; i < parts.length; i++) {
    const item = parts[i].trim();
    if (item.length > 0 && !item.startsWith(`${name}=`)) {
      next.push(item);
    }
  }
  next.push(pair);
  return next.join(';');
}
