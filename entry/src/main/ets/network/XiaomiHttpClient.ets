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

import { http } from '@kit.NetworkKit';
import { XiaomiCloudError, XiaomiNetworkError } from '../models/XiaomiErrors';
import { FeedbackLogService } from '../services/FeedbackLogService';

export interface XiaomiHttpResponse {
  status: number;
  body: string;
  headers: Record<string, string>;
}

export interface XiaomiHttpRequestOptions {
  headers?: Record<string, string>;
  timeoutMs?: number;
}

export class XiaomiHttpClient {
  static async get(
    url: string,
    options?: XiaomiHttpRequestOptions
  ): Promise<XiaomiHttpResponse> {
    return XiaomiHttpClient.request(url, 'GET', undefined, options);
  }

  static async postJson(
    url: string,
    body: Object | undefined,
    options?: XiaomiHttpRequestOptions
  ): Promise<XiaomiHttpResponse> {
    return XiaomiHttpClient.request(url, 'POST', body, options);
  }

  static async postForm(
    url: string,
    form: string,
    options?: XiaomiHttpRequestOptions
  ): Promise<XiaomiHttpResponse> {
    return XiaomiHttpClient.request(url, 'POST', undefined, options, form);
  }

  static async request(
    url: string,
    method: string,
    body: Object | undefined,
    options?: XiaomiHttpRequestOptions,
    form?: string
  ): Promise<XiaomiHttpResponse> {
    const request = http.createHttp();
    const safeUrl = FeedbackLogService.redactText(url);
    let requestBodyText = '';
    if (form !== undefined) {
      requestBodyText = form;
    } else if (body !== undefined) {
      requestBodyText = JSON.stringify(body);
    }
    FeedbackLogService.recordOperation('HTTP',
      `请求开始 ${method} ${safeUrl}${requestBodyText.length > 0 ? ` body=${requestBodyText}` : ''}`);
    try {
      const requestOptions: http.HttpRequestOptions = {
        method: method === 'POST' ? http.RequestMethod.POST : http.RequestMethod.GET,
        connectTimeout: options?.timeoutMs ?? 30000,
        readTimeout: options?.timeoutMs ?? 30000,
        expectDataType: http.HttpDataType.STRING,
        usingCache: false
      };
      if (options?.headers !== undefined) {
        requestOptions.header = options.headers;
      }
      if (form !== undefined) {
        requestOptions.extraData = form;
      } else if (body !== undefined) {
        requestOptions.extraData = JSON.stringify(body);
      }
      const response = await request.request(url, requestOptions);
      const result = typeof response.result === 'string'
        ? response.result as string
        : JSON.stringify(response.result);
      FeedbackLogService.recordOperation('HTTP',
        `请求完成 ${method} ${safeUrl} status=${Number(response.responseCode)} body=${FeedbackLogService.redactText(result)}`);
      const headers: Record<string, string> = {};
      const rawHeader = response.header as Object;
      if (rawHeader !== undefined && rawHeader !== null) {
        const entries = Object.entries(rawHeader as Record<string, Object>);
        for (let i = 0; i < entries.length; i++) {
          const key = entries[i][0];
          const value = entries[i][1];
          headers[key] = String(value);
        }
      }
      return {
        status: Number(response.responseCode),
        body: result,
        headers: headers
      };
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      FeedbackLogService.recordError('HTTP', `请求失败 ${method} ${safeUrl} error=${message}`);
      throw new XiaomiNetworkError(message);
    } finally {
      request.destroy();
    }
  }
}

export class XiaomiCloudResponseError extends XiaomiCloudError {
  constructor(message: string, status: number) {
    super(message, status);
  }
}

export function parseXiaomiJsonResponse(
  response: XiaomiHttpResponse
): Record<string, Object> {
  if (response.status !== 200) {
    throw new XiaomiCloudError(`http status ${response.status}`, response.status);
  }
  let parsed: Object;
  try {
    parsed = JSON.parse(response.body) as Object;
  } catch (err) {
    throw new XiaomiCloudError('invalid json response', response.status);
  }
  if (parsed === null || parsed === undefined) {
    throw new XiaomiCloudError('empty json response', response.status);
  }
  const obj = parsed as Record<string, Object>;
  const code = Number(obj['code'] ?? -1);
  if (code !== 0) {
    const message = String(obj['message'] ?? 'cloud error');
    throw new XiaomiCloudError(message, response.status);
  }
  return obj;
}
