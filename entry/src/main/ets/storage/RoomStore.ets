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

import { AppSettingsStore } from './AppSettingsStore';

/**
 * 用户自定义房间（本地管理，不同步小米云端家庭房间）。
 */
export interface UserRoom {
  /** 房间唯一标识 */
  id: string;
  /** 楼层，如 3、B1 */
  floor: string;
  /** 房间名，如 卧室、客厅 */
  name: string;
  /** 房间所属家庭 ID，空表示未指定家庭 */
  homeId: string;
  /** 房间所属家庭名称 */
  homeName: string;
  /** 已添加到该房间的设备 did 列表 */
  dids: string[];
}

const ROOMS_STORAGE_KEY: string = 'user_rooms_v1';

export class RoomStore {
  static loadRooms(): UserRoom[] {
    const raw = AppSettingsStore.getString(ROOMS_STORAGE_KEY, '');
    if (raw.length === 0) {
      return [];
    }
    try {
      const parsed = JSON.parse(raw) as Object;
      if (parsed instanceof Array) {
        const rooms: UserRoom[] = [];
        for (let i = 0; i < parsed.length; i++) {
          const item = parsed[i] as Record<string, Object>;
          rooms.push({
            id: asString(item['id']),
            floor: asString(item['floor']),
            name: asString(item['name']),
            homeId: asString(item['homeId']),
            homeName: asString(item['homeName']),
            dids: parseStringArray(item['dids'])
          });
        }
        return rooms;
      }
    } catch (err) {
      // 忽略损坏的缓存数据，按空列表处理
    }
    return [];
  }

  static saveRooms(rooms: UserRoom[]): void {
    AppSettingsStore.setString(ROOMS_STORAGE_KEY, JSON.stringify(rooms));
  }

  static upsertRoom(room: UserRoom): void {
    const rooms = RoomStore.loadRooms();
    let found = false;
    for (let i = 0; i < rooms.length; i++) {
      if (rooms[i].id === room.id) {
        rooms[i] = room;
        found = true;
        break;
      }
    }
    if (!found) {
      rooms.push(room);
    }
    RoomStore.saveRooms(rooms);
  }
}

function asString(value: Object | undefined): string {
  return value === undefined || value === null ? '' : String(value);
}

function parseStringArray(value: Object | undefined): string[] {
  if (!(value instanceof Array)) {
    return [];
  }
  const result: string[] = [];
  for (let i = 0; i < value.length; i++) {
    result.push(String(value[i]));
  }
  return result;
}
