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
import { HwColor, HwRadius, HwSpace, MijiaOverviewCard, MijiaOverviewCardText, MijiaOverviewCardValue } from '../utils/DesignTokens';
import { IconCircleButton } from '../components/IconCircleButton';
import { AppBackground } from '../components/AppBackground';
import { xiaomiDataService } from '../services/XiaomiDataService';
import { FeedbackLogService } from '../services/FeedbackLogService';
import { AppSettingsStore } from '../storage/AppSettingsStore';
import { MijiaConsumableItem, MijiaConsumableDetail } from '../cloud/MijiaApiClient';
import { Logger } from '../utils/Logger';

@Entry
@Component
struct ConsumablesPage {
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
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('isDarkMode') isDarkMode: boolean = false;
  @StorageProp('currentWidthBreakpoint') @Watch('onBreakpointChange')
  widthBp: WidthBreakpoint = WidthBreakpoint.WIDTH_SM;
  @State isWideScreen: boolean = false;
  @State items: MijiaConsumableItem[] = [];
  @State loading: boolean = true;
  @State refreshing: boolean = false;
  @State errorMessage: string = '';
  private loadSeq: number = 0;

  private topOffset(): number {
    return 56 + this.statusBarHeight;
  }

  aboutToAppear(): void {
    FeedbackLogService.setCurrentPage('耗材中心');
    this.onBreakpointChange();
    this.loadConsumables();
  }

  onBreakpointChange(): void {
    this.isWideScreen = this.widthBp === WidthBreakpoint.WIDTH_LG ||
      this.widthBp === WidthBreakpoint.WIDTH_MD;
  }

  private handleRefresh(): void {
    this.refreshing = true;
    this.loadConsumables();
  }

  private async loadConsumables(): Promise<void> {
    const seq = ++this.loadSeq;
    this.loading = true;
    this.errorMessage = '';
    try {
      const homeId = AppSettingsStore.getString('selectedHomeId', '');
      if (homeId.length === 0) {
        this.errorMessage = '请先在首页选择家庭';
        this.items = [];
        return;
      }
      const result = await xiaomiDataService.getConsumableItems(homeId);
      if (seq !== this.loadSeq) {
        return;
      }
      const usable: MijiaConsumableItem[] = [];
      for (let i = 0; i < result.length; i++) {
        if (result[i].details.length > 0) {
          usable.push(result[i]);
        }
      }
      this.items = usable;
      FeedbackLogService.recordOperation('PAGE', `耗材中心: ${usable.length} 台设备有耗材信息`);
    } catch (err) {
      if (seq !== this.loadSeq) {
        return;
      }
      Logger.error('load consumables failed, %{public}s',
        err instanceof Error ? err.message : String(err));
      this.errorMessage = '耗材信息加载失败，下拉刷新或点击右上角重试';
      this.items = [];
    } finally {
      if (seq === this.loadSeq) {
        this.loading = false;
        this.refreshing = false;
      }
    }
  }

  private detailColor(percent: number): ResourceColor {
    if (percent >= 0 && percent < 20) {
      return HwColor.danger;
    }
    if (percent >= 0 && percent < 50) {
      return '#FFB340';
    }
    return HwColor.primary;
  }

