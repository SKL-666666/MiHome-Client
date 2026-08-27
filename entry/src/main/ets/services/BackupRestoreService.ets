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
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { deviceInfo, zlib } from '@kit.BasicServicesKit';
import { AppSettingsStore } from '../storage/AppSettingsStore';
import { JsonCache } from '../storage/JsonCache';
import { xiaomiDataService } from './XiaomiDataService';
import { FeedbackLogService } from './FeedbackLogService';

const BACKUP_APP_ID: string = 'miha_home';
const BACKUP_FORMAT_VERSION: number = 1;
const SNAPSHOT_CACHE_KEY: string = 'home_snapshot_v1';
const MAX_BACKUP_FILE_SIZE: number = 16 * 1024 * 1024;
const MAX_BACKUP_ARCHIVE_SIZE: number = 16 * 1024 * 1024;
const MAX_EXTRACTED_ASSET_SIZE: number = 32 * 1024 * 1024;
const MAX_EXTRACTED_FILE_COUNT: number = 256;
const BACKUP_JSON_NAME: string = 'backup.json';
const BACKGROUND_DIR_NAME: string = 'background';
const FONTS_DIR_NAME: string = 'fonts';

export interface BackupHomeItem {
  homeId: string;
  name: string;
}

export interface BackupDeviceItem {
  did: string;
  model: string;
  name: string;
}

export interface BackupDeviceInfo {
  homes: BackupHomeItem[];
  devices: BackupDeviceItem[];
}

export interface BackupFileContent {
  app: string;
  formatVersion: number;
  exportedAt: number;
  deviceInfo: BackupDeviceInfo;
  settings: Record<string, Object>;
}

/**
 * 恢复包：配置文件内容 + 从压缩包中解压出的资源目录信息。
 * 旧版纯 .json 备份 assetDir 为空。
 */
export interface BackupRestorePackage {
  content: BackupFileContent;
  assetDir: string;
  backgroundFile: string;
  fontFiles: string[];
}

/**
 * 设置备份与恢复：导出全部设置 + 设备信息（可选附带自定义背景与上传字体）到 ZIP 压缩包，
 * 或从压缩包/配置文件恢复设置并重启应用。
 */
export class BackupRestoreService {
  static async exportBackup(context: common.UIAbilityContext, includeAssets: boolean): Promise<string> {
    AppSettingsStore.init(context);
    const stamp = Date.now();
    const tmpDir = `${context.filesDir}/miha_export_tmp_${stamp}`;
    const zipPath = `${context.filesDir}/miha_backup_${stamp}.zip`;
    try {
      const settings = AppSettingsStore.getAll();
      const deviceInfoData = await BackupRestoreService.collectCurrentDeviceInfo(context);
      const content: BackupFileContent = {
        app: BACKUP_APP_ID,
        formatVersion: BACKUP_FORMAT_VERSION,
        exportedAt: Date.now(),
        deviceInfo: deviceInfoData,
        settings: settings
      };
      BackupRestoreService.removeDirQuietly(tmpDir);
      fs.mkdirSync(tmpDir);
      BackupRestoreService.writeTextFile(`${tmpDir}/${BACKUP_JSON_NAME}`, JSON.stringify(content));
      if (includeAssets) {
        BackupRestoreService.collectBackgroundAsset(context, tmpDir);
        BackupRestoreService.collectFontAssets(context, tmpDir);
      }
      const zipOptions: zlib.Options = { level: zlib.CompressLevel.COMPRESS_LEVEL_DEFAULT_COMPRESSION };
      await zlib.compressFile(tmpDir, zipPath, zipOptions);
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = [`miha_backup_${stamp}.zip`];
      options.fileSuffixChoices = ['.zip'];
      const savePicker = new picker.DocumentViewPicker(context);
      const uris = await savePicker.save(options);
      if (uris.length === 0) {
        return '';
      }
      const uri = uris[0];
      const written = await BackupRestoreService.copySandboxFileToUri(zipPath, uri);
      if (written) {
        FeedbackLogService.recordOperation('BACKUP',
          includeAssets ? '导出配置文件（含背景与字体）成功' : '导出配置文件（仅配置）成功');
      }
      return written ? uri : '';
    } catch (err) {
      FeedbackLogService.recordError('BACKUP', '导出配置文件失败');
      return '';
    } finally {
      BackupRestoreService.removeDirQuietly(tmpDir);
      BackupRestoreService.removeFileQuietly(zipPath);
    }
  }

