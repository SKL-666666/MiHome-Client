/*
 * 鸿米家（miha）— 已删除设备记录（本地管理）。
 *
 * 米家 API 不提供设备删除接口，因此在本地记录用户主动「删除」的设备，
 * 全局过滤（首页、设备管理、创建智能等均不再展示）。
 *
 * Copyright (C) 2026 鸿米家（miha）项目开发者
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import { AppSettingsStore } from './AppSettingsStore';

const REMOVED_KEY: string = 'removed_device_dids_v1';

/** 具有设备标识 did 的对象（用于泛型过滤） */
interface RemovableDevice {
  did: string;
}

export class DeviceRemovalStore {
  static load(): string[] {
    return AppSettingsStore.getStringArray(REMOVED_KEY, []);
  }

  static isRemoved(did: string): boolean {
    return DeviceRemovalStore.load().indexOf(did) >= 0;
  }

  /** 将设备标记为已删除（本地） */
  static remove(did: string): void {
    const list = DeviceRemovalStore.load();
    if (list.indexOf(did) >= 0) {
      return;
    }
    list.push(did);
    AppSettingsStore.setStringArray(REMOVED_KEY, list);
  }

  /** 撤销删除（从已删除列表中移除） */
  static restore(did: string): void {
    const list = DeviceRemovalStore.load();
    const idx = list.indexOf(did);
    if (idx < 0) {
      return;
    }
    list.splice(idx, 1);
    AppSettingsStore.setStringArray(REMOVED_KEY, list);
  }

  /** 过滤掉已删除的设备 */
  static filter<T extends RemovableDevice>(devices: T[]): T[] {
    const removed = DeviceRemovalStore.load();
    if (removed.length === 0) {
      return devices;
    }
    return devices.filter((device: T) => removed.indexOf(device.did) < 0);
  }
}
