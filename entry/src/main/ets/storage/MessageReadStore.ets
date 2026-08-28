/*
 * 鸿米家（miha）— 云端消息已读状态本地存储。
 *
 * 米家消息接口无已读标记，这里按 messageId 本地持久化已读集合，
 * 支持单条标记与全部已读；上限 500 条防止无限膨胀。
 *
 * Copyright (C) 2026 鸿米家（miha）项目开发者
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import { AppSettingsStore } from './AppSettingsStore';

const READ_MESSAGES_KEY: string = 'read_message_ids_v1';
const MAX_READ_IDS: number = 500;

export class MessageReadStore {
  static loadReadIds(): string[] {
    return AppSettingsStore.getStringArray(READ_MESSAGES_KEY, []);
  }

  static isRead(messageId: string): boolean {
    return MessageReadStore.loadReadIds().indexOf(messageId) >= 0;
  }

  /** 标记单条消息已读 */
  static markRead(messageId: string): void {
    if (messageId.length === 0) {
      return;
    }
    const list = MessageReadStore.loadReadIds();
    if (list.indexOf(messageId) >= 0) {
      return;
    }
    list.push(messageId);
    while (list.length > MAX_READ_IDS) {
      list.shift();
    }
    AppSettingsStore.setStringArray(READ_MESSAGES_KEY, list);
  }

  /** 批量标记已读（全部已读） */
  static markAllRead(messageIds: string[]): void {
    const list = MessageReadStore.loadReadIds();
    let changed = false;
    for (let i = 0; i < messageIds.length; i++) {
      const id = messageIds[i];
      if (id.length === 0 || list.indexOf(id) >= 0) {
        continue;
      }
      list.push(id);
      changed = true;
    }
    if (!changed) {
      return;
    }
    while (list.length > MAX_READ_IDS) {
      list.shift();
    }
    AppSettingsStore.setStringArray(READ_MESSAGES_KEY, list);
  }
}
