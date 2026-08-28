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

import { router, uiAppearance } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { text } from '@kit.ArkGraphics2D';
import { HwColor, HwRadius, HwSpace, MijiaOverviewCard, MijiaOverviewCardText, MijiaOverviewCardValue, applyAppTheme } from '../utils/DesignTokens';
import { loadCustomFonts } from '../utils/CustomFonts';
import { IconCircleButton } from '../components/IconCircleButton';
import { AppBackground } from '../components/AppBackground';
import { AppSettingsStore } from '../storage/AppSettingsStore';
import { FeedbackLogService } from '../services/FeedbackLogService';

@Entry
@Component
struct AppearanceSettingsPage {
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
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('isDarkMode') isDarkMode: boolean = false;
  @StorageLink('backgroundImage') wallpaperImage: string = '';
  @StorageLink('autoMultiColumn') autoMultiColumn: boolean = false;
  @StorageLink('fontMode') fontMode: string = 'system';
  @StorageLink('fontFamilyEn') fontFamilyEn: string = 'system';
  @StorageLink('fontFamilyZh') fontFamilyZh: string = 'system';
  @StorageLink('fontSizeMode') fontSizeMode: string = 'system';
  @StorageLink('fontSizeValue') fontSizeValue: number = 16;
  @StorageLink('fontWeightMode') fontWeightMode: string = 'system';
  @StorageLink('fontWeightValue') fontWeightValue: number = 400;
  @StorageLink('cardsFromTop') cardsFromTop: boolean = true;
  @StorageLink('customFonts') customFonts: string[] = [];
  @State backgroundMessage: string = '';
  @State fontMessage: string = '';
  @State availableFonts: string[] = [];

  aboutToAppear(): void {
    FeedbackLogService.setCurrentPage('外观设置页');
    this.loadCustomFonts();
    this.refreshAvailableFonts();
    this.applyFontSizeScale();
  }

  onPageShow(): void {
    this.refreshAvailableFonts();
  }

  private fontDir(): string {
    const context = getContext(this) as common.UIAbilityContext;
    return `${context.filesDir}/custom_fonts`;
  }

  loadCustomFonts(): void {
    const context = getContext(this) as common.UIAbilityContext;
    loadCustomFonts(context.filesDir, this.customFonts);
  }

  async refreshAvailableFonts(): Promise<void> {
    const names: string[] = [];
    for (let i = 0; i < this.customFonts.length; i++) {
      const fileName = this.customFonts[i];
      const alias = fileName.substring(0, fileName.length - 4);
      if (names.indexOf(alias) < 0) {
        names.push(alias);
      }
    }
    try {
      const systemFonts = await text.getSystemFontFullNamesByType(text.SystemFontType.ALL);
      for (let i = 0; i < systemFonts.length; i++) {
        const family = systemFonts[i];
        if (names.indexOf(family) < 0) {
          names.push(family);
        }
      }
    } catch (err) {
    }
    this.availableFonts = names;
  }