  static async pickBackupFile(context: common.UIAbilityContext): Promise<BackupRestorePackage | null> {
    try {
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      options.fileSuffixFilters = ['ZIP|.zip', 'JSON|.json'];
      const selectPicker = new picker.DocumentViewPicker(context);
      const uris = await selectPicker.select(options);
      if (uris.length === 0) {
        return null;
      }
      return await BackupRestoreService.readPackage(context, uris[0]);
    } catch (err) {
      FeedbackLogService.recordError('BACKUP', '读取配置文件失败');
      return null;
    }
  }

  static applyRestore(context: common.UIAbilityContext, pkg: BackupRestorePackage): boolean {
    let success: boolean = false;
    try {
      const isLargeScreen = BackupRestoreService.isLargeScreenDevice();
      const finalAutoMultiColumn = BackupRestoreService.resolveAutoMultiColumn(pkg.content.settings, isLargeScreen);
      BackupRestoreService.applySettings(pkg.content.settings);
      if (pkg.assetDir.length > 0) {
        const backgroundAllowed = !BackupRestoreService.isLockedSetting('backgroundImage', finalAutoMultiColumn);
        BackupRestoreService.restoreBackground(context, pkg, backgroundAllowed);
        BackupRestoreService.restoreFonts(context, pkg);
      }
      success = true;
    } catch (err) {
      FeedbackLogService.recordError('BACKUP', '恢复配置文件失败');
      success = false;
    } finally {
      if (pkg.assetDir.length > 0) {
        BackupRestoreService.removeDirQuietly(pkg.assetDir);
      }
    }
    if (success) {
      BackupRestoreService.restartApp(context);
    }
    return success;
  }

  static async collectCurrentDeviceInfo(context: common.UIAbilityContext): Promise<BackupDeviceInfo> {
    const cached = BackupRestoreService.readDeviceInfoFromCache(context);
    if (cached !== null) {
      return cached;
    }
    try {
      const snapshot = await xiaomiDataService.getHomeSnapshot(context, true);
      return BackupRestoreService.buildDeviceInfo(snapshot.homesJson, snapshot.devicesJson);
    } catch (err) {
      return { homes: [], devices: [] };
    }
  }

  static deviceInfoMatches(backup: BackupDeviceInfo, current: BackupDeviceInfo): boolean {
    if (backup.homes.length !== current.homes.length || backup.devices.length !== current.devices.length) {
      return false;
    }
    const backupHomes = BackupRestoreService.sortHomes(backup.homes);
    const currentHomes = BackupRestoreService.sortHomes(current.homes);
    for (let i = 0; i < backupHomes.length; i++) {
      if (backupHomes[i].homeId !== currentHomes[i].homeId || backupHomes[i].name !== currentHomes[i].name) {
        return false;
      }
    }
    const backupDevices = BackupRestoreService.sortDevices(backup.devices);
    const currentDevices = BackupRestoreService.sortDevices(current.devices);
    for (let i = 0; i < backupDevices.length; i++) {
      if (backupDevices[i].did !== currentDevices[i].did || backupDevices[i].model !== currentDevices[i].model) {
        return false;
      }
    }
    return true;
  }