  @Builder
  consumableDetailRow(detail: MijiaConsumableDetail) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Text(detail.name)
          .fontFamily(this.appFontFamily(detail.name))
          .fontWeight(this.appFontWeight())
          .fontSize(14)
          .fontColor(Color.White)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (detail.remainText.length > 0) {
          Text(detail.remainText)
            .fontFamily(this.appFontFamily(detail.remainText))
            .fontWeight(this.appFontWeight())
            .fontSize(12)
            .fontColor(MijiaOverviewCardText)
            .maxLines(1)
        }
        if (detail.percent >= 0) {
          Text(`${Math.round(detail.percent)}%`)
            .fontFamily(this.appFontFamily(`${Math.round(detail.percent)}%`))
            .fontWeight(this.appFontWeight())
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.detailColor(detail.percent))
            .maxLines(1)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (detail.percent >= 0) {
        Progress({ value: Math.max(0, Math.min(100, detail.percent)), total: 100, type: ProgressType.Linear })
          .width('100%')
          .height(8)
          .color(this.detailColor(detail.percent))
          .backgroundColor('#24FFFFFF')
          .borderRadius(4)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  consumableCard(item: MijiaConsumableItem) {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.leaf'))
          .fontSize(18)
          .fontColor([Color.White])
        Text(item.name.length > 0 ? item.name : item.model)
          .fontFamily(this.appFontFamily(item.name.length > 0 ? item.name : item.model))
          .fontWeight(this.appFontWeight())
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(`${item.details.length} 项耗材`)
          .fontFamily(this.appFontFamily(`${item.details.length} 项耗材`))
          .fontWeight(this.appFontWeight())
          .fontSize(12)
          .fontColor(MijiaOverviewCardText)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Divider()
        .color('#24FFFFFF')

      ForEach(item.details, (detail: MijiaConsumableDetail) => {
        this.consumableDetailRow(detail)
      }, (detail: MijiaConsumableDetail, index: number) => `${item.did}_${index}_${detail.name}`)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(HwSpace.lg)
    .borderRadius(HwRadius.card)
    .backgroundColor(MijiaOverviewCard)
    .border({ width: 1, color: '#24FFFFFF' })
    .clip(true)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      AppBackground()
      Column() {
        Refresh({ refreshing: $$this.refreshing }) {
        Scroll() {
          Column({ space: 0 }) {
            Blank().height(this.topOffset())
            Column({ space: 12 }) {
              if (this.errorMessage.length > 0) {
                Text(this.errorMessage)
                  .fontFamily(this.appFontFamily(this.errorMessage))
                  .fontWeight(this.appFontWeight())
                  .fontSize(14)
                  .fontColor(HwColor.danger)
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding({ top: 12 })
              }
              if (this.loading && this.items.length === 0) {
                Text('加载中…')
                  .fontFamily(this.appFontFamily('加载中…'))
                  .fontWeight(this.appFontWeight())
                  .fontSize(14)
                  .fontColor(HwColor.textSecondary)
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding({ top: 32, bottom: 32 })
              }
              if (!this.loading && this.errorMessage.length === 0 && this.items.length === 0) {
                Column({ space: 8 }) {
                  SymbolGlyph($r('sys.symbol.leaf'))
                    .fontSize(30)
                    .fontColor([HwColor.textSecondary])
                  Text('暂无耗材信息')
                    .fontFamily(this.appFontFamily('暂无耗材信息'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(15)
                    .fontColor(HwColor.textPrimary)
                  Text('支持耗材上报的设备会显示在这里')
                    .fontFamily(this.appFontFamily('支持耗材上报的设备会显示在这里'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(12)
                    .fontColor(HwColor.textSecondary)
                }
                .width('100%')
                .padding({ top: 48, bottom: 48 })
              }
              ForEach(this.items, (item: MijiaConsumableItem) => {
                this.consumableCard(item)
              }, (item: MijiaConsumableItem) => item.did)
            }
            .width('100%')
            .constraintSize({
              maxWidth: this.isWideScreen ? 1080 : '100%'
            })
            .padding({ left: HwSpace.lg, right: HwSpace.lg, top: HwSpace.lg, bottom: HwSpace.xl })
          }
          .width('100%')
        }
        .width('100%')
        .height('100%')
        .align(this.cardsFromTop ? Alignment.Top : Alignment.Center)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        }
        .width('100%')
        .height('100%')
        .onRefreshing(() => {
          this.handleRefresh();
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)

      Row() {
        IconCircleButton({
          symbol: $r('sys.symbol.chevron_left'),
          buttonSize: 40,
          iconSize: 20,
          onAction: (): void => {
            router.back();
          }
        })
        Text('耗材中心')
          .fontFamily(this.appFontFamily('耗材中心'))
          .fontWeight(this.appFontWeight())
          .margin({ left: HwSpace.md })
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(HwColor.textPrimary)
        Blank()
        IconCircleButton({
          symbol: $r('sys.symbol.arrow_counterclockwise'),
          buttonSize: 40,
          iconSize: 20,
          buttonEnabled: !this.refreshing,
          spinning: this.refreshing,
          onAction: (): void => {
            this.handleRefresh();
          }
        })
      }
      .width('100%')
      .height(56 + this.statusBarHeight)
      .padding({ left: 16, right: 16, top: this.statusBarHeight })
      .backgroundColor('#59FFFFFF')
      .backgroundEffect({ radius: 30, saturation: 1.5, color: '#80FFFFFF' })
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
