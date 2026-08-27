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

import { bundleManager, common } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { AppSettingsStore } from '../storage/AppSettingsStore';

const ENABLED_KEY = 'fullLogEnabled';
const START_TIME_KEY = 'fullLogStartTime';
const LOG_DIR_NAME = 'feedback';
const SESSION_FILE_NAME = 'full_log_current.txt';
const MAX_BUFFER_LINES = 5000;

/**
 * 完整日志模式服务。
 *
 * 开启后持续收集应用内所有操作日志（内存环形缓冲 + 会话文件双写），
 * 直到用户在反馈页面点击"生成日志文件"，此时产出带文件头/尾的日志文件。
 * 开关状态通过 AppSettingsStore 持久化，应用重启后若仍开启则继续收集。
 */
export class FeedbackLogService {
  private static context: common.UIAbilityContext | null = null;
  private static enabled: boolean = false;
  private static startTime: number = 0;
  private static buffer: string[] = [];
  private static recordCount: number = 0;
  private static sessionFile: fs.File | null = null;
  private static currentPage: string = '';

  /** 在 EntryAbility.onCreate 中调用，必须在 AppSettingsStore.init 之后。 */
  static init(context: common.UIAbilityContext): void {
    if (FeedbackLogService.context !== null) {
      return;
    }
    FeedbackLogService.context = context;
    FeedbackLogService.enabled = AppSettingsStore.getBoolean(ENABLED_KEY, false);
    FeedbackLogService.startTime = AppSettingsStore.getNumber(START_TIME_KEY, 0);
    if (FeedbackLogService.enabled) {
      FeedbackLogService.openSessionFile();
    }
  }

  static isEnabled(): boolean {
    return FeedbackLogService.enabled;
  }

  static getRecordCount(): number {
    return FeedbackLogService.recordCount;
  }

  static getStartTime(): number {
    return FeedbackLogService.startTime;
  }

  /** 记录当前所在页面；页面 aboutToAppear 时调用。 */
  static setCurrentPage(pageName: string): void {
    if (FeedbackLogService.currentPage === pageName) {
      return;
    }
    FeedbackLogService.currentPage = pageName;
    FeedbackLogService.recordOperation('PAGE', `当前页面: ${pageName}`);
  }

  static getCurrentPage(): string {
    return FeedbackLogService.currentPage;
  }

  /** 开启完整日志模式：重置会话并开始收集。 */
  static enable(): void {
    if (FeedbackLogService.context === null || FeedbackLogService.enabled) {
      return;
    }
    FeedbackLogService.enabled = true;
    FeedbackLogService.startTime = Date.now();
    FeedbackLogService.recordCount = 0;
    FeedbackLogService.buffer = [];
    AppSettingsStore.setBoolean(ENABLED_KEY, true);
    AppSettingsStore.setNumber(START_TIME_KEY, FeedbackLogService.startTime);
    FeedbackLogService.openSessionFile();
    FeedbackLogService.record('SYSTEM', '完整日志模式已开启');
  }

  /** 关闭完整日志模式：写入结束标记并释放会话文件。 */
  static disable(): void {
    if (!FeedbackLogService.enabled) {
      return;
    }
    FeedbackLogService.record('SYSTEM', '完整日志模式已关闭');
    FeedbackLogService.enabled = false;
    AppSettingsStore.setBoolean(ENABLED_KEY, false);
    FeedbackLogService.closeSessionFile();
    FeedbackLogService.buffer = [];
  }

  /** 记录一条操作日志（仅完整日志模式开启时生效）。 */
  static record(tag: string, message: string): void {
    if (!FeedbackLogService.enabled) {
      return;
    }
    FeedbackLogService.appendLine(FeedbackLogService.formatLine('INFO', tag, message));
  }

  /** 记录一条操作日志（与 record 等价，便于调用处语义化）。 */
  static recordOperation(tag: string, message: string): void {
    FeedbackLogService.record(tag, message);
  }

  /** 记录一条错误日志（仅完整日志模式开启时生效）。 */
  static recordError(tag: string, message: string): void {
    if (!FeedbackLogService.enabled) {
      return;
    }
    FeedbackLogService.appendLine(FeedbackLogService.formatLine('ERROR', tag, message));
  }