  static applySettings(settings: Record<string, Object>): void {
    const isLargeScreen = BackupRestoreService.isLargeScreenDevice();
    const finalAutoMultiColumn = BackupRestoreService.resolveAutoMultiColumn(settings, isLargeScreen);
    const keys = Object.keys(settings);
    let skippedCount: number = 0;
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      if (BackupRestoreService.shouldSkipSetting(key, isLargeScreen, finalAutoMultiColumn)) {
        skippedCount++;
        continue;
      }
      BackupRestoreService.writeSetting(key, settings[key]);
    }
    if (finalAutoMultiColumn) {
      AppSettingsStore.setBoolean('dualColumnMode', false);
      AppSettingsStore.delete('dualColumnRestore');
    }
    if (skippedCount > 0) {
      FeedbackLogService.recordOperation('BACKUP', `恢复配置文件完成，跳过 ${skippedCount} 项本设备不适用/被锁定的设置`);
    }
  }

  static restartApp(context: common.UIAbilityContext): void {
    try {
      const want: Want = {
        bundleName: context.abilityInfo.bundleName,
        abilityName: context.abilityInfo.name
      };
      context.getApplicationContext().restartApp(want);
      FeedbackLogService.recordOperation('BACKUP', '恢复后重启应用');
    } catch (err) {
      FeedbackLogService.recordError('BACKUP', '恢复后重启应用失败');
    }
  }

  private static async readPackage(
    context: common.UIAbilityContext,
    uri: string
  ): Promise<BackupRestorePackage | null> {
    const workDir = `${context.filesDir}/miha_restore_tmp_${Date.now()}`;
    try {
      fs.mkdirSync(workDir);
      const lower = uri.toLowerCase();
      if (lower.endsWith('.zip')) {
        try {
          const zipPath = `${workDir}/package.zip`;
          const copied = await BackupRestoreService.copyUriToSandboxFile(uri, zipPath);
          if (!copied) {
            throw new Error('copy package failed');
          }
          await zlib.decompressFile(zipPath, workDir);
          if (!BackupRestoreService.validateExtractedTree(workDir)) {
            throw new Error('invalid extracted backup tree');
          }
          const jsonPath = `${workDir}/${BACKUP_JSON_NAME}`;
          if (!fs.accessSync(jsonPath)) {
            throw new Error('package missing backup.json');
          }
          const content = BackupRestoreService.parseBackupContent(BackupRestoreService.readTextFileSync(jsonPath));
          if (content === null) {
            throw new Error('invalid package content');
          }
          const pkg: BackupRestorePackage = {
            content: content,
            assetDir: workDir,
            backgroundFile: BackupRestoreService.findBackgroundFile(workDir),
            fontFiles: BackupRestoreService.findFontFiles(workDir)
          };
          return pkg;
        } catch (err) {
          BackupRestoreService.removeDirQuietly(workDir);
          return null;
        }
      }
      const text = await BackupRestoreService.readTextFromUri(uri);
      if (text.length === 0) {
        BackupRestoreService.removeDirQuietly(workDir);
        return null;
      }
      const content = BackupRestoreService.parseBackupContent(text);
      if (content === null) {
        BackupRestoreService.removeDirQuietly(workDir);
        return null;
      }
      const pkg: BackupRestorePackage = { content: content, assetDir: '', backgroundFile: '', fontFiles: [] };
      BackupRestoreService.removeDirQuietly(workDir);
      return pkg;
    } catch (err) {
      BackupRestoreService.removeDirQuietly(workDir);
      return null;
    }
  }

  private static restoreBackground(
    context: common.UIAbilityContext,
    pkg: BackupRestorePackage,
    allowed: boolean
  ): void {
    try {
      if (!allowed || pkg.backgroundFile.length === 0) {
        return;
      }
      const src = `${pkg.assetDir}/${BACKGROUND_DIR_NAME}/${pkg.backgroundFile}`;
      if (!fs.accessSync(src)) {
        return;
      }
      const destPath = `${context.filesDir}/background_image_${Date.now()}`;
      fs.copyFileSync(src, destPath);
      const uri = `file://${destPath}`;
      AppSettingsStore.setString('backgroundImage', uri);
      AppStorage.setOrCreate('backgroundImage', uri);
      FeedbackLogService.recordOperation('BACKUP', '恢复自定义背景成功');
    } catch (err) {
      FeedbackLogService.recordError('BACKUP', '恢复自定义背景失败');
    }
  }

  private static restoreFonts(context: common.UIAbilityContext, pkg: BackupRestorePackage): void {
    try {
      if (pkg.fontFiles.length === 0) {
        return;
      }
      const dir = `${context.filesDir}/custom_fonts`;
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir);
      }
      const restored: string[] = [];
      for (let i = 0; i < pkg.fontFiles.length; i++) {
        const src = `${pkg.assetDir}/${FONTS_DIR_NAME}/${pkg.fontFiles[i]}`;
        if (!fs.accessSync(src)) {
          continue;
        }
        const dest = `${dir}/${pkg.fontFiles[i]}`;
        fs.copyFileSync(src, dest);
        restored.push(pkg.fontFiles[i]);
      }
      if (restored.length > 0) {
        AppSettingsStore.setStringArray('customFonts', restored);
        AppStorage.setOrCreate('customFonts', restored);
        FeedbackLogService.recordOperation('BACKUP', `恢复上传字体 ${restored.length} 个成功`);
      }
    } catch (err) {
      FeedbackLogService.recordError('BACKUP', '恢复上传字体失败');
    }
  }

  private static collectBackgroundAsset(context: common.UIAbilityContext, tmpDir: string): void {
    try {
      const uri = AppSettingsStore.getString('backgroundImage', '');
      if (uri.length === 0) {
        return;
      }
      const path = BackupRestoreService.uriToPath(uri);
      if (!fs.accessSync(path) || !fs.statSync(path).isFile()) {
        return;
      }
      const fileName = path.substring(path.lastIndexOf('/') + 1);
      if (fileName.length === 0) {
        return;
      }
      fs.mkdirSync(`${tmpDir}/${BACKGROUND_DIR_NAME}`);
      fs.copyFileSync(path, `${tmpDir}/${BACKGROUND_DIR_NAME}/${fileName}`);
    } catch (err) {
    }
  }

  private static collectFontAssets(context: common.UIAbilityContext, tmpDir: string): void {
    try {
      const names = AppSettingsStore.getStringArray('customFonts', []);
      if (names.length === 0) {
        return;
      }
      fs.mkdirSync(`${tmpDir}/${FONTS_DIR_NAME}`);
      for (let i = 0; i < names.length; i++) {
        const src = `${context.filesDir}/custom_fonts/${names[i]}`;
        if (fs.accessSync(src) && fs.statSync(src).isFile()) {
          fs.copyFileSync(src, `${tmpDir}/${FONTS_DIR_NAME}/${names[i]}`);
        }
      }
    } catch (err) {
    }
  }

  private static findBackgroundFile(extractDir: string): string {
    try {
      const bgDir = `${extractDir}/${BACKGROUND_DIR_NAME}`;
      if (!fs.accessSync(bgDir)) {
        return '';
      }
      const names = fs.listFileSync(bgDir);
      for (let i = 0; i < names.length; i++) {
        const full = `${bgDir}/${names[i]}`;
        if (fs.statSync(full).isFile()) {
          return names[i];
        }
      }
      return '';
    } catch (err) {
      return '';
    }
  }

  private static findFontFiles(extractDir: string): string[] {
    const result: string[] = [];
    try {
      const fontsDir = `${extractDir}/${FONTS_DIR_NAME}`;
      if (!fs.accessSync(fontsDir)) {
        return result;
      }
      const names = fs.listFileSync(fontsDir);
      for (let i = 0; i < names.length; i++) {
        const full = `${fontsDir}/${names[i]}`;
        if (fs.statSync(full).isFile()) {
          result.push(names[i]);
        }
      }
      return result;
    } catch (err) {
      return result;
    }
  }

  private static writeTextFile(path: string, content: string): void {
    const file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(file.fd, content);
    } finally {
      fs.closeSync(file);
    }
  }

  private static readTextFileSync(path: string): string {
    const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
    try {
      const stat = fs.statSync(file.fd);
      if (stat.size <= 0 || stat.size > MAX_BACKUP_FILE_SIZE) {
        return '';
      }
      const buffer = new ArrayBuffer(stat.size);
      const readLen = fs.readSync(file.fd, buffer);
      if (readLen <= 0) {
        return '';
      }
      return new util.TextDecoder('utf-8').decode(new Uint8Array(buffer.slice(0, readLen)));
    } finally {
      fs.closeSync(file);
    }
  }

  private static async copySandboxFileToUri(srcPath: string, uri: string): Promise<boolean> {
    try {
      const src = await fs.open(srcPath, fs.OpenMode.READ_ONLY);
      let bytes: ArrayBuffer;
      try {
        const stat = await fs.stat(src.fd);
        const buffer = new ArrayBuffer(stat.size);
        const readLen = await fs.read(src.fd, buffer);
        bytes = buffer.slice(0, readLen);
      } finally {
        await fs.close(src);
      }
      const dst = await fs.open(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      try {
        await fs.write(dst.fd, bytes);
      } finally {
        await fs.close(dst);
      }
      return true;
    } catch (err) {
      return false;
    }
  }

  private static async copyUriToSandboxFile(uri: string, destPath: string): Promise<boolean> {
    try {
      const src = await fs.open(uri, fs.OpenMode.READ_ONLY);
      let bytes: ArrayBuffer;
      try {
        const stat = await fs.stat(src.fd);
        if (stat.size <= 0 || stat.size > MAX_BACKUP_ARCHIVE_SIZE) {
          return false;
        }
        const buffer = new ArrayBuffer(stat.size);
        const readLen = await fs.read(src.fd, buffer);
        bytes = buffer.slice(0, readLen);
      } finally {
        await fs.close(src);
      }
      const dst = await fs.open(destPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      try {
        await fs.write(dst.fd, bytes);
      } finally {
        await fs.close(dst);
      }
      return true;
    } catch (err) {
      return false;
    }
  }

  private static validateExtractedTree(root: string): boolean {
    let fileCount = 0;
    let totalSize = 0;
    try {
      const walk = (dir: string, relativeDir: string): boolean => {
        const names = fs.listFileSync(dir);
        for (let i = 0; i < names.length; i++) {
          const name = names[i];
          if (name.includes('..') || name.includes('/') || name.includes('\\')) {
            return false;
          }
          const full = `${dir}/${name}`;
          const relative = relativeDir.length > 0 ? `${relativeDir}/${name}` : name;
          const stat = fs.statSync(full);
          if (stat.isDirectory()) {
            if (relative !== BACKGROUND_DIR_NAME && relative !== FONTS_DIR_NAME) {
              return false;
            }
            if (!walk(full, relative)) {
              return false;
            }
          } else if (stat.isFile()) {
            fileCount += 1;
            totalSize += stat.size;
            if (fileCount > MAX_EXTRACTED_FILE_COUNT || totalSize > MAX_EXTRACTED_ASSET_SIZE) {
              return false;
            }
            if (relative !== 'package.zip' && relative !== BACKUP_JSON_NAME &&
              !relative.startsWith(`${BACKGROUND_DIR_NAME}/`) &&
              !relative.startsWith(`${FONTS_DIR_NAME}/`)) {
              return false;
            }
          } else {
            return false;
          }
        }
        return true;
      };
      return walk(root, '');
    } catch (err) {
      return false;
    }
  }

  private static uriToPath(uri: string): string {
    if (uri.startsWith('file://')) {
      return uri.substring(7);
    }
    return uri;
  }

  private static removeDirQuietly(dir: string): void {
    try {
      if (!fs.accessSync(dir)) {
        return;
      }
      const names = fs.listFileSync(dir);
      for (let i = 0; i < names.length; i++) {
        const full = `${dir}/${names[i]}`;
        if (fs.statSync(full).isDirectory()) {
          BackupRestoreService.removeDirQuietly(full);
        } else {
          fs.unlinkSync(full);
        }
      }
      fs.rmdirSync(dir);
    } catch (err) {
    }
  }

  private static removeFileQuietly(path: string): void {
    try {
      if (fs.accessSync(path)) {
        fs.unlinkSync(path);
      }
    } catch (err) {
    }
  }

  private static parseBackupContent(text: string): BackupFileContent | null {
    let parsed: Object;
    try {
      parsed = JSON.parse(text);
    } catch (err) {
      return null;
    }
    const raw = parsed as Record<string, Object>;
    if (raw['app'] !== BACKUP_APP_ID || raw['formatVersion'] !== BACKUP_FORMAT_VERSION) {
      return null;
    }
    const rawDeviceInfo = raw['deviceInfo'] as Record<string, Object>;
    const rawSettings = raw['settings'] as Record<string, Object>;
    if (rawDeviceInfo === undefined || rawDeviceInfo === null ||
      rawSettings === undefined || rawSettings === null) {
      return null;
    }
    const deviceInfo = BackupRestoreService.parseDeviceInfo(rawDeviceInfo);
    const content: BackupFileContent = {
      app: BACKUP_APP_ID,
      formatVersion: BACKUP_FORMAT_VERSION,
      exportedAt: BackupRestoreService.asNumber(raw['exportedAt']),
      deviceInfo: deviceInfo,
      settings: rawSettings
    };
    return content;
  }

  private static buildDeviceInfo(homesJson: string, devicesJson: string): BackupDeviceInfo {
    const homes: BackupHomeItem[] = [];
    if (homesJson.length > 0) {
      try {
        const rawHomes = JSON.parse(homesJson) as Object[];
        for (let i = 0; i < rawHomes.length; i++) {
          const home = rawHomes[i] as Record<string, Object>;
          homes.push({
            homeId: BackupRestoreService.asString(home['homeId']),
            name: BackupRestoreService.asString(home['name'])
          });
        }
      } catch (err) {
      }
    }
    const devices: BackupDeviceItem[] = [];
    if (devicesJson.length > 0) {
      try {
        const rawDevices = JSON.parse(devicesJson) as Record<string, Object>;
        const keys = Object.keys(rawDevices);
        for (let i = 0; i < keys.length; i++) {
          const device = rawDevices[keys[i]] as Record<string, Object>;
          devices.push({
            did: BackupRestoreService.asString(device['did']),
            model: BackupRestoreService.asString(device['model']),
            name: BackupRestoreService.asString(device['name'])
          });
        }
      } catch (err) {
      }
    }
    return { homes: homes, devices: devices };
  }

  private static parseDeviceInfo(rawDeviceInfo: Record<string, Object>): BackupDeviceInfo {
    const homes: BackupHomeItem[] = [];
    const rawHomes = rawDeviceInfo['homes'];
    if (rawHomes instanceof Array) {
      for (let i = 0; i < rawHomes.length; i++) {
        const home = rawHomes[i] as Record<string, Object>;
        homes.push({
          homeId: BackupRestoreService.asString(home['homeId']),
          name: BackupRestoreService.asString(home['name'])
        });
      }
    }
    const devices: BackupDeviceItem[] = [];
    const rawDevices = rawDeviceInfo['devices'];
    if (rawDevices instanceof Array) {
      for (let i = 0; i < rawDevices.length; i++) {
        const device = rawDevices[i] as Record<string, Object>;
        devices.push({
          did: BackupRestoreService.asString(device['did']),
          model: BackupRestoreService.asString(device['model']),
          name: BackupRestoreService.asString(device['name'])
        });
      }
    }
    return { homes: homes, devices: devices };
  }

  private static readDeviceInfoFromCache(context: common.UIAbilityContext): BackupDeviceInfo | null {
    try {
      const cache = new JsonCache(context);
      const raw = cache.get(SNAPSHOT_CACHE_KEY);
      if (raw.length === 0) {
        return null;
      }
      const snapshot = JSON.parse(raw) as Record<string, Object>;
      const homesJson = BackupRestoreService.asString(snapshot['homesJson']);
      const devicesJson = BackupRestoreService.asString(snapshot['devicesJson']);
      if (homesJson.length === 0 && devicesJson.length === 0) {
        return null;
      }
      return BackupRestoreService.buildDeviceInfo(homesJson, devicesJson);
    } catch (err) {
      return null;
    }
  }

  private static async readTextFromUri(uri: string): Promise<string> {
    const file = await fs.open(uri, fs.OpenMode.READ_ONLY);
    try {
      const stat = await fs.stat(file.fd);
      const size = stat.size;
      if (size <= 0 || size > MAX_BACKUP_FILE_SIZE) {
        return '';
      }
      const buffer = new ArrayBuffer(size);
      const readLen = await fs.read(file.fd, buffer);
      if (readLen <= 0) {
        return '';
      }
      const bytes = buffer.slice(0, readLen);
      return new util.TextDecoder('utf-8').decode(new Uint8Array(bytes));
    } finally {
      await fs.close(file);
    }
  }

  private static sortHomes(items: BackupHomeItem[]): BackupHomeItem[] {
    const copy = items.slice();
    copy.sort((a: BackupHomeItem, b: BackupHomeItem): number => a.homeId.localeCompare(b.homeId));
    return copy;
  }

  private static sortDevices(items: BackupDeviceItem[]): BackupDeviceItem[] {
    const copy = items.slice();
    copy.sort((a: BackupDeviceItem, b: BackupDeviceItem): number => a.did.localeCompare(b.did));
    return copy;
  }

  /**
   * 恢复时按当前设备情况过滤设置：
   * 1. 内部瞬态键（从不展示）不恢复；
   * 2. 本设备不显示的设置不恢复（自动多栏仅大屏显示）；
   * 3. 恢复后处于禁止更改状态的设置不恢复（自动多栏开启时双列/背景被锁定）。
   */
  private static shouldSkipSetting(
    key: string,
    isLargeScreen: boolean,
    finalAutoMultiColumn: boolean
  ): boolean {
    if (BackupRestoreService.NEVER_RESTORE_KEYS.indexOf(key) >= 0) {
      return true;
    }
    if (key === 'autoMultiColumn' && !isLargeScreen) {
      return true;
    }
    if (BackupRestoreService.isLockedSetting(key, finalAutoMultiColumn)) {
      return true;
    }
    return false;
  }

  private static isLockedSetting(key: string, finalAutoMultiColumn: boolean): boolean {
    return finalAutoMultiColumn && BackupRestoreService.LOCKED_WITH_AUTO_MULTI_COLUMN_KEYS.indexOf(key) >= 0;
  }

  private static resolveAutoMultiColumn(settings: Record<string, Object>, isLargeScreen: boolean): boolean {
    if (isLargeScreen && settings['autoMultiColumn'] !== undefined) {
      return settings['autoMultiColumn'] === true;
    }
    return AppSettingsStore.getBoolean('autoMultiColumn', false);
  }

  private static writeSetting(key: string, value: Object): void {
    if (typeof value === 'string') {
      AppSettingsStore.setString(key, value);
    } else if (typeof value === 'boolean') {
      AppSettingsStore.setBoolean(key, value);
    } else if (typeof value === 'number') {
      AppSettingsStore.setNumber(key, value);
    } else if (value instanceof Array) {
      const items: string[] = [];
      for (let j = 0; j < value.length; j++) {
        items.push(String(value[j]));
      }
      AppSettingsStore.setStringArray(key, items);
    }
  }

  private static isLargeScreenDevice(): boolean {
    try {
      const type = deviceInfo.deviceType;
      return type === 'tablet' || type === '2in1';
    } catch (err) {
      return false;
    }
  }

  private static readonly NEVER_RESTORE_KEYS: string[] = ['dualColumnRestore', 'fullLogStartTime'];

  private static readonly LOCKED_WITH_AUTO_MULTI_COLUMN_KEYS: string[] = ['dualColumnMode', 'backgroundImage'];

  private static asString(value: Object | undefined): string {
    if (value === undefined || value === null) {
      return '';
    }
    return String(value);
  }

  private static asNumber(value: Object | undefined): number {
    return typeof value === 'number' ? value : 0;
  }
}
