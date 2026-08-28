/*
 * 鸿米家（miha）— 设备本地管理（显示名覆盖 + 收藏）。
 *
 * 米家 API 不提供设备改名接口，因此在本地保存「显示名覆盖」，
 * 首页、详情页、搜索均优先展示覆盖名；收藏列表用于首页置顶排序。
 *
 * Copyright (C) 2026 鸿米家（miha）项目开发者
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import { AppSettingsStore } from './AppSettingsStore';

const NAME_OVERRIDES_KEY: string = 'device_name_overrides_v1';
const FAVORITES_KEY: string = 'favorite_device_dids_v1';

export class DeviceOverrideStore {
  static loadNameOverrides(): Record<string, string> {
    const raw = AppSettingsStore.getString(NAME_OVERRIDES_KEY, '');
    if (raw.length === 0) {
      return {} as Record<string, string>;
    }
    try {
      return JSON.parse(raw) as Record<string, string>;
    } catch (err) {
      return {} as Record<string, string>;
    }
  }

  /** 返回设备显示名：本地覆盖名优先，其次云端名称 */
  static getDisplayName(did: string, cloudName: string): string {
    const overrides = DeviceOverrideStore.loadNameOverrides();
    const override = overrides[did];
    if (override !== undefined && override.length > 0) {
      return override;
    }
    return cloudName;
  }

  /** 保存显示名覆盖（空字符串表示恢复云端名称） */
  static setNameOverride(did: string, name: string): void {
    const overrides = DeviceOverrideStore.loadNameOverrides();
    const next: Record<string, string> = {};
    const keys = Object.keys(overrides);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      if (key !== did) {
        next[key] = overrides[key];
      }
    }
    const trimmed = name.trim();
    if (trimmed.length > 0) {
      next[did] = trimmed;
    }
    AppSettingsStore.setString(NAME_OVERRIDES_KEY, JSON.stringify(next));
  }

  static loadFavorites(): string[] {
    return AppSettingsStore.getStringArray(FAVORITES_KEY, []);
  }

  static isFavorite(did: string): boolean {
    return DeviceOverrideStore.loadFavorites().indexOf(did) >= 0;
  }

  /** 切换收藏状态，返回切换后是否处于收藏 */
  static toggleFavorite(did: string): boolean {
    const list = DeviceOverrideStore.loadFavorites();
    const idx = list.indexOf(did);
    if (idx >= 0) {
      list.splice(idx, 1);
      AppSettingsStore.setStringArray(FAVORITES_KEY, list);
      return false;
    }
    list.push(did);
    AppSettingsStore.setStringArray(FAVORITES_KEY, list);
    return true;
  }
}
