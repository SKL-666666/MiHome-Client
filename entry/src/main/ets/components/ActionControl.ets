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

import { ActionControlDescriptor } from './CapabilityRenderer';
import { HwRadius, HwSpace, MijiaOverviewCard, MijiaOverviewCardText, MijiaOverviewCardValue } from '../utils/DesignTokens';

@Component
export struct ActionControl {
  @Prop control: ActionControlDescriptor;
  @Prop loading: boolean;
  @StorageLink('fontMode') fontMode: string = 'system';
  @StorageLink('fontFamilyEn') fontFamilyEn: string = 'system';
  @StorageLink('fontFamilyZh') fontFamilyZh: string = 'system';
  @StorageLink('fontWeightMode') fontWeightMode: string = 'system';
  @StorageLink('fontWeightValue') fontWeightValue: number = 400;
  onAction: () => void = (): void => {
  };

  private appFontFamily(content: string): string {
    if (this.fontMode !== 'custom') {
      return '';
    }
    const family = this.hasCjk(content) ? this.fontFamilyZh : this.fontFamilyEn;
    return family === 'system' || family.length === 0 ? '' : family;
  }

  private hasCjk(content: string): boolean {
    for (let i = 0; i < content.length; i++) {
      const code = content.charCodeAt(i);
      if (code >= 0x4E00 && code <= 0x9FFF) {
        return true;
      }
    }
    return false;
  }

  private appFontWeight(): number {
    return this.fontWeightMode === 'custom' ? this.fontWeightValue : 400;
  }

  build() {
    // 动作卡片：图标 + 动作名 + 说明，点击执行
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.loading) {
          LoadingProgress()
            .width(20)
            .height(20)
            .color(MijiaOverviewCardValue)
        } else {
          SymbolGlyph($r('sys.symbol.bolt'))
            .fontSize(20)
            .fontColor([MijiaOverviewCardValue])
        }
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor('#14000000')

      Column({ space: 3 }) {
        Text(this.loading ? '执行中…' : this.control.label)
          .fontFamily(this.appFontFamily(this.loading ? '执行中…' : this.control.label))
          .fontWeight(this.appFontWeight())
          .fontSize(15)
          .fontColor(Color.White)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.loading ? '正在执行，请稍候' : '点击执行此动作')
          .fontFamily(this.appFontFamily(this.loading ? '正在执行，请稍候' : '点击执行此动作'))
          .fontWeight(this.appFontWeight())
          .fontSize(11)
          .fontColor(MijiaOverviewCardText)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([MijiaOverviewCardText])
    }
    .width('100%')
    .padding(HwSpace.lg)
    .borderRadius(HwRadius.card)
    .backgroundColor(MijiaOverviewCard)
    .border({ width: 1, color: '#24FFFFFF' })
    .clip(true)
    .opacity(this.loading ? 0.6 : 1)
    .onClick(() => {
      if (!this.loading) {
        this.onAction();
      }
    })
  }
}
