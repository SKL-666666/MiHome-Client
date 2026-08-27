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
import { AppSettingsStore } from '../storage/AppSettingsStore';
import { FeedbackLogService } from '../services/FeedbackLogService';

@Entry
@Component
struct SettingsPage {
  @StorageLink('immersiveLightEnabled') immersiveLightEnabled: boolean = true;
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
  @StorageProp('isLargeScreen') isLargeScreen: boolean = false;
  @StorageProp('is2in1') is2in1: boolean = false;
  @StorageLink('pcLayoutEnabled') pcLayoutEnabled: boolean = false;
  @StorageProp('currentWidthBreakpoint') @Watch('onBreakpointChange')
  widthBp: WidthBreakpoint = WidthBreakpoint.WIDTH_SM;
  @State isWideScreen: boolean = false;
  @StorageLink('hideOfflineDevices') hideOfflineDevices: boolean = false;
  @StorageLink('dualColumnMode') dualColumnMode: boolean = false;
  @StorageLink('autoMultiColumn') autoMultiColumn: boolean = false;
  @StorageLink('homeSmoothSwitch') homeSmoothSwitch: boolean = false;
  @StorageLink('temperatureFahrenheit') temperatureFahrenheit: boolean = false;
  @StorageLink('temperatureShowUnit') temperatureShowUnit: boolean = false;
  @StorageLink('backgroundImage') wallpaperImage: string = '';
  @StorageLink('infoShowMoreContent') infoShowMoreContent: boolean = true;
  @StorageLink('infoRefreshInterval') infoRefreshInterval: string = '30';
  @StorageLink('sortDevicesByRoom') sortDevicesByRoom: boolean = false;
  @State clearMessage: string = '';

  aboutToAppear(): void {
    FeedbackLogService.setCurrentPage('设置页');
    this.onBreakpointChange();
    FeedbackLogService.recordOperation('PAGE',
      `设置项: 隐藏离线=${this.hideOfflineDevices} 分栏=${this.dualColumnMode} 自动多栏=${this.autoMultiColumn} ` +
      `平滑切换=${this.homeSmoothSwitch} 华氏温度=${this.temperatureFahrenheit} 显示单位=${this.temperatureShowUnit} ` +
      `显示更多内容=${this.infoShowMoreContent} 按房间排序=${this.sortDevicesByRoom}`);
  }

  onBreakpointChange(): void {
    this.isWideScreen = this.widthBp === WidthBreakpoint.WIDTH_LG ||
      this.widthBp === WidthBreakpoint.WIDTH_XL;
  }

  clearAllSettings(): void {
    AppSettingsStore.delete('hideOfflineDevices');
    AppSettingsStore.delete('selectedHomeId');
    AppSettingsStore.delete('selectedHomeName');
    AppSettingsStore.delete('dualColumnMode');
    AppSettingsStore.delete('autoMultiColumn');
    AppSettingsStore.delete('temperatureFahrenheit');
    AppSettingsStore.delete('temperatureShowUnit');
    AppSettingsStore.delete('dualColumnRestore');
    AppSettingsStore.delete('infoExcludedDevices');
    AppSettingsStore.delete('infoShowMoreContent');
    AppSettingsStore.delete('sortDevicesByRoom');
    AppSettingsStore.delete('backgroundImage');
    AppSettingsStore.delete('defaultHomeTab');
    AppSettingsStore.delete('infoRefreshInterval');
    AppStorage.setOrCreate('hideOfflineDevices', false);
    AppStorage.setOrCreate('selectedHomeId', '');
    AppStorage.setOrCreate('selectedHomeName', '');
    AppStorage.setOrCreate('dualColumnMode', false);
    AppStorage.setOrCreate('autoMultiColumn', false);
    AppStorage.setOrCreate('temperatureFahrenheit', false);
    AppStorage.setOrCreate('temperatureShowUnit', false);
    AppStorage.setOrCreate('infoExcludedDevices', []);
    AppStorage.setOrCreate('infoShowMoreContent', true);
    AppStorage.setOrCreate('sortDevicesByRoom', false);
    AppStorage.setOrCreate('backgroundImage', '');
    AppStorage.setOrCreate('defaultHomeTab', 'home');
    AppStorage.setOrCreate('infoRefreshInterval', '30');
    this.hideOfflineDevices = false;
    this.dualColumnMode = false;
    this.autoMultiColumn = false;
    this.temperatureFahrenheit = false;
    this.temperatureShowUnit = false;
    this.infoShowMoreContent = true;
    this.infoRefreshInterval = '30';
    this.sortDevicesByRoom = false;
    this.wallpaperImage = '';
    this.clearMessage = '已清空所有记住的设置项';
  }