  async pickBackgroundImage(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const imagePicker = new photoAccessHelper.PhotoViewPicker();
      const result = await imagePicker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      });
      if (result.photoUris.length === 0) {
        return;
      }
      const sourceUri = result.photoUris[0];
      const tempPath = `${context.filesDir}/background_source`;
      let cropUri = sourceUri;
      try {
        try {
          fs.unlinkSync(tempPath);
        } catch (ignored) {
        }
        await fs.copyFile(sourceUri, tempPath);
        cropUri = `file://${tempPath}`;
      } catch (copyErr) {
        // Keep the picker URI when the sandbox copy is unavailable.
      }
      router.pushUrl({
        url: 'pages/BackgroundCropPage',
        params: { sourceUri: cropUri }
      });
    } catch (err) {
      this.backgroundMessage = '选择图片失败';
    }
  }

  clearBackground(): void {
    this.wallpaperImage = '';
    AppSettingsStore.delete('backgroundImage');
    this.backgroundMessage = '背景已清空';
  }

  showClearBackgroundDialog(): void {
    this.getUIContext().showAlertDialog({
      title: '清空背景',
      message: '确定要清空当前自定义背景吗？清空后无法恢复。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '清空',
        fontColor: HwColor.danger,
        action: () => {
          this.clearBackground();
        }
      }
    });
  }

  async uploadFont(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const documentPicker = new picker.DocumentViewPicker(context);
      const result = await documentPicker.select({
        maxSelectNumber: 1,
        fileSuffixFilters: ['.ttf', '.otf']
      });
      if (result.length === 0) {
        return;
      }
      const sourceUri = result[0];
      let srcFile: fs.File | undefined = undefined;
      let fileName = '';
      try {
        srcFile = fs.openSync(sourceUri, fs.OpenMode.READ_ONLY);
        fileName = srcFile.name;
      } catch (openErr) {
        this.fontMessage = '无法读取所选字体文件';
        return;
      }
      if (fileName.length === 0) {
        try {
          const rawName = sourceUri.split('/').pop() ?? '';
          fileName = decodeURIComponent(rawName);
        } catch (nameErr) {
          this.fontMessage = '无法识别字体文件名';
          return;
        }
      }
      if (srcFile === undefined) {
        this.fontMessage = '无法读取所选字体文件';
        return;
      }
      const lowerName = fileName.toLowerCase();
      if (!lowerName.endsWith('.ttf') && !lowerName.endsWith('.otf')) {
        fs.closeSync(srcFile);
        this.fontMessage = '仅支持 ttf / otf 字体文件';
        return;
      }
      const dir = this.fontDir();
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir);
      }
      const ext = lowerName.endsWith('.ttf') ? '.ttf' : '.otf';
      const base = fileName.substring(0, fileName.length - 4);
      let targetName = fileName;
      let index = 1;
      while (fs.accessSync(`${dir}/${targetName}`)) {
        targetName = `${base}_${index}${ext}`;
        index++;
      }
      const targetPath = `${dir}/${targetName}`;
      const dstFile = fs.openSync(targetPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      try {
        const buffer = new ArrayBuffer(1024 * 1024);
        while (true) {
          const readLen = fs.readSync(srcFile.fd, buffer);
          if (readLen <= 0) {
            break;
          }
          fs.writeSync(dstFile.fd, buffer, { length: readLen });
        }
      } finally {
        fs.closeSync(dstFile);
        fs.closeSync(srcFile);
      }
      const alias = targetName.substring(0, targetName.length - 4);
      try {
        text.FontCollection.getGlobalInstance().loadFontSyncWithCheck(alias, `file://${targetPath}`);
      } catch (verifyErr) {
        try {
          fs.unlinkSync(targetPath);
        } catch (ignored) {
        }
        this.fontMessage = '字体文件无效，请上传有效的 ttf / otf 文件';
        return;
      }
      const nextFonts: string[] = this.customFonts.slice();
      nextFonts.push(targetName);
      this.customFonts = nextFonts;
      AppSettingsStore.setStringArray('customFonts', nextFonts);
      this.refreshAvailableFonts();
      this.fontMessage = '字体上传成功';
    } catch (err) {
      this.fontMessage = '上传字体失败';
    }
  }

  setFontMode(mode: string): void {
    this.fontMode = mode;
    AppSettingsStore.setString('fontMode', mode);
  }

  setFontFamily(isEnglish: boolean, family: string): void {
    if (isEnglish) {
      this.fontFamilyEn = family;
      AppSettingsStore.setString('fontFamilyEn', family);
    } else {
      this.fontFamilyZh = family;
      AppSettingsStore.setString('fontFamilyZh', family);
    }
  }

  setFontSizeMode(mode: string): void {
    this.fontSizeMode = mode;
    AppSettingsStore.setString('fontSizeMode', mode);
    this.applyFontSizeScale();
  }

  setFontWeightMode(mode: string): void {
    this.fontWeightMode = mode;
    AppSettingsStore.setString('fontWeightMode', mode);
  }

  onFontSizeChange(value: number): void {
    const rounded = Math.round(value);
    this.fontSizeValue = rounded;
    AppSettingsStore.setNumber('fontSizeValue', rounded);
    this.applyFontSizeScale();
  }

  onFontWeightChange(value: number): void {
    const weight = Math.round(value / 100) * 100;
    this.fontWeightValue = weight;
    AppSettingsStore.setNumber('fontWeightValue', weight);
  }

  private applyFontSizeScale(): void {
    try {
      const appContext = (getContext(this) as common.UIAbilityContext).getApplicationContext();
      let scale: number = 1;
      if (this.fontSizeMode === 'custom') {
        scale = this.fontSizeValue / 16;
      } else {
        scale = uiAppearance.getFontScale();
      }
      appContext.setFontSizeScale(scale);
    } catch (err) {
    }
  }

  private appFontWeight(): number {
    return this.fontWeightMode === 'custom' ? this.fontWeightValue : 400;
  }

  fontModeMenu(): MenuElement[] {
    return [
      {
        value: '跟随系统',
        action: () => {
          this.setFontMode('system');
        }
      },
      {
        value: '自定义字体',
        action: () => {
          this.setFontMode('custom');
        }
      }
    ];
  }

  fontFamilyMenu(isEnglish: boolean): MenuElement[] {
    const items: MenuElement[] = [
      {
        value: '跟随系统',
        action: () => {
          this.setFontFamily(isEnglish, 'system');
        }
      }
    ];
    for (let i = 0; i < this.availableFonts.length; i++) {
      const family = this.availableFonts[i];
      items.push({
        value: family,
        action: () => {
          this.setFontFamily(isEnglish, family);
        }
      });
    }
    return items;
  }

  fontSizeModeMenu(): MenuElement[] {
    return [
      {
        value: '跟随系统',
        action: () => {
          this.setFontSizeMode('system');
        }
      },
      {
        value: '自定义',
        action: () => {
          this.setFontSizeMode('custom');
        }
      }
    ];
  }

  fontWeightModeMenu(): MenuElement[] {
    return [
      {
        value: '跟随系统',
        action: () => {
          this.setFontWeightMode('system');
        }
      },
      {
        value: '自定义',
        action: () => {
          this.setFontWeightMode('custom');
        }
      }
    ];
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      AppBackground()
      Column() {
        Scroll() {
          Column({ space: 0 }) {
            Blank().height(56 + this.statusBarHeight)
            Column({ space: 12 }) {
              if (this.backgroundMessage.length > 0) {
                Text(this.backgroundMessage)
                  .fontFamily(this.appFontFamily(this.backgroundMessage))
                  .fontWeight(this.appFontWeight())
                  .fontSize(13)
                  .fontColor(HwColor.primary)
                  .width('100%')
                  .padding({ left: 4, right: 4 })
              }
              if (this.fontMessage.length > 0) {
                Text(this.fontMessage)
                  .fontFamily(this.appFontFamily(this.fontMessage))
                  .fontWeight(this.appFontWeight())
                  .fontSize(13)
                  .fontColor(HwColor.primary)
                  .width('100%')
                  .padding({ left: 4, right: 4 })
              }

            Row({ space: 12 }) {
              Column({ space: 4 }) {
                Text('深色模式')
                  .fontFamily(this.appFontFamily('深色模式'))
                  .fontWeight(this.appFontWeight())
                  .fontSize(15)
                  .fontColor(Color.White)
                Text('开启后应用内使用深色主题，仅应用内生效，不跟随系统')
                  .fontFamily(this.appFontFamily('开启后应用内使用深色主题，仅应用内生效，不跟随系统'))
                  .fontWeight(this.appFontWeight())
                  .fontSize(12)
                  .fontColor(MijiaOverviewCardText)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.isDarkMode })
                .onChange((isOn: boolean) => {
                  applyAppTheme(isOn);
                  AppSettingsStore.setBoolean('darkModeEnabled', isOn);
                  AppStorage.setOrCreate('isDarkMode', isOn);
                  FeedbackLogService.recordOperation('SETTING', isOn ? '开启深色模式' : '关闭深色模式');
                })
            }
            .width('100%')
            .padding(HwSpace.lg)
            .borderRadius(HwRadius.card)
            .backgroundColor(MijiaOverviewCard)
            .border({ width: 1, color: '#24FFFFFF' })
            .clip(true)

            Row({ space: 12 }) {
              Column({ space: 4 }) {
                Text('所有页面卡片从顶部开始排列')
                  .fontFamily(this.appFontFamily('所有页面卡片从顶部开始排列'))
                  .fontWeight(this.appFontWeight())
                  .fontSize(15)
                  .fontColor(Color.White)
                Text('开启后首页、设备详情、信息、我的、房间等页面内容从顶部开始排列')
                  .fontFamily(this.appFontFamily('开启后首页、设备详情、信息、我的、房间等页面内容从顶部开始排列'))
                  .fontWeight(this.appFontWeight())
                  .fontSize(12)
                  .fontColor(MijiaOverviewCardText)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.cardsFromTop })
                .onChange((isOn: boolean) => {
                  this.cardsFromTop = isOn;
                  AppSettingsStore.setBoolean('cardsFromTop', isOn);
                })
            }
            .width('100%')
            .padding(HwSpace.lg)
            .borderRadius(HwRadius.card)
            .backgroundColor(MijiaOverviewCard)
            .border({ width: 1, color: '#24FFFFFF' })
            .clip(true)

            Row({ space: 12 }) {
              Column({ space: 4 }) {
                Text('更换字体')
                    .fontFamily(this.appFontFamily('更换字体'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(15)
                    .fontColor(Color.White)
                  Text(this.fontMode === 'custom' ? '自定义字体' : '跟随系统')
                    .fontFamily(this.appFontFamily(this.fontMode === 'custom' ? '自定义字体' : '跟随系统'))
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
              .bindMenu(this.fontModeMenu())

              if (this.fontMode === 'custom') {
                Row({ space: 12 }) {
                  Column({ space: 4 }) {
                    Text('英文/数字字体')
                      .fontFamily(this.appFontFamily('英文/数字字体'))
                      .fontWeight(this.appFontWeight())
                      .fontSize(15)
                      .fontColor(Color.White)
                    Text(this.fontFamilyEn === 'system' ? '跟随系统' : this.fontFamilyEn)
                      .fontFamily(this.appFontFamily(this.fontFamilyEn === 'system' ? '跟随系统' : this.fontFamilyEn))
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
                .bindMenu(this.fontFamilyMenu(true))

                Row({ space: 12 }) {
                  Column({ space: 4 }) {
                    Text('中文字体')
                      .fontFamily(this.appFontFamily('中文字体'))
                      .fontWeight(this.appFontWeight())
                      .fontSize(15)
                      .fontColor(Color.White)
                    Text(this.fontFamilyZh === 'system' ? '跟随系统' : this.fontFamilyZh)
                      .fontFamily(this.appFontFamily(this.fontFamilyZh === 'system' ? '跟随系统' : this.fontFamilyZh))
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
                .bindMenu(this.fontFamilyMenu(false))

                Row({ space: 12 }) {
                  Column({ space: 4 }) {
                    Text('上传字体')
                      .fontFamily(this.appFontFamily('上传字体'))
                      .fontWeight(this.appFontWeight())
                      .fontSize(15)
                      .fontColor(Color.White)
                    Text(`支持 ttf / otf，已上传 ${this.customFonts.length} 个`)
                      .fontFamily(this.appFontFamily(`支持 ttf / otf，已上传 ${this.customFonts.length} 个`))
                      .fontWeight(this.appFontWeight())
                      .fontSize(12)
                      .fontColor(MijiaOverviewCardText)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  SymbolGlyph($r('sys.symbol.plus'))
                    .fontSize(18)
                    .fontColor([MijiaOverviewCardValue])
                }
                .width('100%')
                .padding(HwSpace.lg)
                .borderRadius(HwRadius.card)
                .backgroundColor(MijiaOverviewCard)
                .border({ width: 1, color: '#24FFFFFF' })
                .clip(true)
                .onClick(() => {
                  this.uploadFont();
                })
              }

              if (this.customFonts.length > 0) {
                Row({ space: 12 }) {
                  Column({ space: 4 }) {
                    Text('管理字体')
                      .fontFamily(this.appFontFamily('管理字体'))
                      .fontWeight(this.appFontWeight())
                      .fontSize(15)
                      .fontColor(Color.White)
                    Text(`改名、删除已上传的 ${this.customFonts.length} 个字体`)
                      .fontFamily(this.appFontFamily(`改名、删除已上传的 ${this.customFonts.length} 个字体`))
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
                  router.pushUrl({ url: 'pages/FontManagePage' });
                })
              }

              Row({ space: 12 }) {
                Column({ space: 4 }) {
                  Text('字体大小')
                    .fontFamily(this.appFontFamily('字体大小'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(15)
                    .fontColor(Color.White)
                  Text(this.fontSizeMode === 'custom' ? `自定义(${this.fontSizeValue})` : '跟随系统')
                    .fontFamily(this.appFontFamily(this.fontSizeMode === 'custom' ? `自定义(${this.fontSizeValue})` : '跟随系统'))
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
              .bindMenu(this.fontSizeModeMenu())

              if (this.fontSizeMode === 'custom') {
                Row({ space: 12 }) {
                  Text('字体大小')
                    .fontFamily(this.appFontFamily('字体大小'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(15)
                    .fontColor(Color.White)
                  Slider({
                    value: this.fontSizeValue,
                    min: 12,
                    max: 28,
                    step: 1,
                    style: SliderStyle.OutSet
                  })
                    .layoutWeight(1)
                    .showSteps(true)
                    .onChange((value: number) => {
                      this.onFontSizeChange(value);
                    })
                  Text(`${this.fontSizeValue}`)
                    .fontFamily(this.appFontFamily(`${this.fontSizeValue}`))
                    .fontWeight(this.appFontWeight())
                    .fontSize(14)
                    .fontColor(MijiaOverviewCardText)
                }
                .width('100%')
                .padding(HwSpace.lg)
                .borderRadius(HwRadius.card)
                .backgroundColor(MijiaOverviewCard)
                .border({ width: 1, color: '#24FFFFFF' })
                .clip(true)
              }

              Row({ space: 12 }) {
                Column({ space: 4 }) {
                  Text('字体粗细')
                    .fontFamily(this.appFontFamily('字体粗细'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(15)
                    .fontColor(Color.White)
                  Text(this.fontWeightMode === 'custom' ? `自定义(${this.fontWeightValue})` : '跟随系统')
                    .fontFamily(this.appFontFamily(this.fontWeightMode === 'custom' ? `自定义(${this.fontWeightValue})` : '跟随系统'))
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
              .bindMenu(this.fontWeightModeMenu())

              if (this.fontWeightMode === 'custom') {
                Row({ space: 12 }) {
                  Text('字体粗细')
                    .fontFamily(this.appFontFamily('字体粗细'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(15)
                    .fontColor(Color.White)
                  Slider({
                    value: this.fontWeightValue,
                    min: 100,
                    max: 900,
                    step: 100,
                    style: SliderStyle.OutSet
                  })
                    .layoutWeight(1)
                    .showSteps(true)
                    .onChange((value: number) => {
                      this.onFontWeightChange(value);
                    })
                  Text(`${this.fontWeightValue}`)
                    .fontFamily(this.appFontFamily(`${this.fontWeightValue}`))
                    .fontWeight(this.appFontWeight())
                    .fontSize(14)
                    .fontColor(MijiaOverviewCardText)
                }
                .width('100%')
                .padding(HwSpace.lg)
                .borderRadius(HwRadius.card)
                .backgroundColor(MijiaOverviewCard)
                .border({ width: 1, color: '#24FFFFFF' })
                .clip(true)
              }

              Row({ space: 12 }) {
                Column({ space: 4 }) {
                  Text('更换背景')
                    .fontFamily(this.appFontFamily('更换背景'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(15)
                    .fontColor(Color.White)
                  Text(this.autoMultiColumn
                    ? '自动多栏开启时不可用'
                    : (this.wallpaperImage.length > 0 ? '已设置背景' : '未设置背景'))
                    .fontFamily(this.appFontFamily(this.autoMultiColumn
                    ? '自动多栏开启时不可用'
                    : (this.wallpaperImage.length > 0 ? '已设置背景' : '未设置背景')))
                    .fontWeight(this.appFontWeight())
                    .fontSize(12)
                    .fontColor(MijiaOverviewCardText)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                SymbolGlyph($r('sys.symbol.picture'))
                  .fontSize(18)
                  .fontColor([MijiaOverviewCardText])
              }
              .width('100%')
              .padding(HwSpace.lg)
              .borderRadius(HwRadius.card)
              .backgroundColor(MijiaOverviewCard)
              .border({ width: 1, color: '#24FFFFFF' })
              .clip(true)
              .enabled(!this.autoMultiColumn)
              .opacity(this.autoMultiColumn ? 0.4 : 1)
              .onClick(() => {
                this.pickBackgroundImage();
              })

              Row({ space: 12 }) {
                Text('清空背景')
                  .fontFamily(this.appFontFamily('清空背景'))
                  .fontWeight(this.appFontWeight())
                  .fontSize(15)
                  .fontColor(HwColor.danger)
                  .layoutWeight(1)
                SymbolGlyph($r('sys.symbol.trash'))
                  .fontSize(18)
                  .fontColor([HwColor.danger])
              }
              .width('100%')
              .padding(HwSpace.lg)
              .borderRadius(HwRadius.card)
              .backgroundColor(MijiaOverviewCard)
              .border({ width: 1, color: '#24FFFFFF' })
              .clip(true)
              .enabled(!this.autoMultiColumn)
              .opacity(this.autoMultiColumn ? 0.4 : 1)
              .onClick(() => {
                this.showClearBackgroundDialog();
              })
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
          onAction: () => {
            router.back();
          }
        })
        Text('外观设置')
          .fontFamily(this.appFontFamily('外观设置'))
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
