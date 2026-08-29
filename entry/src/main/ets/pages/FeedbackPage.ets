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

import { HwColor, HwRadius, HwSpace, MijiaOverviewCard, MijiaOverviewCardText, MijiaOverviewCardValue, MijiaSheetBackground } from '../utils/DesignTokens';
import { IconCircleButton } from '../components/IconCircleButton';
import { AppBackground } from '../components/AppBackground';
import { FeedbackLogService } from '../services/FeedbackLogService';

@Entry
@Component
struct FeedbackPage {
  @StorageLink('fontMode') fontMode: string = 'system';
  @StorageLink('fontFamilyEn') fontFamilyEn: string = 'system';
  @StorageLink('fontFamilyZh') fontFamilyZh: string = 'system';
  @StorageLink('fontWeightMode') fontWeightMode: string = 'system';
  @StorageLink('fontWeightValue') fontWeightValue: number = 400;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('isDarkMode') isDarkMode: boolean = false;
  @StorageProp('navigationBarHeight') navigationBarHeight: number = 0;

  @State logEnabled: boolean = false;
  @State recordCount: number = 0;
  @State generatedPath: string = '';
  @State generating: boolean = false;
  @State showTutorialSheet: boolean = false;

  aboutToAppear(): void {
    FeedbackLogService.setCurrentPage('反馈页');
    this.refreshState();
  }

  onPageShow(): void {
    this.refreshState();
  }

  refreshState(): void {
    this.logEnabled = FeedbackLogService.isEnabled();
    this.recordCount = FeedbackLogService.getRecordCount();
  }

  enableLogMode(): void {
    FeedbackLogService.enable();
    this.refreshState();
    this.showToast('完整日志模式已开启');
  }

  disableLogMode(): void {
    FeedbackLogService.disable();
    this.generatedPath = '';
    this.refreshState();
    this.showToast('完整日志模式已关闭');
  }

  async generateLogFile(): Promise<void> {
    if (this.generating) {
      return;
    }
    this.generating = true;
    this.generatedPath = '';
    try {
      const uri = await FeedbackLogService.saveLogFileWithPicker();
      if (uri.length > 0) {
        this.generatedPath = uri;
        this.showToast('日志文件已生成');
      } else {
        this.showToast('未保存日志文件');
      }
    } finally {
      this.generating = false;
      this.refreshState();
    }
  }

  goBack(): void {
    this.getUIContext().getRouter().back();
  }

  showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (err) {
    }
  }

  appFontFamily(content: string): string {
    if (this.fontMode !== 'custom') {
      return '';
    }
    const family = this.hasCjk(content) ? this.fontFamilyZh : this.fontFamilyEn;
    return family === 'system' || family.length === 0 ? '' : family;
  }

  hasCjk(content: string): boolean {
    for (let i = 0; i < content.length; i++) {
      const code = content.charCodeAt(i);
      if (code >= 0x4E00 && code <= 0x9FFF) {
        return true;
      }
    }
    return false;
  }

  appFontWeight(): number {
    return this.fontWeightMode === 'custom' ? this.fontWeightValue : 400;
  }

  @Builder
  modeStatusCard() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.record_circle'))
          .fontSize(20)
          .fontColor([MijiaOverviewCardValue])
        Text('完整日志模式已开启')
          .fontFamily(this.appFontFamily('完整日志模式已开启'))
          .fontWeight(this.appFontWeight())
          .fontSize(15)
          .fontColor(Color.White)
          .layoutWeight(1)
        Text(`${this.recordCount} 条`)
          .fontFamily(this.appFontFamily(`${this.recordCount} 条`))
          .fontWeight(this.appFontWeight())
          .fontSize(13)
          .fontColor(MijiaOverviewCardText)
      }
      .width('100%')

      Text('正在为所有操作收集完整日志，回到本页点击“生成日志文件”即可结束收集并导出。')
        .fontFamily(this.appFontFamily('正在为所有操作收集完整日志，回到本页点击“生成日志文件”即可结束收集并导出。'))
        .fontWeight(this.appFontWeight())
        .fontSize(13)
        .fontColor(MijiaOverviewCardText)
        .lineHeight(20)
        .width('100%')

      Button('关闭完整日志模式')
        .width('100%')
        .height(44)
        .fontFamily(this.appFontFamily('关闭完整日志模式'))
        .fontWeight(this.appFontWeight())
        .fontSize(15)
        .fontColor(HwColor.textPrimary)
        .backgroundColor('#14000000')
        .borderRadius(HwRadius.control)
        .onClick(() => {
          this.disableLogMode();
        })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  tutorialSheet() {
    Column({ space: 18 }) {
      Text('反馈教程')
        .fontFamily(this.appFontFamily('反馈教程'))
        .fontWeight(this.appFontWeight())
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(HwColor.textPrimary)

      Divider()
        .color('#14000000')

      Row({ space: 12 }) {
        Text('第一步')
          .fontFamily(this.appFontFamily('第一步'))
          .fontWeight(this.appFontWeight())
          .fontSize(13)
          .fontColor(Color.White)
          .backgroundColor(HwColor.primary)
          .borderRadius(8)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        Text('打开完整日志模式')
          .fontFamily(this.appFontFamily('打开完整日志模式'))
          .fontWeight(this.appFontWeight())
          .fontSize(15)
          .fontColor(HwColor.textPrimary)
          .layoutWeight(1)
          .wordBreak(WordBreak.BREAK_WORD)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 12 }) {
        Text('第二步')
          .fontFamily(this.appFontFamily('第二步'))
          .fontWeight(this.appFontWeight())
          .fontSize(13)
          .fontColor(Color.White)
          .backgroundColor(HwColor.primary)
          .borderRadius(8)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        Text('重新打开出现问题的地方')
          .fontFamily(this.appFontFamily('重新打开出现问题的地方'))
          .fontWeight(this.appFontWeight())
          .fontSize(15)
          .fontColor(HwColor.textPrimary)
          .layoutWeight(1)
          .wordBreak(WordBreak.BREAK_WORD)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 12 }) {
        Text('第三步')
          .fontFamily(this.appFontFamily('第三步'))
          .fontWeight(this.appFontWeight())
          .fontSize(13)
          .fontColor(Color.White)
          .backgroundColor(HwColor.primary)
          .borderRadius(8)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        Text('将生成的日志文件和出问题的截图发给作者')
          .fontFamily(this.appFontFamily('将生成的日志文件和出问题的截图发给作者'))
          .fontWeight(this.appFontWeight())
          .fontSize(15)
          .fontColor(HwColor.textPrimary)
          .lineHeight(22)
          .layoutWeight(1)
          .wordBreak(WordBreak.BREAK_WORD)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: HwSpace.xl, right: HwSpace.xl, top: 20, bottom: 28 })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      AppBackground()
      Column() {

        Scroll() {
          Column({ space: 16 }) {
            Blank().height(40 + this.statusBarHeight)
            Column({ space: 12 }) {
              if (this.logEnabled) {
                this.modeStatusCard()
              } else {
                Column({ space: 12 }) {
                  Text('完整日志模式')
                    .fontFamily(this.appFontFamily('完整日志模式'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(15)
                    .fontColor(Color.White)
                    .width('100%')
                  Text('开启后，应用将为所有操作收集完整日志；回到本页点击“生成日志文件”即可结束收集并导出。')
                    .fontFamily(this.appFontFamily('开启后，应用将为所有操作收集完整日志；回到本页点击“生成日志文件”即可结束收集并导出。'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(13)
                    .fontColor(MijiaOverviewCardText)
                    .lineHeight(20)
                    .width('100%')
                  Button('开启完整日志模式')
                    .width('100%')
                    .height(44)
                    .fontFamily(this.appFontFamily('开启完整日志模式'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(15)
                    .fontColor(Color.White)
                    .backgroundColor(HwColor.primary)
                    .borderRadius(HwRadius.control)
                    .onClick(() => {
                      this.enableLogMode();
                    })
                }
                .alignItems(HorizontalAlign.Start)
                .width('100%')
              }
            }
            .width('100%')
            .padding(HwSpace.lg)
            .borderRadius(HwRadius.card)
            .backgroundColor(MijiaOverviewCard)
            .border({ width: 1, color: '#24FFFFFF' })
            .clip(true)

            Column({ space: 12 }) {
              Row({ space: 10 }) {
                SymbolGlyph($r('sys.symbol.doc_text'))
                  .fontSize(20)
                  .fontColor([Color.White])
                Text('生成日志文件')
                  .fontFamily(this.appFontFamily('生成日志文件'))
                  .fontWeight(this.appFontWeight())
                  .fontSize(15)
                  .fontColor(Color.White)
                  .layoutWeight(1)
              }
              .width('100%')

              Text(this.logEnabled ? '点击后弹出系统保存窗口，选择保存位置生成日志文件，并关闭完整日志模式。' : '请先开启完整日志模式，收集操作日志后再生成日志文件。')
                .fontFamily(this.appFontFamily(this.logEnabled ? '点击后弹出系统保存窗口，选择保存位置生成日志文件，并关闭完整日志模式。' : '请先开启完整日志模式，收集操作日志后再生成日志文件。'))
                .fontWeight(this.appFontWeight())
                .fontSize(13)
                .fontColor(MijiaOverviewCardText)
                .lineHeight(20)
                .width('100%')

              Button('生成日志文件')
                .width('100%')
                .height(44)
                .fontFamily(this.appFontFamily('生成日志文件'))
                .fontWeight(this.appFontWeight())
                .fontSize(15)
                .fontColor(Color.White)
                .backgroundColor(this.logEnabled && !this.generating ? HwColor.primary : '#C5CBD3')
                .enabled(this.logEnabled && !this.generating)
                .borderRadius(HwRadius.control)
                .onClick(() => {
                  this.generateLogFile();
                })

              if (this.generatedPath.length > 0) {
                Divider()
                  .color('#14000000')
                Text(this.generatedPath)
                  .fontFamily(this.appFontFamily(this.generatedPath))
                  .fontWeight(this.appFontWeight())
                  .fontSize(12)
                  .fontColor(MijiaOverviewCardText)
                  .lineHeight(18)
                  .width('100%')
                  .copyOption(CopyOptions.LocalDevice)
                Text('日志文件已保存到你选择的位置。')
                  .fontFamily(this.appFontFamily('日志文件已保存到你选择的位置。'))
                  .fontWeight(this.appFontWeight())
                  .fontSize(12)
                  .fontColor(MijiaOverviewCardText)
                  .lineHeight(18)
                  .width('100%')
              }
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding(HwSpace.lg)
            .borderRadius(HwRadius.card)
            .backgroundColor(MijiaOverviewCard)
            .border({ width: 1, color: '#24FFFFFF' })
            .clip(true)

            Row({ space: 10 }) {
              SymbolGlyph($r('sys.symbol.book'))
                .fontSize(20)
                .fontColor([Color.White])
              Text('反馈教程')
                .fontFamily(this.appFontFamily('反馈教程'))
                .fontWeight(this.appFontWeight())
                .fontSize(15)
                .fontColor(Color.White)
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
            .onClick(() => {
              this.showTutorialSheet = true;
            })
          }
          .width('100%')
          .padding({ left: HwSpace.lg, right: HwSpace.lg, top: HwSpace.md, bottom: this.navigationBarHeight + 24 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
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
            this.goBack();
          }
        })
        Text('反馈')
          .fontFamily(this.appFontFamily('反馈'))
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
    .bindSheet($$this.showTutorialSheet, this.tutorialSheet(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
            backgroundColor: MijiaSheetBackground,
      showClose: true,
      
    })
    .keyboardShortcut(FunctionKey.ESC, [], () => {
      this.getUIContext().getRouter().back();
    })
  }
}