  refreshIntervalLabel(value: string): string {
    const seconds = Number.parseInt(value, 10);
    if (Number.isNaN(seconds) || seconds < 60) {
      return '30秒';
    }
    if (seconds % 60 === 0) {
      return `${seconds / 60}分钟`;
    }
    return `${seconds}秒`;
  }

  cycleRefreshInterval(): void {
    const options: string[] = ['30', '60', '120', '300', '600'];
    const current = AppStorage.get<string>('infoRefreshInterval') ?? '30';
    let index = options.indexOf(current);
    if (index < 0) {
      index = 0;
    }
    const next = options[(index + 1) % options.length];
    AppStorage.setOrCreate('infoRefreshInterval', next);
    AppSettingsStore.setString('infoRefreshInterval', next);
    this.infoRefreshInterval = next;
    FeedbackLogService.recordOperation('UI', `自动刷新间隔改为 ${this.refreshIntervalLabel(next)}`);
  }

  setAutoMultiColumn(isOn: boolean): void {
    if (isOn === this.autoMultiColumn) {
      return;
    }
    if (isOn) {
      AppSettingsStore.setBoolean('dualColumnRestore', this.dualColumnMode);
      this.dualColumnMode = false;
      AppSettingsStore.setBoolean('dualColumnMode', false);
    } else {
      if (AppSettingsStore.getBoolean('dualColumnRestore', false)) {
        this.dualColumnMode = true;
        AppSettingsStore.setBoolean('dualColumnMode', true);
      }
      AppSettingsStore.delete('dualColumnRestore');
    }
    this.autoMultiColumn = isOn;
    AppSettingsStore.setBoolean('autoMultiColumn', isOn);
  }