  /**
   * 生成日志内容（文件头 + 全部收集记录 + 文件尾）。
   * 不会关闭日志模式，也不删除会话文件；保存成功后由 saveLogFileWithPicker 调用 disable + removeSessionFile 收尾。
   */
  static buildLogContent(): string {
    if (FeedbackLogService.context === null) {
      return '';
    }
    try {
      const now = new Date();
      const dir = FeedbackLogService.logDir();
      const sessionPath = `${dir}/${SESSION_FILE_NAME}`;
      FeedbackLogService.record('SYSTEM', '用户点击生成日志文件');
      let sessionContent = '';
      if (fs.accessSync(sessionPath)) {
        sessionContent = fs.readTextSync(sessionPath);
      } else {
        sessionContent = FeedbackLogService.buffer.join('\n');
      }
      const count = FeedbackLogService.recordCount;
      const header = FeedbackLogService.buildHeader(now);
      const footer = `\n--- 日志结束，共 ${count} 条 ---\n`;
      let content = header;
      if (sessionContent.length > 0) {
        content += sessionContent;
      }
      content += footer;
      return content;
    } catch (err) {
      return '';
    }
  }

  /**
   * 通过系统保存选择器让用户选择日志文件的保存位置。
   * 保存成功后关闭完整日志模式并清理会话文件，返回用户选择的 URI；
   * 用户取消或保存失败时返回空字符串，日志模式保持开启。
   */
  static async saveLogFileWithPicker(): Promise<string> {
    const context = FeedbackLogService.context;
    if (context === null) {
      return '';
    }
    try {
      const content = FeedbackLogService.buildLogContent();
      if (content.length === 0) {
        return '';
      }
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = [`feedback_${FeedbackLogService.stamp(new Date())}.log`];
      options.fileSuffixChoices = ['.log'];
      const savePicker = new picker.DocumentViewPicker(context);
      const uris = await savePicker.save(options);
      if (uris.length === 0) {
        return '';
      }
      const uri = uris[0];
      const written = await FeedbackLogService.writeContentToUri(uri, content);
      if (!written) {
        return '';
      }
      FeedbackLogService.disable();
      FeedbackLogService.removeSessionFile();
      return uri;
    } catch (err) {
      return '';
    }
  }

