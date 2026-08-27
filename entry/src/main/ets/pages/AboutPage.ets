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

import { router } from '@kit.ArkUI';
import { bundleManager, common, Want } from '@kit.AbilityKit';
import { HwColor, HwRadius, HwSpace, MijiaOverviewCard, MijiaOverviewCardText } from '../utils/DesignTokens';
import { IconCircleButton } from '../components/IconCircleButton';
import { AppBackground } from '../components/AppBackground';
import { FeedbackLogService } from '../services/FeedbackLogService';

@Entry
@Component
struct AboutPage {
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
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('isDarkMode') isDarkMode: boolean = false;
  @StorageProp('navigationBarHeight') navigationBarHeight: number = 0;
  @State versionName: string = '';
  @State versionCode: number = 0;

  aboutToAppear(): void {
    FeedbackLogService.setCurrentPage('关于页');
    this.versionName = this.readVersionName();
    this.versionCode = this.readVersionCode();
  }

  readVersionName(): string {
    try {
      const bundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      );
      return bundleInfo.versionName;
    } catch (err) {
      return '1.0.0.2';
    }
  }

  readVersionCode(): number {
    try {
      const bundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      );
      return bundleInfo.versionCode;
    } catch (err) {
      return 0;
    }
  }

  openUrl(url: string): void {
    if (url.length === 0) {
      return;
    }
    const context = getContext(this) as common.UIAbilityContext;
    const want: Want = {
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: url
    };
    context.startAbility(want).catch((err: Error) => {
      // Keep the page stable when no browser is available.
    });
  }

  @Builder
  linkRow(label: string, url: string) {
    Row({ space: 10 }) {
      Text(label)
        .fontFamily(this.appFontFamily(label))
        .fontWeight(this.appFontWeight())
        .fontSize(15)
        .fontColor(Color.White)
        .layoutWeight(1)
      if (url.length > 0) {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([MijiaOverviewCardText])
      }
    }
    .width('100%')
    .padding(HwSpace.lg)
    .onClick(() => {
      this.openUrl(url);
    })
  }

  build() {
    Stack() {
      AppBackground()
      Column() {
        Row() {
          IconCircleButton({
          symbol: $r('sys.symbol.chevron_left'),
          buttonSize: 40,
          iconSize: 20,
          onAction: () => {
            router.back();
          }
        })
        Text('关于')
          .fontFamily(this.appFontFamily('关于'))
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

      Scroll() {
        Column({ space: 24 }) {
          Column({ space: 10 }) {
            Image($r('app.media.ico'))
              .width(96)
              .height(96)
              .borderRadius(24)
              .objectFit(ImageFit.Cover)
            Text('鸿米家')
              .fontFamily(this.appFontFamily('鸿米家'))
              .fontWeight(this.appFontWeight())
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(HwColor.textPrimary)
            Text(`版本 ${this.versionName}`)
              .fontFamily(this.appFontFamily(`版本 ${this.versionName}`))
              .fontWeight(this.appFontWeight())
              .fontSize(14)
              .fontColor(HwColor.textSecondary)
            Text(`(${this.versionCode})`)
              .fontFamily(this.appFontFamily(`(${this.versionCode})`))
              .fontWeight(this.appFontWeight())
              .fontSize(12)
              .fontColor(HwColor.textSecondary)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .margin({ top: 28 })

          Column({ space: 0 }) {
            this.linkRow('开发者：开心就好无需烦恼', 'https://www.coolapk.com/u/6069943')
            Divider()
              .color('#14000000')
              .margin({ left: HwSpace.lg, right: HwSpace.lg })
            this.linkRow('项目地址', '')
            Divider()
              .color('#14000000')
              .margin({ left: HwSpace.lg, right: HwSpace.lg })
            this.linkRow('米家开源地址', 'https://github.com/XiaoMi/ha_xiaomi_home')
          }
          .width('100%')
          .borderRadius(HwRadius.card)
          .backgroundColor(MijiaOverviewCard)
          .border({ width: 1, color: '#24FFFFFF' })
          .clip(true)

        }
        .width('100%')
        .padding({ left: HwSpace.lg, right: HwSpace.lg, bottom: 24 })
      }
      .layoutWeight(1)

      Text('本版本新增了日志功能，反馈BUG请提交日志')
        .fontFamily(this.appFontFamily('本版本新增了日志功能，反馈BUG请提交日志'))
        .fontWeight(this.appFontWeight())
        .fontSize(12)
        .fontColor(HwColor.textSecondary)
        .textAlign(TextAlign.Center)
        .lineHeight(18)
        .width('100%')
        .padding({ left: HwSpace.xl, right: HwSpace.xl, bottom: this.navigationBarHeight + 12 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isDarkMode ? HwColor.backgroundDark : HwColor.background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .keyboardShortcut(FunctionKey.ESC, [], () => {
      router.back();
    })
  }
}
