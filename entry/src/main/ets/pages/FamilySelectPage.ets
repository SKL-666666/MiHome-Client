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
import { XiaomiHome, ALL_HOMES_ID, ALL_HOMES_NAME } from '../models/XiaomiHomeModels';
import { xiaomiDataService } from '../services/XiaomiDataService';
import { HwColor, HwRadius, HwSpace, MijiaOverviewCard, MijiaOverviewCardText, MijiaOverviewCardValue } from '../utils/DesignTokens';
import { IconCircleButton } from '../components/IconCircleButton';
import { AppBackground } from '../components/AppBackground';
import { AppSettingsStore } from '../storage/AppSettingsStore';
import { FeedbackLogService } from '../services/FeedbackLogService';

@Entry
@Component
struct FamilySelectPage {
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
  @StorageLink('selectedHomeId') selectedHomeId: string = '';
  @StorageLink('selectedHomeName') selectedHomeName: string = '';
  @StorageLink('homeSelectionVersion') homeSelectionVersion: number = 0;
  @State homes: XiaomiHome[] = [];
  @State loading: boolean = true;
  @State errorMessage: string = '';
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('navigationBarHeight') navigationBarHeight: number = 0;
  @StorageProp('isDarkMode') isDarkMode: boolean = false;

  aboutToAppear(): void {
    FeedbackLogService.setCurrentPage('选择家庭页');
    this.loadHomes();
  }

  async loadHomes(): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    try {
      this.homes = await xiaomiDataService.getHomes();
    } catch (err) {
      this.errorMessage = err instanceof Error ? err.message : '加载家庭失败';
    } finally {
      this.loading = false;
    }
  }

  selectHome(home: XiaomiHome): void {
    this.selectedHomeId = home.homeId;
    this.selectedHomeName = home.name;
    AppSettingsStore.setString('selectedHomeId', home.homeId);
    AppSettingsStore.setString('selectedHomeName', home.name);
    this.homeSelectionVersion = this.homeSelectionVersion + 1;
    router.back();
  }

  selectAllHomes(): void {
    this.selectedHomeId = ALL_HOMES_ID;
    this.selectedHomeName = ALL_HOMES_NAME;
    AppSettingsStore.setString('selectedHomeId', ALL_HOMES_ID);
    AppSettingsStore.setString('selectedHomeName', ALL_HOMES_NAME);
    this.homeSelectionVersion = this.homeSelectionVersion + 1;
    router.back();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      AppBackground()
      Column() {

      Column({ space: 14 }) {
        Blank().height(42 + this.statusBarHeight)
        if (this.loading) {
          Text('加载中…')
            .fontFamily(this.appFontFamily('加载中…'))
            .fontWeight(this.appFontWeight())
            .fontSize(14)
            .fontColor(HwColor.textSecondary)
            .padding({ top: 24, bottom: 24 })
        }

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontFamily(this.appFontFamily(this.errorMessage))
            .fontWeight(this.appFontWeight())
            .fontSize(14)
            .fontColor(HwColor.danger)
        }

        Scroll() {
          Column({ space: 10 }) {
            Row({ space: 10 }) {
              Column({ space: 4 }) {
                Text(ALL_HOMES_NAME)
                  .fontFamily(this.appFontFamily(ALL_HOMES_NAME))
                  .fontWeight(this.appFontWeight())
                  .fontSize(17)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Color.White)
                Text('显示账号下所有家庭的所有设备')
                  .fontFamily(this.appFontFamily('显示账号下所有家庭的所有设备'))
                  .fontWeight(this.appFontWeight())
                  .fontSize(13)
                  .fontColor(MijiaOverviewCardText)
              }
              .alignItems(HorizontalAlign.Start)
              Blank()
              if (this.selectedHomeId === ALL_HOMES_ID) {
                Text('当前')
                  .fontFamily(this.appFontFamily('当前'))
                  .fontWeight(this.appFontWeight())
                  .fontSize(12)
                  .fontColor(MijiaOverviewCardValue)
              }
            }
            .width('100%')
            .padding(HwSpace.lg)
            .borderRadius(HwRadius.card)
            .backgroundColor(MijiaOverviewCard)
            .border({
              width: this.selectedHomeId === ALL_HOMES_ID ? 1 : 0,
              color: this.selectedHomeId === ALL_HOMES_ID ? MijiaOverviewCardValue : '#00000000'
            })
            .onClick(() => {
              this.selectAllHomes();
            })

            ForEach(this.homes, (home: XiaomiHome) => {
              Row({ space: 10 }) {
                Column({ space: 4 }) {
                  Text(home.name)
                    .fontFamily(this.appFontFamily(home.name))
                    .fontWeight(this.appFontWeight())
                    .fontSize(17)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Color.White)
                  Text(`${home.roomList.length} 个房间`)
                    .fontFamily(this.appFontFamily(`${home.roomList.length} 个房间`))
                    .fontWeight(this.appFontWeight())
                    .fontSize(13)
                    .fontColor(MijiaOverviewCardText)
                }
                .alignItems(HorizontalAlign.Start)
                Blank()
                if (this.selectedHomeId === home.homeId) {
                  Text('当前')
                    .fontFamily(this.appFontFamily('当前'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(12)
                    .fontColor(MijiaOverviewCardValue)
                }
              }
              .width('100%')
              .padding(HwSpace.lg)
              .borderRadius(HwRadius.card)
              .backgroundColor(MijiaOverviewCard)
              .border({
                width: this.selectedHomeId === home.homeId ? 1 : 0,
                color: this.selectedHomeId === home.homeId ? MijiaOverviewCardValue : '#00000000'
              })
              .onClick(() => {
                this.selectHome(home);
              })
            }, (home: XiaomiHome) => home.homeId)
          }
          .width('100%')
        }
        .layoutWeight(1)
      }
      .padding({
        left: HwSpace.xl,
        right: HwSpace.xl,
        top: HwSpace.xl,
        bottom: HwSpace.xl + this.navigationBarHeight
      })
      .width('100%')
      .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)

      Row() {
        IconCircleButton({
          symbol: $r('sys.symbol.chevron_left'),
          buttonSize: 40,
          iconSize: 20,
          tint: '#FFFFFF',
          onAction: () => {
            router.back();
          }
        })
        Text('选择家庭')
          .fontFamily(this.appFontFamily('选择家庭'))
          .fontWeight(this.appFontWeight())
          .margin({ left: HwSpace.md })
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
        Blank()
      }
      .width('100%')
      .height(56 + this.statusBarHeight)
      .padding({ left: 16, right: 16, top: this.statusBarHeight })
      .linearGradient({
        angle: 90,
        colors: [['#E62F658C', 0], ['#E63B7094', 0.5], ['#E646789C', 1]]
      })
      .backgroundEffect({ radius: 30, saturation: 1.5, color: '#33FFFFFF' })
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