  private static async writeContentToUri(uri: string, content: string): Promise<boolean> {
    try {
      const file = await fs.open(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      try {
        await fs.write(file.fd, content);
      } finally {
        await fs.close(file);
      }
      return true;
    } catch (err) {
      return false;
    }
  }

  private static removeSessionFile(): void {
    if (FeedbackLogService.context === null) {
      return;
    }
    try {
      const sessionPath = `${FeedbackLogService.logDir()}/${SESSION_FILE_NAME}`;
      if (fs.accessSync(sessionPath)) {
        fs.unlinkSync(sessionPath);
      }
    } catch (err) {
    }
  }

  /** 对可能包含敏感信息的文本做脱敏处理。 */
  static redactText(text: string): string {
    return text
      .replace(/access_token=[^&\s]+/gi, 'access_token=***')
      .replace(/refresh_token=[^&\s]+/gi, 'refresh_token=***')
      .replace(/token=[^&\s]+/gi, 'token=***')
      .replace(/ssecurity=[^&\s]+/gi, 'ssecurity=***')
      .replace(/signature=[^&\s]+/gi, 'signature=***')
      .replace(/rc4_hash__=[^&\s]+/gi, 'rc4_hash__=***')
      .replace(/_nonce=[^&\s]+/gi, '_nonce=***')
      .replace(/"access_token"\s*:\s*"[^"]*"/gi, '"access_token":"***"')
      .replace(/"refresh_token"\s*:\s*"[^"]*"/gi, '"refresh_token":"***"')
      .replace(/"token"\s*:\s*"[^"]*"/gi, '"token":"***"')
      .replace(/"ssecurity"\s*:\s*"[^"]*"/gi, '"ssecurity":"***"')
      .replace(/(serviceToken|passToken|yetAnotherServiceToken|cUserId)=[^&;\s]+/gi, '$1=***')
      .replace(/"(serviceToken|passToken|yetAnotherServiceToken|cUserId)"\s*:\s*"[^"]*"/gi, '"$1":"***"')
      .replace(/"signature"\s*:\s*"[^"]*"/gi, '"signature":"***"')
      .replace(/"rc4_hash__"\s*:\s*"[^"]*"/gi, '"rc4_hash__":"***"')
      .replace(/"_nonce"\s*:\s*"[^"]*"/gi, '"_nonce":"***"')
      .replace(/(authorization:?\s*bearer)\s*\S+/gi, '$1 ***')
      .replace(/"authorization"\s*:\s*"[^"]*"/gi, '"authorization":"***"')
      .replace(/(password|passwd|pwd)=[^&\s]+/gi, '$1=***')
      .replace(/"password"\s*:\s*"[^"]*"/gi, '"password":"***"')
      .replace(/"passwd"\s*:\s*"[^"]*"/gi, '"passwd":"***"')
      .replace(/cookie=[^&\s]+/gi, 'cookie=***')
      .replace(/"cookie"\s*:\s*"[^"]*"/gi, '"cookie":"***"');
  }

  private static appendLine(line: string): void {
    FeedbackLogService.recordCount++;
    FeedbackLogService.buffer.push(line);
    if (FeedbackLogService.buffer.length > MAX_BUFFER_LINES) {
      FeedbackLogService.buffer.shift();
    }
    const file = FeedbackLogService.sessionFile;
    if (file !== null) {
      try {
        fs.writeSync(file.fd, `${line}\n`);
      } catch (err) {
      }
    }
  }

  private static formatLine(level: string, tag: string, message: string): string {
    const safeMessage = FeedbackLogService.redactText(message);
    return `[${FeedbackLogService.formatTime(Date.now())}] [${level}] [${tag}] ${safeMessage}`;
  }

  private static logDir(): string {
    const context = FeedbackLogService.context;
    if (context === null) {
      throw new Error('feedback log service not initialized');
    }
    const dir = `${context.filesDir}/${LOG_DIR_NAME}`;
    try {
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir);
      }
    } catch (err) {
    }
    return dir;
  }

  private static openSessionFile(): void {
    try {
      const dir = FeedbackLogService.logDir();
      const path = `${dir}/${SESSION_FILE_NAME}`;
      const file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.APPEND);
      FeedbackLogService.sessionFile = file;
    } catch (err) {
      FeedbackLogService.sessionFile = null;
    }
  }

  private static closeSessionFile(): void {
    const file = FeedbackLogService.sessionFile;
    if (file !== null) {
      try {
        fs.closeSync(file);
      } catch (err) {
      }
      FeedbackLogService.sessionFile = null;
    }
  }

  private static buildHeader(generatedAt: Date): string {
    let versionName = 'unknown';
    let versionCode = 0;
    try {
      const bundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      );
      versionName = bundleInfo.versionName;
      versionCode = bundleInfo.versionCode;
    } catch (err) {
    }
    const lines: string[] = [];
    lines.push('================ 鸿米家完整日志 ================');
    lines.push(`版本: ${versionName} (${versionCode})`);
    lines.push(`设备: ${deviceInfo.manufacture} ${deviceInfo.marketName} ${deviceInfo.hardwareModel}`);
    lines.push(`系统: ${deviceInfo.osFullName}`);
    lines.push(`设备类型: ${deviceInfo.deviceType}`);
    lines.push(`日志模式开启时间: ${FeedbackLogService.startTime > 0 ? FeedbackLogService.formatTime(FeedbackLogService.startTime) : 'unknown'}`);
    lines.push(`日志文件生成时间: ${FeedbackLogService.formatTime(generatedAt.getTime())}`);
    lines.push(`当前页面: ${FeedbackLogService.currentPage.length > 0 ? FeedbackLogService.currentPage : 'unknown'}`);
    lines.push(`日志条数: ${FeedbackLogService.recordCount}`);
    lines.push('------------------------------------------------');
    return `${lines.join('\n')}\n`;
  }

  private static formatTime(ms: number): string {
    const d = new Date(ms);
    return `${d.getFullYear()}-${FeedbackLogService.pad2(d.getMonth() + 1)}-${FeedbackLogService.pad2(d.getDate())} ` +
      `${FeedbackLogService.pad2(d.getHours())}:${FeedbackLogService.pad2(d.getMinutes())}:${FeedbackLogService.pad2(d.getSeconds())}.${FeedbackLogService.pad3(d.getMilliseconds())}`;
  }

  private static stamp(d: Date): string {
    return `${d.getFullYear()}${FeedbackLogService.pad2(d.getMonth() + 1)}${FeedbackLogService.pad2(d.getDate())}` +
      `_${FeedbackLogService.pad2(d.getHours())}${FeedbackLogService.pad2(d.getMinutes())}${FeedbackLogService.pad2(d.getSeconds())}`;
  }

  private static pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  private static pad3(value: number): string {
    if (value < 10) {
      return `00${value}`;
    }
    if (value < 100) {
      return `0${value}`;
    }
    return `${value}`;
  }
}
