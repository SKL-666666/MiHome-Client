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

const CACHE_NAME = 'xiaomi_home_cache';

export class JsonCache {
  private readonly prefs: preferences.Preferences;

  constructor(context: common.UIAbilityContext) {
    this.prefs = preferences.getPreferencesSync(context, {
      name: CACHE_NAME
    });
  }

  get(key: string): string {
    const value = this.prefs.getSync(key, '');
    return typeof value === 'string' ? value : '';
  }

  set(key: string, json: string): void {
    this.prefs.putSync(key, json);
    this.prefs.flushSync();
  }

  delete(key: string): void {
    this.prefs.deleteSync(key);
    this.prefs.flushSync();
  }
}
