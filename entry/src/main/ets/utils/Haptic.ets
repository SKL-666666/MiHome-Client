/*
 * 鸿米家（miha）— 轻量触感反馈封装。
 *
 * 统一使用系统预置 soft 震动效果（usage=touch），
 * 未授予 VIBRATE 或设备不支持时静默失败，不干扰主流程。
 *
 * Copyright (C) 2026 鸿米家（miha）项目开发者
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import { vibrator } from '@kit.SensorServiceKit';

export class Haptic {
  /** 轻触反馈：点按设备卡片、收藏切换、消息点击等场景 */
  static soft(): void {
    try {
      const effect: vibrator.VibratePreset = {
        type: 'preset',
        effectId: 'haptic.effect.soft',
        count: 1
      };
      const attribute: vibrator.VibrateAttribute = {
        usage: 'touch'
      };
      vibrator.startVibration(effect, attribute).catch((): void => {
      });
    } catch (err) {
    }
  }

  /** 成功反馈：一键关灯等批量操作完成时使用 */
  static success(): void {
    try {
      const effect: vibrator.VibratePreset = {
        type: 'preset',
        effectId: 'haptic.notice.success',
        count: 1
      };
      const attribute: vibrator.VibrateAttribute = {
        usage: 'touch'
      };
      vibrator.startVibration(effect, attribute).catch((): void => {
      });
    } catch (err) {
    }
  }
}
