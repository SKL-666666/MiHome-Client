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

import { deviceInfo } from '@kit.BasicServicesKit';

/**
 * 当前运行系统 API 是否 >= 26。
 */
export function isApi26OrAbove(): boolean {
  try {
    return deviceInfo.sdkApiVersion >= 26;
  } catch (err) {
    return false;
  }
}

/**
 * 卡片一律使用纯白实色（米家浅蓝白风格），不再使用毛玻璃 / 沉浸光感材质。
 * 旧版本依赖 API 24+ 的 uiMaterial（@kit.ArkUI），在低版本 SDK 上不可用，
 * 因此统一改为实色背景，保证跨版本一致渲染。
 */
export class ImmersiveMaterialModifier implements AttributeModifier<CommonAttribute> {
  applyNormalAttribute(instance: CommonAttribute): void {
    instance.backgroundColor(Color.White);
  }
}

export const immersiveMaterialModifier: ImmersiveMaterialModifier = new ImmersiveMaterialModifier();

/**
 * 旧毛玻璃修饰器，同样改为纯白实色。
 */
export class LegacyMaterialModifier implements AttributeModifier<CommonAttribute> {
  applyNormalAttribute(instance: CommonAttribute): void {
    instance.backgroundColor(Color.White);
  }
}

export const legacyMaterialModifier: LegacyMaterialModifier = new LegacyMaterialModifier();

/**
 * 底部弹窗使用纯色背景，不叠加系统材质。
 * 返回 undefined 并保留导出，兼容既有调用；调用方不再把结果传给 SheetOptions。
 */
export function sheetSystemMaterial(): Object | undefined {
  return undefined;
}

export function sheetBlurStyle(): BlurStyle | undefined {
  return undefined;
}
