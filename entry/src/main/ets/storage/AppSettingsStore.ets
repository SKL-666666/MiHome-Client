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

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const STORE_NAME = 'miha_settings';

export class AppSettingsStore {
  private static prefs: preferences.Preferences | null = null;

  static init(context: common.UIAbilityContext): void {
    if (AppSettingsStore.prefs === null) {
      AppSettingsStore.prefs = preferences.getPreferencesSync(context, {
        name: STORE_NAME
      });
    }
  }

  private static store(): preferences.Preferences {
    if (AppSettingsStore.prefs === null) {
      throw new Error('settings store not initialized');
    }
    return AppSettingsStore.prefs;
  }

  static has(key: string): boolean {
    return AppSettingsStore.store().hasSync(key);
  }

  static getAll(): Record<string, Object> {
    return AppSettingsStore.store().getAllSync() as Record<string, Object>;
  }

  static getBoolean(key: string, defaultValue: boolean): boolean {
    const value = AppSettingsStore.store().getSync(key, defaultValue);
    return typeof value === 'boolean' ? value : defaultValue;
  }

  static getString(key: string, defaultValue: string): string {
    const value = AppSettingsStore.store().getSync(key, defaultValue);
    return typeof value === 'string' ? value : defaultValue;
  }

  static getNumber(key: string, defaultValue: number): number {
    const value = AppSettingsStore.store().getSync(key, defaultValue);
    return typeof value === 'number' ? value : defaultValue;
  }

  static getStringArray(key: string, defaultValue: string[]): string[] {
    const raw = AppSettingsStore.getString(key, '');
    if (raw.length === 0) {
      return defaultValue.slice();
    }
    try {
      const parsed = JSON.parse(raw) as Object;
      if (parsed instanceof Array) {
        return parsed.map((item: Object) => String(item));
      }
    } catch (err) {
    }
    return defaultValue.slice();
  }

  static setBoolean(key: string, value: boolean): void {
    AppSettingsStore.store().putSync(key, value);
    AppSettingsStore.store().flushSync();
  }

  static setString(key: string, value: string): void {
    AppSettingsStore.store().putSync(key, value);
    AppSettingsStore.store().flushSync();
  }

  static setNumber(key: string, value: number): void {
    AppSettingsStore.store().putSync(key, value);
    AppSettingsStore.store().flushSync();
  }

  static setStringArray(key: string, value: string[]): void {
    AppSettingsStore.setString(key, JSON.stringify(value));
  }

  static delete(key: string): void {
    AppSettingsStore.store().deleteSync(key);
    AppSettingsStore.store().flushSync();
  }
}
