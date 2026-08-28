/*
 * 鸿米家（miha）— 本地智能场景持久化存储。
 *
 * Copyright (C) 2026 鸿米家（miha）项目开发者
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import { LocalScene, LocalSceneAction } from '../models/XiaomiHomeModels';
import { AppSettingsStore } from './AppSettingsStore';

const LOCAL_SCENES_KEY: string = 'localScenes';

/** 本地自建智能的读取与保存（JSON 序列化到 Preferences） */
export class LocalSceneStore {
  static load(): LocalScene[] {
    const raw = AppSettingsStore.getString(LOCAL_SCENES_KEY, '');
    if (raw.length === 0) {
      return [];
    }
    try {
      const parsed = JSON.parse(raw) as Object;
      if (!(parsed instanceof Array)) {
        return [];
      }
      const scenes: LocalScene[] = [];
      for (let i = 0; i < parsed.length; i++) {
        const obj = parsed[i] as Record<string, Object>;
        const actions: LocalSceneAction[] = [];
        const rawActions = obj['actions'];
        if (rawActions instanceof Array) {
          for (let j = 0; j < rawActions.length; j++) {
            const ao = rawActions[j] as Record<string, Object>;
            const valueText = ao['valueText'];
            actions.push({
              did: String(ao['did']),
              deviceName: String(ao['deviceName']),
              siid: Number(ao['siid']),
              piid: Number(ao['piid']),
              label: String(ao['label']),
              value: ao['value'],
              valueText: valueText === undefined ? undefined : String(valueText)
            });
          }
        }
        const timerDaysValue = String(obj['timerDays'] ?? '');
        scenes.push({
          sceneId: String(obj['sceneId']),
          name: String(obj['name']),
          actions: actions,
          timerEnabled: obj['timerEnabled'] === true,
          timerHour: obj['timerHour'] === undefined ? 8 : Number(obj['timerHour']),
          timerMinute: obj['timerMinute'] === undefined ? 0 : Number(obj['timerMinute']),
          timerDays: timerDaysValue.length === 7 ? timerDaysValue : '1111111',
          lastFireDay: String(obj['lastFireDay'] ?? '')
        });
      }
      return scenes;
    } catch (err) {
      return [];
    }
  }

  static save(scenes: LocalScene[]): void {
    AppSettingsStore.setString(LOCAL_SCENES_KEY, JSON.stringify(scenes));
  }

  static delete(sceneId: string): void {
    const scenes = LocalSceneStore.load();
    const next: LocalScene[] = [];
    for (let i = 0; i < scenes.length; i++) {
      if (scenes[i].sceneId !== sceneId) {
        next.push(scenes[i]);
      }
    }
    LocalSceneStore.save(next);
  }

  static update(scene: LocalScene): void {
    const scenes = LocalSceneStore.load();
    const next: LocalScene[] = [];
    for (let i = 0; i < scenes.length; i++) {
      next.push(scenes[i].sceneId === scene.sceneId ? scene : scenes[i]);
    }
    LocalSceneStore.save(next);
  }
}
