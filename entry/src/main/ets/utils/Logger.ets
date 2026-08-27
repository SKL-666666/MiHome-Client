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

import { hilog } from '@kit.PerformanceAnalysisKit';
import { FeedbackLogService } from '../services/FeedbackLogService';

export enum LogLevel {
  DEBUG = 3,
  INFO = 4,
  WARN = 5,
  ERROR = 6
}

const DOMAIN: number = 0x4D47;
const TAG: string = 'XiaomiHomeHarmony';

export class Logger {
  private static redactMessage(message: string): string {
    return message
      .replace(/access_token=[^&\s]+/gi, 'access_token=***')
      .replace(/refresh_token=[^&\s]+/gi, 'refresh_token=***')
      .replace(/token=[^&\s]+/gi, 'token=***')
      .replace(/ssecurity=[^&\s]+/gi, 'ssecurity=***')
      .replace(/signature=[^&\s]+/gi, 'signature=***')
      .replace(/rc4_hash__=[^&\s]+/gi, 'rc4_hash__=***')
      .replace(/_nonce=[^&\s]+/gi, '_nonce=***')
      .replace(/(authorization:?\s*bearer)\s*\S+/gi, '$1 ***')
      .replace(/(password|passwd|pwd)=[^&\s]+/gi, '$1=***')
      .replace(/cookie=[^&\s]+/gi, 'cookie=***');
  }

  static debug(message: string, ...args: Object[]): void {
    Logger.write(LogLevel.DEBUG, message, args);
  }

  static info(message: string, ...args: Object[]): void {
    Logger.write(LogLevel.INFO, message, args);
  }

  static warn(message: string, ...args: Object[]): void {
    Logger.write(LogLevel.WARN, message, args);
  }

  static error(message: string, ...args: Object[]): void {
    Logger.write(LogLevel.ERROR, message, args);
  }

  private static write(level: LogLevel, message: string, args: Object[]): void {
    const safeMessage = Logger.redactMessage(message);
    if (args.length > 0) {
      const safeArgs = args.map((item: Object): Object => {
        if (item instanceof Uint8Array) {
          return '<Uint8Array>';
        }
        return item;
      });
      const rendered = `${safeMessage} ${JSON.stringify(safeArgs)}`;
      hilog.info(DOMAIN, TAG, '%{public}s', rendered);
      FeedbackLogService.record(Logger.levelName(level), rendered);
    } else {
      hilog.info(DOMAIN, TAG, '%{public}s', safeMessage);
      FeedbackLogService.record(Logger.levelName(level), safeMessage);
    }
  }

  private static levelName(level: LogLevel): string {
    if (level === LogLevel.DEBUG) {
      return 'DEBUG';
    }
    if (level === LogLevel.WARN) {
      return 'WARN';
    }
    if (level === LogLevel.ERROR) {
      return 'ERROR';
    }
    return 'INFO';
  }
}