  showClearAllDialog(): void {
    this.getUIContext().showAlertDialog({
      title: '清空所有记住的设置项',
      message: '确定要清空所有记住的设置项吗？包括背景、家庭选择、默认页面、更新频率等。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '清空',
        fontColor: HwColor.danger,
        action: () => {
          this.clearAllSettings();
        }
      }
    });
  }

  private updateBoolean(key: string, on: boolean): void {
    AppStorage.setOrCreate(key, on);
    AppSettingsStore.setBoolean(key, on);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      AppBackground()
      Column() {
        Scroll() {
          Column({ space: 0 }) {
            Blank().height(56 + this.statusBarHeight)
            Column({ space: 12 }) {
              if (this.clearMessage.length > 0) {
                Text(this.clearMessage)
                  .fontFamily(this.appFontFamily(this.clearMessage))
                  .fontWeight(this.appFontWeight())
                  .fontSize(13)
                  .fontColor(HwColor.primary)
                  .width('100%')
                  .padding({ left: 4, right: 4 })
              }

              // 隐藏离线设备
              Row({ space: 12 }) {
                Column({ space: 4 }) {
                  Text('隐藏离线设备')
                    .fontFamily(this.appFontFamily('隐藏离线设备'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(15)
                    .fontColor(Color.White)
                  Text('首页不显示离线设备')
                    .fontFamily(this.appFontFamily('首页不显示离线设备'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(12)
                    .fontColor(MijiaOverviewCardText)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.hideOfflineDevices })
                  .onChange((isOn: boolean) => {
                    this.updateBoolean('hideOfflineDevices', isOn);
                  })
              }
              .width('100%')
              .padding(HwSpace.lg)
              .borderRadius(HwRadius.card)
              .backgroundColor(MijiaOverviewCard)
              .border({ width: 1, color: '#24FFFFFF' })
              .clip(true)

              // 按房间排序
              Row({ space: 12 }) {
                Column({ space: 4 }) {
                  Text('按房间排序')
                    .fontFamily(this.appFontFamily('按房间排序'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(15)
                    .fontColor(Color.White)
                  Text('首页设备按本地房间分组排序')
                    .fontFamily(this.appFontFamily('首页设备按本地房间分组排序'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(12)
                    .fontColor(MijiaOverviewCardText)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.sortDevicesByRoom })
                  .onChange((isOn: boolean) => {
                    this.updateBoolean('sortDevicesByRoom', isOn);
                  })
              }
              .width('100%')
              .padding(HwSpace.lg)
              .borderRadius(HwRadius.card)
              .backgroundColor(MijiaOverviewCard)
              .border({ width: 1, color: '#24FFFFFF' })
              .clip(true)

              // 平滑切换
              Row({ space: 12 }) {
                Column({ space: 4 }) {
                  Text('平滑切换')
                    .fontFamily(this.appFontFamily('平滑切换'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(15)
                    .fontColor(this.pcLayoutEnabled ? MijiaOverviewCardText : Color.White)
                  Text(this.pcLayoutEnabled ? '侧边导航布局下不可用' : '底栏切换带平滑动效')
                    .fontFamily(this.appFontFamily(this.pcLayoutEnabled ? '侧边导航布局下不可用' : '底栏切换带平滑动效'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(12)
                    .fontColor(MijiaOverviewCardText)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.homeSmoothSwitch })
                  .enabled(!this.pcLayoutEnabled)
                  .onChange((isOn: boolean) => {
                    this.updateBoolean('homeSmoothSwitch', isOn);
                  })
              }
              .width('100%')
              .padding(HwSpace.lg)
              .borderRadius(HwRadius.card)
              .backgroundColor(MijiaOverviewCard)
              .border({ width: 1, color: '#24FFFFFF' })
              .clip(true)

              // 华氏度
              Row({ space: 12 }) {
                Column({ space: 4 }) {
                  Text('温度以华氏度℉')
                    .fontFamily(this.appFontFamily('温度以华氏度℉'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(15)
                    .fontColor(Color.White)
                  Text('所有温度以华氏度显示')
                    .fontFamily(this.appFontFamily('所有温度以华氏度显示'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(12)
                    .fontColor(MijiaOverviewCardText)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.temperatureFahrenheit })
                  .onChange((isOn: boolean) => {
                    this.updateBoolean('temperatureFahrenheit', isOn);
                  })
              }
              .width('100%')
              .padding(HwSpace.lg)
              .borderRadius(HwRadius.card)
              .backgroundColor(MijiaOverviewCard)
              .border({ width: 1, color: '#24FFFFFF' })
              .clip(true)

              // 温度额外显示单位
              Row({ space: 12 }) {
                Column({ space: 4 }) {
                  Text('温度额外显示单位')
                    .fontFamily(this.appFontFamily('温度额外显示单位'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(15)
                    .fontColor(Color.White)
                  Text('温度数值后显示°C/°F单位')
                    .fontFamily(this.appFontFamily('温度数值后显示°C/°F单位'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(12)
                    .fontColor(MijiaOverviewCardText)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.temperatureShowUnit })
                  .onChange((isOn: boolean) => {
                    this.updateBoolean('temperatureShowUnit', isOn);
                  })
              }
              .width('100%')
              .padding(HwSpace.lg)
              .borderRadius(HwRadius.card)
              .backgroundColor(MijiaOverviewCard)
              .border({ width: 1, color: '#24FFFFFF' })
              .clip(true)

              // 信息页显示更多内容
              Row({ space: 12 }) {
                Column({ space: 4 }) {
                  Text('信息页显示更多内容')
                    .fontFamily(this.appFontFamily('信息页显示更多内容'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(15)
                    .fontColor(Color.White)
                  Text('卡片显示设备数与平均值')
                    .fontFamily(this.appFontFamily('卡片显示设备数与平均值'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(12)
                    .fontColor(MijiaOverviewCardText)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.infoShowMoreContent })
                  .onChange((isOn: boolean) => {
                    this.updateBoolean('infoShowMoreContent', isOn);
                  })
              }
              .width('100%')
              .padding(HwSpace.lg)
              .borderRadius(HwRadius.card)
              .backgroundColor(MijiaOverviewCard)
              .border({ width: 1, color: '#24FFFFFF' })
              .clip(true)

              // 自动刷新间隔
              Row({ space: 12 }) {
                Column({ space: 4 }) {
                  Text('自动刷新间隔')
                    .fontFamily(this.appFontFamily('自动刷新间隔'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(15)
                    .fontColor(Color.White)
                  Text('首页与信息页数据自动刷新周期，点击切换')
                    .fontFamily(this.appFontFamily('首页与信息页数据自动刷新周期，点击切换'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(12)
                    .fontColor(MijiaOverviewCardText)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Text(this.refreshIntervalLabel(this.infoRefreshInterval))
                  .fontFamily(this.appFontFamily(this.refreshIntervalLabel(this.infoRefreshInterval)))
                  .fontWeight(this.appFontWeight())
                  .fontSize(14)
                  .fontColor(MijiaOverviewCardValue)
                  .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                  .borderRadius(HwRadius.control)
                  .backgroundColor('#1AFFFFFF')
                  .onClick(() => {
                    this.cycleRefreshInterval();
                  })
              }
              .width('100%')
              .padding(HwSpace.lg)
              .borderRadius(HwRadius.card)
              .backgroundColor(MijiaOverviewCard)
              .border({ width: 1, color: '#24FFFFFF' })
              .clip(true)

              // 背景与外观（自定义背景、字体等）
              Row({ space: 12 }) {
                Column({ space: 4 }) {
                  Text('背景与外观')
                    .fontFamily(this.appFontFamily('背景与外观'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(15)
                    .fontColor(Color.White)
                  Text(this.wallpaperImage.length > 0 ? '已设置自定义背景' : '选择图片作为应用背景')
                    .fontFamily(this.appFontFamily(this.wallpaperImage.length > 0 ? '已设置自定义背景' : '选择图片作为应用背景'))
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
              .onClick(() => {
                this.getUIContext().getRouter().pushUrl({ url: 'pages/AppearanceSettingsPage' });
              })

              // 清空所有记住的设置项
              Row({ space: 12 }) {
                Column({ space: 4 }) {
                  Text('清空所有记住的设置项')
                    .fontFamily(this.appFontFamily('清空所有记住的设置项'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(15)
                    .fontColor(HwColor.danger)
                  Text('包括背景、家庭选择、默认页面、更新频率等')
                    .fontFamily(this.appFontFamily('包括背景、家庭选择、默认页面、更新频率等'))
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
                this.showClearAllDialog();
              })

              // 大屏布局
              if (this.isLargeScreen) {
                Row({ space: 12 }) {
                  Column({ space: 4 }) {
                    Text('自动多栏')
                      .fontFamily(this.appFontFamily('自动多栏'))
                      .fontWeight(this.appFontWeight())
                      .fontSize(15)
                      .fontColor(this.pcLayoutEnabled ? MijiaOverviewCardText : Color.White)
                    Text(this.pcLayoutEnabled ? '侧边导航布局下不可用' : '平板自动分栏，详情右侧打开')
                      .fontFamily(this.appFontFamily('平板自动分栏，详情右侧打开'))
                      .fontWeight(this.appFontWeight())
                      .fontSize(12)
                      .fontColor(MijiaOverviewCardText)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  Toggle({ type: ToggleType.Switch, isOn: this.autoMultiColumn })
                    .enabled(!this.pcLayoutEnabled)
                    .onChange((isOn: boolean) => {
                      this.setAutoMultiColumn(isOn);
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
                    Text('侧边导航布局')
                      .fontFamily(this.appFontFamily('侧边导航布局'))
                      .fontWeight(this.appFontWeight())
                      .fontSize(15)
                      .fontColor(Color.White)
                    Text(this.is2in1 ? 'PC 侧边导航样式（2in1 默认开启）' : 'PC 侧边导航样式（平板默认关闭）')
                      .fontFamily(this.appFontFamily('PC 侧边导航样式'))
                      .fontWeight(this.appFontWeight())
                      .fontSize(12)
                      .fontColor(MijiaOverviewCardText)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  Toggle({ type: ToggleType.Switch, isOn: this.pcLayoutEnabled })
                    .onChange((isOn: boolean) => {
                      this.pcLayoutEnabled = isOn;
                      this.updateBoolean('pcLayoutEnabled', isOn);
                      if (isOn && this.autoMultiColumn) {
                        this.setAutoMultiColumn(false);
                      }
                      if (isOn && this.homeSmoothSwitch) {
                        this.homeSmoothSwitch = false;
                        this.updateBoolean('homeSmoothSwitch', false);
                      }
                    })
                }
                .width('100%')
                .padding(HwSpace.lg)
                .borderRadius(HwRadius.card)
                .backgroundColor(MijiaOverviewCard)
                .border({ width: 1, color: '#24FFFFFF' })
                .clip(true)
              }
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
        Text('设置')
          .fontFamily(this.appFontFamily('设置'))
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
