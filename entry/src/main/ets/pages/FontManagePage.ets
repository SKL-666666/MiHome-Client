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
import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { text } from '@kit.ArkGraphics2D';
import { HwColor, HwRadius, HwSpace, MijiaOverviewCard, MijiaOverviewCardText, MijiaOverviewCardValue, MijiaSheetBackground } from '../utils/DesignTokens';
import { IconCircleButton } from '../components/IconCircleButton';
import { AppBackground } from '../components/AppBackground';
import { AppSettingsStore } from '../storage/AppSettingsStore';
import { FeedbackLogService } from '../services/FeedbackLogService';

@Entry
@Component
struct FontManagePage {
  @StorageLink('immersiveLightEnabled') immersiveLightEnabled: boolean = true;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('isDarkMode') isDarkMode: boolean = false;
  @StorageLink('customFonts') customFonts: string[] = [];
  @StorageLink('fontMode') fontMode: string = 'system';
  @StorageLink('fontFamilyEn') fontFamilyEn: string = 'system';
  @StorageLink('fontFamilyZh') fontFamilyZh: string = 'system';
  @StorageLink('fontWeightMode') fontWeightMode: string = 'system';
  @StorageLink('fontWeightValue') fontWeightValue: number = 400;
  @State message: string = '';
  @State renameError: string = '';
  @State renameIndex: number = -1;
  @State renameDraft: string = '';
  @State showRenameSheet: boolean = false;

  private fontDir(): string {
    const context = getContext(this) as common.UIAbilityContext;
    return `${context.filesDir}/custom_fonts`;
  }

  private aliasOf(fileName: string): string {
    const lower = fileName.toLowerCase();
    const ext = lower.endsWith('.ttf') ? '.ttf' : '.otf';
    return fileName.substring(0, fileName.length - ext.length);
  }

  private appFontWeight(): number {
    return this.fontWeightMode === 'custom' ? this.fontWeightValue : 400;
  }

  private appFontFamily(content: string): string {
    if (this.fontMode !== 'custom') {
      return '';
    }
    const family = this.hasCjk(content) ? this.fontFamilyZh : this.fontFamilyEn;
    return family === 'system' || family.length === 0 ? '' : family;
  }

  aboutToAppear(): void {
    FeedbackLogService.setCurrentPage('字体管理页');
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

  startRename(index: number): void {
    this.renameIndex = index;
    this.renameDraft = this.aliasOf(this.customFonts[index]);
    this.renameError = '';
    this.showRenameSheet = true;
  }

  confirmRename(): void {
    if (this.renameIndex < 0 || this.renameIndex >= this.customFonts.length) {
      return;
    }
    const oldName = this.customFonts[this.renameIndex];
    const oldAlias = this.aliasOf(oldName);
    const oldExt = oldName.toLowerCase().endsWith('.ttf') ? '.ttf' : '.otf';
    let newName = this.renameDraft.trim();
    if (newName.length === 0) {
      this.renameError = '名称不能为空';
      return;
    }
    const lowerNew = newName.toLowerCase();
    if (!lowerNew.endsWith('.ttf') && !lowerNew.endsWith('.otf')) {
      newName = `${newName}${oldExt}`;
    }
    if (newName.includes('/') || newName.includes('\\') || newName.includes(':')) {
      this.renameError = '名称包含非法字符';
      return;
    }
    if (newName === oldName) {
      this.showRenameSheet = false;
      return;
    }
    try {
      const dir = this.fontDir();
      if (fs.accessSync(`${dir}/${newName}`)) {
        this.renameError = '已存在同名字体';
        return;
      }
      const newAlias = this.aliasOf(newName);
      try {
        text.FontCollection.getGlobalInstance().unloadFontSync(oldAlias);
      } catch (err) {
      }
      fs.renameSync(`${dir}/${oldName}`, `${dir}/${newName}`);
      try {
        text.FontCollection.getGlobalInstance().loadFontSyncWithCheck(newAlias, `file://${dir}/${newName}`);
      } catch (err) {
        try {
          fs.renameSync(`${dir}/${newName}`, `${dir}/${oldName}`);
        } catch (ignored) {
        }
        this.renameError = '重命名后字体无效，已还原';
        return;
      }
      const next: string[] = [];
      for (let i = 0; i < this.customFonts.length; i++) {
        next.push(i === this.renameIndex ? newName : this.customFonts[i]);
      }
      this.customFonts = next;
      AppSettingsStore.setStringArray('customFonts', next);
      if (this.fontFamilyEn === oldAlias) {
        this.fontFamilyEn = newAlias;
        AppSettingsStore.setString('fontFamilyEn', newAlias);
      }
      if (this.fontFamilyZh === oldAlias) {
        this.fontFamilyZh = newAlias;
        AppSettingsStore.setString('fontFamilyZh', newAlias);
      }
      this.showRenameSheet = false;
      this.message = '已重命名';
    } catch (err) {
      this.renameError = '重命名失败';
    }
  }

  confirmDelete(index: number): void {
    if (index < 0 || index >= this.customFonts.length) {
      return;
    }
    const alias = this.aliasOf(this.customFonts[index]);
    this.getUIContext().showAlertDialog({
      title: '删除字体',
      message: `确定删除「${alias}」吗？删除后无法恢复。`,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: HwColor.danger,
        action: () => {
          this.deleteFont(index);
        }
      }
    });
  }

