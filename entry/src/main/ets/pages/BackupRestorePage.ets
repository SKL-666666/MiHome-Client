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

import { common } from '@kit.AbilityKit';
import { HwColor, HwRadius, HwSpace, MijiaOverviewCard, MijiaOverviewCardText } from '../utils/DesignTokens';
import { IconCircleButton } from '../components/IconCircleButton';
import { AppBackground } from '../components/AppBackground';
import { FeedbackLogService } from '../services/FeedbackLogService';
import { BackupRestoreService, BackupRestorePackage } from '../services/BackupRestoreService';

@Entry
@Component
struct BackupRestorePage {
  @StorageLink('immersiveLightEnabled') immersiveLightEnabled: boolean = true;
  @StorageLink('fontMode') fontMode: string = 'system';
  @StorageLink('fontFamilyEn') fontFamilyEn: string = 'system';
  @StorageLink('fontFamilyZh') fontFamilyZh: string = 'system';
  @StorageLink('fontWeightMode') fontWeightMode: string = 'system';
  @StorageLink('fontWeightValue') fontWeightValue: number = 400;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('isDarkMode') isDarkMode: boolean = false;
  @StorageLink('cardsFromTop') cardsFromTop: boolean = true;
  @State message: string = '';
  @State busy: boolean = false;

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

  aboutToAppear(): void {
    FeedbackLogService.setCurrentPage('备份与恢复页');
  }

  private exportConfig(): void {
    if (this.busy) {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: '导出自定义资源',
      message: '是否同时导出自定义背景和上传的字体？',
      buttons: [
        {
          value: '取消',
          action: () => {
          }
        },
        {
          value: '否',
          action: () => {
            this.doExport(false);
          }
        },
        {
          value: '是',
          action: () => {
            this.doExport(true);
          }
        }
      ]
    });
  }

  private async doExport(includeAssets: boolean): Promise<void> {
    if (this.busy) {
      return;
    }
    const context = getContext(this) as common.UIAbilityContext;
    this.busy = true;
    this.message = '';
    try {
      const uri = await BackupRestoreService.exportBackup(context, includeAssets);
      if (uri.length > 0) {
        this.message = includeAssets ? '已导出配置、背景与字体' : '配置文件已导出';
      } else {
        this.message = '已取消导出';
      }
    } catch (err) {
      this.message = '导出失败，请重试';
      FeedbackLogService.recordError('BACKUP', '导出配置文件失败');
    } finally {
      this.busy = false;
    }
  }

  private async restoreConfig(): Promise<void> {
    if (this.busy) {
      return;
    }
    const context = getContext(this) as common.UIAbilityContext;
    this.busy = true;
    this.message = '';
    try {
      const pkg = await BackupRestoreService.pickBackupFile(context);
      if (pkg === null) {
        this.message = '已取消恢复或配置文件无效';
        return;
      }
      const current = await BackupRestoreService.collectCurrentDeviceInfo(context);
      const matched = BackupRestoreService.deviceInfoMatches(pkg.content.deviceInfo, current);
      if (matched) {
        this.applyRestoreAndRestart(context, pkg);
      } else {
        const backupCount = pkg.content.deviceInfo.devices.length;
        const currentCount = current.devices.length;
        this.getUIContext().showAlertDialog({
          title: '设备信息不一致',
          message: `备份文件中的设备信息与当前设备不符（备份 ${backupCount} 台，当前 ${currentCount} 台）。` +
            '确定仍要恢复设置吗？确认后将恢复备份中的设置并重启应用。',
          primaryButton: {
            value: '取消',
            action: () => {
              this.message = '已取消恢复';
            }
          },
          secondaryButton: {
            value: '确定恢复',
            fontColor: HwColor.danger,
            action: () => {
              this.applyRestoreAndRestart(context, pkg);
            }
          }
        });
      }
    } catch (err) {
      this.message = '恢复失败，请重试';
      FeedbackLogService.recordError('BACKUP', '恢复配置文件失败');
    } finally {
      this.busy = false;
    }
  }

  private applyRestoreAndRestart(context: common.UIAbilityContext, pkg: BackupRestorePackage): void {
    const ok = BackupRestoreService.applyRestore(context, pkg);
    if (!ok) {
      this.message = '恢复失败，请重试';
      FeedbackLogService.recordError('BACKUP', '恢复配置文件失败');
    }
  }

  private messageColor(): ResourceColor {
    if (this.message.indexOf('失败') >= 0) {
      return HwColor.danger;
    }
    return HwColor.primary;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      AppBackground()
      Column() {
        Scroll() {
          Column({ space: 0 }) {
            Blank().height(56 + this.statusBarHeight)
            Column({ space: 12 }) {
              Text('将当前所有设置与设备信息导出到本地文件，或从备份文件恢复设置。恢复设置后应用会自动重启。')
                .fontFamily(this.appFontFamily('将当前所有设置与设备信息导出到本地文件，或从备份文件恢复设置。恢复设置后应用会自动重启。'))
                .fontWeight(this.appFontWeight())
                .fontSize(13)
                .fontColor(HwColor.textSecondary)
                .width('100%')

              Row({ space: 12 }) {
                Column({ space: 4 }) {
                  Text('导出配置文件')
                    .fontFamily(this.appFontFamily('导出配置文件'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(15)
                    .fontColor(Color.White)
                  Text('将设置打包为压缩包导出，可选择包含背景与字体')
                    .fontFamily(this.appFontFamily('将设置打包为压缩包导出，可选择包含背景与字体'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(12)
                    .fontColor(MijiaOverviewCardText)
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
              .onClick(() => {
                this.exportConfig();
              })

              Row({ space: 12 }) {
                Column({ space: 4 }) {
                  Text('恢复配置文件')
                    .fontFamily(this.appFontFamily('恢复配置文件'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(15)
                    .fontColor(Color.White)
                  Text('从压缩包或配置文件恢复设置与资源，设备信息不符时会提示确认')
                    .fontFamily(this.appFontFamily('从压缩包或配置文件恢复设置与资源，设备信息不符时会提示确认'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(12)
                    .fontColor(MijiaOverviewCardText)
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
              .onClick(() => {
                this.restoreConfig();
              })

              if (this.busy) {
                Text('正在处理，请稍候…')
                  .fontFamily(this.appFontFamily('正在处理，请稍候…'))
                  .fontWeight(this.appFontWeight())
                  .fontSize(13)
                  .fontColor(HwColor.textSecondary)
                  .width('100%')
                  .padding(HwSpace.md)
              }

              if (this.message.length > 0) {
                Text(this.message)
                  .fontFamily(this.appFontFamily(this.message))
                  .fontWeight(this.appFontWeight())
                  .fontSize(13)
                  .fontColor(this.messageColor())
                  .width('100%')
                  .padding({ left: 4, right: 4 })
              }
            }
            .width('100%')
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
      .backgroundColor(Color.Transparent)

      Row() {
        IconCircleButton({
          symbol: $r('sys.symbol.chevron_left'),
          buttonSize: 40,
          iconSize: 20,
          onAction: () => {
            this.getUIContext().getRouter().back();
          }
        })
        Text('备份与恢复')
          .fontFamily(this.appFontFamily('备份与恢复'))
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
    .backgroundColor(this.isDarkMode ? HwColor.backgroundDark : HwColor.background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .keyboardShortcut(FunctionKey.ESC, [], () => {
      this.getUIContext().getRouter().back();
    })
  }
}
