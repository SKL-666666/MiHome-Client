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

import { HdsNavDestination } from '@kit.UIDesignKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { HwColor, HwRadius, HwSpace, MijiaOverviewCard, MijiaOverviewCardText } from '../utils/DesignTokens';
import { AppBackground } from '../components/AppBackground';
import { IconCircleButton } from '../components/IconCircleButton';
import { AboutDeviceRouteParam } from '../models/NavRouteParams';
import { FeedbackLogService } from '../services/FeedbackLogService';

@Builder
export function AboutDeviceBuilder(name: string, param: Object) {
  AboutDevicePage({
    deviceName: (param as AboutDeviceRouteParam).name,
    manufacturer: (param as AboutDeviceRouteParam).manufacturer,
    model: (param as AboutDeviceRouteParam).model,
    serial: (param as AboutDeviceRouteParam).serial,
    firmware: (param as AboutDeviceRouteParam).firmware
  })
}

@Component
export struct AboutDevicePage {
  @StorageLink('immersiveLightEnabled') immersiveLightEnabled: boolean = true;
  @StorageLink('cardsFromTop') cardsFromTop: boolean = true;
  @StorageLink('fontMode') fontMode: string = 'system';
  @StorageLink('fontFamilyEn') fontFamilyEn: string = 'system';
  @StorageLink('fontFamilyZh') fontFamilyZh: string = 'system';

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
  @StorageLink('fontWeightMode') fontWeightMode: string = 'system';
  @StorageLink('fontWeightValue') fontWeightValue: number = 400;

  private appFontWeight(): number {
    return this.fontWeightMode === 'custom' ? this.fontWeightValue : 400;
  }
  @Consume('pageInfos') pageInfos: NavPathStack;
  @Prop deviceName: string = '';
  @Prop manufacturer: string = '';
  @StorageProp('isDarkMode') isDarkMode: boolean = false;
  @Prop model: string = '';
  @Prop serial: string = '';
  @Prop firmware: string = '';
  private scroller: Scroller = new Scroller();
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;

  aboutToAppear(): void {
    FeedbackLogService.setCurrentPage('关于设备页');
    FeedbackLogService.recordOperation('PAGE',
      `设备信息: ${this.deviceName} 厂商=${this.manufacturer} 型号=${this.model} 序列号=${this.serial} 固件=${this.firmware}`);
  }

  @Builder
  infoRow(label: string, value: string) {
    Row({ space: 12 }) {
      Text(label)
        .fontFamily(this.appFontFamily(label))
        .fontWeight(this.appFontWeight())
        .fontSize(15)
        .fontColor(Color.White)
        .layoutWeight(1)
      Text(value.length > 0 ? value : '--')
        .fontFamily(this.appFontFamily(value.length > 0 ? value : '--'))
        .fontWeight(this.appFontWeight())
        .fontSize(15)
        .fontColor(MijiaOverviewCardText)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      SymbolGlyph($r('sys.symbol.square_on_square_fill'))
        .fontSize(15)
        .fontColor([MijiaOverviewCardText])
    }
    .width('100%')
    .padding(HwSpace.lg)
    .borderRadius(HwRadius.control)
    .onClick(() => {
      this.copyInfoRow(label, value);
    })
  }

  private async copyInfoRow(label: string, value: string): Promise<void> {
    const copyContent = value.length > 0 ? value : '--';
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, copyContent);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      await systemPasteboard.setData(data);
      this.getUIContext().getPromptAction().showToast({ message: `已复制${label}` });
    } catch (err) {
      this.getUIContext().getPromptAction().showToast({ message: '复制失败，请重试' });
    }
  }

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        AppBackground()

        Scroll(this.scroller) {
          Column({ space: 0 }) {
            Blank().height(56 + this.statusBarHeight)

            Column({ space: 0 }) {
              this.infoRow('设备名称', this.deviceName)
              Divider()
                .color('#14000000')
                .margin({ left: HwSpace.lg, right: HwSpace.lg })
              this.infoRow('设备制造商', this.manufacturer)
              Divider()
                .color('#14000000')
                .margin({ left: HwSpace.lg, right: HwSpace.lg })
              this.infoRow('设备型号', this.model)
              Divider()
                .color('#14000000')
                .margin({ left: HwSpace.lg, right: HwSpace.lg })
              this.infoRow('设备序列号', this.serial)
              Divider()
                .color('#14000000')
                .margin({ left: HwSpace.lg, right: HwSpace.lg })
              this.infoRow('固件版本', this.firmware)
            }
            .width('100%')
            .borderRadius(HwRadius.card)
            .backgroundColor(MijiaOverviewCard)
            .border({ width: 1, color: '#24FFFFFF' })
            .clip(true)
            .margin({ left: HwSpace.lg, right: HwSpace.lg })

            Blank().height(40)
          }
          .width('100%')
        }
        .width('100%')
        .height('100%')
        .align(this.cardsFromTop ? Alignment.Top : Alignment.Center)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)

        Row() {
          IconCircleButton({
            symbol: $r('sys.symbol.chevron_left'),
            onAction: () => {
              this.pageInfos.pop();
            }
          })
          Text('关于本设备')
            .fontFamily(this.appFontFamily('关于本设备'))
            .fontWeight(this.appFontWeight())
            .margin({ left: HwSpace.md })
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(HwColor.textPrimary)
          Blank()
        }
        .width('100%')
        .height(56 + this.statusBarHeight)
        .padding({ left: 16, right: 16, top: this.statusBarHeight })
        .backgroundColor('#FFFFFF')
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isDarkMode ? HwColor.backgroundDark : HwColor.background)
    .hideTitleBar(true)
    .hideBackButton(true)
    .hideToolBar(true, true)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .keyboardShortcut(FunctionKey.ESC, [], () => {
      this.pageInfos.pop();
    })
  }
}