  deleteFont(index: number): void {
    try {
      const fileName = this.customFonts[index];
      const alias = this.aliasOf(fileName);
      try {
        text.FontCollection.getGlobalInstance().unloadFontSync(alias);
      } catch (err) {
      }
      try {
        fs.unlinkSync(`${this.fontDir()}/${fileName}`);
      } catch (err) {
      }
      const next: string[] = [];
      for (let i = 0; i < this.customFonts.length; i++) {
        if (i !== index) {
          next.push(this.customFonts[i]);
        }
      }
      this.customFonts = next;
      AppSettingsStore.setStringArray('customFonts', next);
      if (this.fontFamilyEn === alias) {
        this.fontFamilyEn = 'system';
        AppSettingsStore.setString('fontFamilyEn', 'system');
      }
      if (this.fontFamilyZh === alias) {
        this.fontFamilyZh = 'system';
        AppSettingsStore.setString('fontFamilyZh', 'system');
      }
      this.message = '已删除';
    } catch (err) {
      this.message = '删除失败';
    }
  }

  @Builder
  renameSheet() {
    Column({ space: 16 }) {
      Column({ space: 6 }) {
        Text('重命名字体')
          .fontFamily(this.appFontFamily('重命名字体'))
          .fontWeight(this.appFontWeight())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(HwColor.textPrimary)
        Text('输入新名称，扩展名将自动保持 .ttf / .otf')
          .fontFamily(this.appFontFamily('输入新名称，扩展名将自动保持 .ttf / .otf'))
          .fontWeight(this.appFontWeight())
          .fontSize(12)
          .fontColor(HwColor.textSecondary)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      TextInput({ placeholder: '输入新字体名', text: this.renameDraft })
        .width('100%')
        .height(44)
        .fontSize(15)
        .fontColor(HwColor.textPrimary)
        .placeholderColor(HwColor.textSecondary)
        .backgroundColor(MijiaOverviewCard)
        .border({ width: 1, color: '#24FFFFFF' })
        .borderRadius(HwRadius.control)
        .padding({ left: HwSpace.md, right: HwSpace.md })
        .clip(true)
        .onChange((value: string) => {
          this.renameDraft = value;
        })

      if (this.renameError.length > 0) {
        Text(this.renameError)
          .fontFamily(this.appFontFamily(this.renameError))
          .fontWeight(this.appFontWeight())
          .fontSize(13)
          .fontColor(HwColor.danger)
          .width('100%')
      }

      Row({ space: 12 }) {
        Button('取消', { type: ButtonType.Capsule, stateEffect: true })
          .layoutWeight(1)
          .height(44)
          .fontSize(15)
          .fontColor(MijiaOverviewCardText)
          .backgroundColor(MijiaOverviewCard)
          .border({ width: 1, color: '#24FFFFFF' })
          .onClick(() => {
            this.showRenameSheet = false;
          })
        Button('确定', { type: ButtonType.Capsule, stateEffect: true })
          .layoutWeight(1)
          .height(44)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(MijiaOverviewCardValue)
          .backgroundColor(MijiaOverviewCard)
          .border({ width: 1, color: '#24FFFFFF' })
          .enabled(this.renameDraft.trim().length > 0)
          .opacity(this.renameDraft.trim().length > 0 ? 1 : 0.4)
          .onClick(() => {
            this.confirmRename();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: HwSpace.lg, right: HwSpace.lg, top: 16, bottom: 24 })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      AppBackground()
      Column() {
        Scroll() {
          Column({ space: 0 }) {
            Blank().height(56 + this.statusBarHeight)
            Column({ space: 12 }) {
              if (this.message.length > 0) {
                Text(this.message)
                  .fontFamily(this.appFontFamily(this.message))
                  .fontWeight(this.appFontWeight())
                  .fontSize(13)
                  .fontColor(HwColor.primary)
                  .width('100%')
                  .padding({ left: 4, right: 4 })
              }
              if (this.customFonts.length === 0) {
                Text('暂无上传的字体')
                  .fontFamily(this.appFontFamily('暂无上传的字体'))
                  .fontWeight(this.appFontWeight())
                  .fontSize(14)
                  .fontColor(HwColor.textSecondary)
                  .width('100%')
                  .padding({ top: HwSpace.xl, bottom: HwSpace.xl })
                  .textAlign(TextAlign.Center)
              }
              ForEach(this.customFonts, (fileName: string, index: number) => {
                Row({ space: 12 }) {
                  Column({ space: 2 }) {
                    Text(this.aliasOf(fileName))
                      .fontFamily(this.appFontFamily(this.aliasOf(fileName)))
                      .fontWeight(this.appFontWeight())
                      .fontSize(15)
                      .fontColor(Color.White)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(fileName)
                      .fontFamily(this.appFontFamily(fileName))
                      .fontWeight(this.appFontWeight())
                      .fontSize(12)
                      .fontColor(MijiaOverviewCardText)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  Button('改名', { type: ButtonType.Capsule, stateEffect: true })
                    .height(32)
                    .fontSize(13)
                    .fontColor(Color.White)
                    .backgroundColor(MijiaOverviewCard)
                    .border({ width: 1, color: '#24FFFFFF' })
                    .onClick(() => {
                      this.startRename(index);
                    })
                  Button('删除', { type: ButtonType.Capsule, stateEffect: true })
                    .height(32)
                    .fontSize(13)
                    .fontColor(HwColor.danger)
                    .backgroundColor(MijiaOverviewCard)
                    .border({ width: 1, color: '#24FFFFFF' })
                    .onClick(() => {
                      this.confirmDelete(index);
                    })
                }
                .width('100%')
                .padding(HwSpace.lg)
                .borderRadius(HwRadius.card)
                .backgroundColor(MijiaOverviewCard)
                .border({ width: 1, color: '#24FFFFFF' })
                .clip(true)
              }, (fileName: string, index: number) => `${index}_${fileName}`)
            }
            .width('100%')
            .padding({ left: HwSpace.lg, right: HwSpace.lg, top: HwSpace.lg, bottom: HwSpace.xl })
          }
          .width('100%')
        }
        .width('100%')
        .height('100%')
        .align(Alignment.TopStart)
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
          tint: '#FFFFFF',
          onAction: () => {
            router.back();
          }
        })
        Text('管理字体')
          .fontFamily(this.appFontFamily('管理字体'))
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
    .bindSheet($$this.showRenameSheet, this.renameSheet(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
            backgroundColor: MijiaSheetBackground,
      showClose: false,
      onDisappear: () => {
        this.renameIndex = -1;
      }
    })
    .keyboardShortcut(FunctionKey.ESC, [], () => {
      router.back();
    })
  }
}
