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

export enum XiaomiErrorCode {
  AUTH_INVALID_PARAMETER = 'AUTH_INVALID_PARAMETER',
  AUTH_INVALID_STATE = 'AUTH_INVALID_STATE',
  AUTH_TOKEN_EXCHANGE_FAILED = 'AUTH_TOKEN_EXCHANGE_FAILED',
  AUTH_TOKEN_EXPIRED = 'AUTH_TOKEN_EXPIRED',
  NETWORK_ERROR = 'NETWORK_ERROR',
  CLOUD_ERROR = 'CLOUD_ERROR',
  DEVICE_OFFLINE = 'DEVICE_OFFLINE',
  MIOT_PARSE_ERROR = 'MIOT_PARSE_ERROR',
  LAN_CONNECTION_ERROR = 'LAN_CONNECTION_ERROR',
  STORAGE_ERROR = 'STORAGE_ERROR'
}

export class XiaomiError extends Error {
  readonly code: XiaomiErrorCode;
  readonly status: number;

  constructor(code: XiaomiErrorCode, message: string, status: number = 0) {
    super(message);
    this.name = 'XiaomiError';
    this.code = code;
    this.status = status;
  }
}

export class XiaomiAuthError extends XiaomiError {
  constructor(code: XiaomiErrorCode, message: string, status: number = 0) {
    super(code, message, status);
    this.name = 'XiaomiAuthError';
  }
}

export class XiaomiTokenExpiredError extends XiaomiAuthError {
  constructor(message: string = 'token expired') {
    super(XiaomiErrorCode.AUTH_TOKEN_EXPIRED, message, 401);
    this.name = 'XiaomiTokenExpiredError';
  }
}

export class XiaomiNetworkError extends XiaomiError {
  constructor(message: string = 'network error', status: number = 0) {
    super(XiaomiErrorCode.NETWORK_ERROR, message, status);
    this.name = 'XiaomiNetworkError';
  }
}

export class XiaomiCloudError extends XiaomiError {
  constructor(message: string = 'cloud error', status: number = 0) {
    super(XiaomiErrorCode.CLOUD_ERROR, message, status);
    this.name = 'XiaomiCloudError';
  }
}

export class XiaomiDeviceOfflineError extends XiaomiError {
  constructor(message: string = 'device offline') {
    super(XiaomiErrorCode.DEVICE_OFFLINE, message);
    this.name = 'XiaomiDeviceOfflineError';
  }
}

export class MIoTParseError extends XiaomiError {
  constructor(message: string = 'miot spec parse error') {
    super(XiaomiErrorCode.MIOT_PARSE_ERROR, message);
    this.name = 'MIoTParseError';
  }
}

export class LanConnectionError extends XiaomiError {
  constructor(message: string = 'lan connection error') {
    super(XiaomiErrorCode.LAN_CONNECTION_ERROR, message);
    this.name = 'LanConnectionError';
  }
}

export class XiaomiStorageError extends XiaomiError {
  constructor(message: string = 'secure storage error') {
    super(XiaomiErrorCode.STORAGE_ERROR, message);
    this.name = 'XiaomiStorageError';
  }
}
