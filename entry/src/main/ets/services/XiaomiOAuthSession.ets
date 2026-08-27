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

import { common, Want } from '@kit.AbilityKit';
import { url } from '@kit.ArkTS';
import { XiaomiAuthInfo } from '../models/XiaomiAuthInfo';
import { XiaomiError, XiaomiAuthError, XiaomiErrorCode } from '../models/XiaomiErrors';
import { createOAuthClient, XiaomiOAuthClient } from '../oauth/XiaomiOAuthClient';
import { XiaomiCloudAuthProvider } from '../oauth/XiaomiCloudAuthProvider';
import { randomUuid } from '../utils/CryptoUtils';
import { Logger } from '../utils/Logger';

export interface XiaomiOAuthLoginResult {
  success: boolean;
  authInfo?: XiaomiAuthInfo;
  error?: XiaomiError;
}

export type XiaomiOAuthLoginListener = (result: XiaomiOAuthLoginResult) => void;

export class XiaomiOAuthSession {
  private oauthClient: XiaomiOAuthClient | null = null;
  private provider: XiaomiCloudAuthProvider | null = null;
  private expectedState: string = '';
  private listener: XiaomiOAuthLoginListener | null = null;
  private started: boolean = false;

  async start(
    context: common.UIAbilityContext,
    region: string,
    redirectUri?: string
  ): Promise<void> {
    if (this.started) {
      throw new XiaomiAuthError(XiaomiErrorCode.AUTH_INVALID_PARAMETER, 'oauth already started');
    }
    const uuid = randomUuid('harmony');
    this.oauthClient = createOAuthClient(region, uuid, redirectUri);
    this.provider = new XiaomiCloudAuthProvider(this.oauthClient);
    this.expectedState = this.oauthClient.getState();
    this.started = true;

    const authorizationUrl = this.oauthClient.buildAuthorizationUrl();
    const want: Want = {
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: authorizationUrl
    };
    Logger.info('opening xiaomi oauth authorization url');
    await context.startAbility(want);
  }

  setListener(listener: XiaomiOAuthLoginListener | null): void {
    this.listener = listener;
  }

  async handleCallback(want: Want): Promise<boolean> {
    if (!this.started || this.oauthClient === null || this.provider === null) {
      return false;
    }
    const uri = want.uri;
    if (uri === undefined || uri === null || uri.length === 0) {
      return false;
    }
    try {
      const parsed = new url.URL(uri);
      const code = parsed.searchParams.get('code');
      const state = parsed.searchParams.get('state');
      if (code === null || state === null) {
        this.fail(new XiaomiAuthError(XiaomiErrorCode.AUTH_INVALID_PARAMETER, 'missing code or state'));
        return true;
      }
      if (state !== this.expectedState) {
        this.fail(new XiaomiAuthError(XiaomiErrorCode.AUTH_INVALID_STATE, 'state mismatch'));
        return true;
      }
      const authInfo = await this.provider.login(code);
      this.notify({
        success: true,
        authInfo: authInfo
      });
      this.reset();
      return true;
    } catch (err) {
      const error = err instanceof XiaomiError
        ? err
        : new XiaomiAuthError(XiaomiErrorCode.AUTH_TOKEN_EXCHANGE_FAILED, String(err));
      this.fail(error);
      return true;
    }
  }

  reset(): void {
    this.oauthClient = null;
    this.provider = null;
    this.expectedState = '';
    this.listener = null;
    this.started = false;
  }

  private notify(result: XiaomiOAuthLoginResult): void {
    if (this.listener !== null) {
      this.listener(result);
    }
  }

  private fail(error: XiaomiError): void {
    this.notify({
      success: false,
      error: error
    });
    this.reset();
  }
}

export const xiaomiOAuthSession = new XiaomiOAuthSession();
