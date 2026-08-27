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

import {
  MijiaQrLoginService,
  MijiaQrLoginTicket
} from '../oauth/MijiaQrLoginService';
import { xiaomiDataService } from '../services/XiaomiDataService';
import { FeedbackLogService } from '../services/FeedbackLogService';
import { Logger } from '../utils/Logger';
import { HwColor, HwRadius, HwSpace, MijiaOverviewCard, MijiaOverviewCardValue } from '../utils/DesignTokens';
import { PressableButton } from '../components/PressableButton';
import { AppBackground } from '../components/AppBackground';
import { AppSettingsStore } from '../storage/AppSettingsStore';

@Entry
@Component
struct LoginPage {
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

  aboutToAppear(): void {
    FeedbackLogService.setCurrentPage('登录页');
  }

  @State qrUrl: string = '';
  @State loading: boolean = false;
  @State statusMessage: string = '';
  @State errorMessage: string = '';
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('navigationBarHeight') navigationBarHeight: number = 0;
  @StorageProp('isDarkMode') isDarkMode: boolean = false;
  @StorageProp('isWearable') isWearable: boolean = false;

  private loginService: MijiaQrLoginService | null = null;
  private ticket: MijiaQrLoginTicket | null = null;

  async startMijiaLogin(): Promise<void> {
    if (this.loading) {
      return;
    }
    this.loading = true;
    this.errorMessage = '';
    this.statusMessage = '';
    try {
      this.loginService = new MijiaQrLoginService();
      this.ticket = await this.loginService.buildLoginTicket();
      this.qrUrl = this.ticket.qr;
      this.statusMessage = '请使用小米/米家 App 扫码登录';
      const auth = await this.loginService.pollTicket(this.ticket);
      await xiaomiDataService.setMijiaAuth(auth);
      AppStorage.setOrCreate('selectedHomeId', '');
      AppStorage.setOrCreate('selectedHomeName', '');
      AppStorage.setOrCreate('homeSelectionVersion', 0);
      AppSettingsStore.setString('selectedHomeId', '');
      AppSettingsStore.setString('selectedHomeName', '');
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/HomePage' });
    } catch (err) {
      this.errorMessage = err instanceof Error ? err.message : '登录失败';
      Logger.error('mijia qr login failed, %{public}s', this.errorMessage);
    } finally {
      this.loading = false;
    }
  }

  build() {
    Stack() {
      AppBackground()
      Column() {
        Column({ space: HwSpace.sm }) {
        Text('米家控制')
          .fontFamily(this.appFontFamily('米家控制'))
          .fontWeight(this.appFontWeight())
          .fontSize(this.isWearable ? 24 : 32)
          .fontWeight(FontWeight.Bold)
          .fontColor(HwColor.textPrimary)

        Text('使用小米/米家 App 扫码登录')
          .fontFamily(this.appFontFamily('使用小米/米家 App 扫码登录'))
          .fontWeight(this.appFontWeight())
          .fontSize(this.isWearable ? 13 : 16)
          .fontColor(HwColor.textSecondary)
      }
        .margin({ top: this.isWearable ? 24 : 72, bottom: this.isWearable ? 16 : 32 })

      Column({ space: 18 }) {
        Column() {
          if (this.qrUrl.length > 0) {
            Image(this.qrUrl)
              .width(this.isWearable ? 160 : 240)
              .height(this.isWearable ? 160 : 240)
              .objectFit(ImageFit.Contain)
          } else {
            Text('二维码将显示在这里')
              .fontFamily(this.appFontFamily('二维码将显示在这里'))
              .fontWeight(this.appFontWeight())
              .fontSize(14)
              .fontColor(HwColor.textSecondary)
          }
        }
        .width(this.isWearable ? 160 : 240)
        .height(this.isWearable ? 160 : 240)
        .justifyContent(FlexAlign.Center)
        .borderRadius(HwRadius.card)
        .backgroundColor(MijiaOverviewCard)
        .border({ width: 1, color: '#24FFFFFF' })
        .clip(true)

        PressableButton({
          label: this.loading ? '等待扫码...' : '生成二维码登录',
          emphasized: true,
          loading: this.loading,
          fullWidth: true,
          buttonHeight: 48,
          role: ButtonRole.NORMAL,
          onAction: () => {
            this.startMijiaLogin();
          }
        })

        if (this.statusMessage.length > 0) {
          Text(this.statusMessage)
            .fontFamily(this.appFontFamily(this.statusMessage))
            .fontWeight(this.appFontWeight())
            .fontSize(14)
            .fontColor(MijiaOverviewCardValue)
        }

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontFamily(this.appFontFamily(this.errorMessage))
            .fontWeight(this.appFontWeight())
            .fontSize(14)
            .fontColor(HwColor.danger)
        }
      }
      .width('100%')
      .padding(this.isWearable ? HwSpace.md : HwSpace.xl)
      .borderRadius(HwRadius.card)
      .backgroundColor(MijiaOverviewCard)
      .border({ width: 1, color: '#24FFFFFF' })
      .clip(true)

      Blank()
      }
      .width('100%')
      .height('100%')
      .padding({
        left: HwSpace.xl,
        right: HwSpace.xl,
        top: HwSpace.xl + this.statusBarHeight,
        bottom: HwSpace.xl + this.navigationBarHeight
      })
      .backgroundColor(Color.Transparent)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isDarkMode ? HwColor.backgroundDark : HwColor.background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
