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
import { SymbolGlyphModifier } from '@kit.ArkUI';
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  ScrollEffectType,
  HdsTabs,
  HdsTabsController,
  hdsMaterial
} from '@kit.UIDesignKit';
import { XiaomiDevice, XiaomiHome, XiaomiScene, InfoExcludeOption, LocalScene, ALL_HOMES_ID, ALL_HOMES_NAME } from '../models/XiaomiHomeModels';
import { xiaomiDataService } from '../services/XiaomiDataService';
import { LocalSceneStore } from '../storage/LocalSceneStore';
import { FeedbackLogService } from '../services/FeedbackLogService';
import { Logger } from '../utils/Logger';
import { DataSourceState } from '../models/CacheState';
import { XiaomiAuthError } from '../models/XiaomiErrors';
import {
  HwColor,
  HwRadius,
  HwSpace,
  MijiaHeaderGradient,
  MijiaOverviewCard,
  MijiaOverviewCardPressed,
  MijiaOverviewCardText,
  MijiaOverviewCardValue,
  MijiaSheetBackground
} from '../utils/DesignTokens';
import { isCelsiusUnit, celsiusToFahrenheit } from '../utils/TemperatureDisplay';
import { IconCircleButton } from '../components/IconCircleButton';
import { AppSettingsStore } from '../storage/AppSettingsStore';
import { AppBackground } from '../components/AppBackground';
import { DeviceDetailRouteParam, DeviceManageRouteParam } from '../models/NavRouteParams';
import { DeviceController } from '../controllers/DeviceController';
import { DevicePropertyParam, DevicePropertyResult } from '../controllers/DeviceTransport';
import { MIoTSpecInstance } from '../models/MIotSpecModels';
import { RoomStore, UserRoom } from '../storage/RoomStore';
import { DeviceRemovalStore } from '../storage/DeviceRemovalStore';

const TITLE_BAR_HEIGHT_FREE: number = 137;
const CONTENT_TOP_OFFSET: number = 137;
const BOTTOM_BAR_HEIGHT: number = 56;
const BOTTOM_BAR_MARGIN: number = 12;
const INFO_CARD_HEIGHT: number = 128;
const SIDE_BAR_WIDTH_DEFAULT: number = 96;
const SIDE_BAR_WIDTH_MIN: number = 80;
const SIDE_BAR_WIDTH_MAX: number = 320;
const MAX_CONTENT_WIDTH: number = 1080;
const ROOM_ALL_KEY: string = '__all_rooms__';
const ROOM_UNROOMED_KEY: string = '__unroomed__';

interface RoomCandidate {
  key: string;
  name: string;
  roomId: string;
  dids: string[];
}

interface RoomChip {
  key: string;
  name: string;
  roomId: string;
  dids: string[];
  count: number;
}

interface InfoSpecProperty {
  siid: number;
  piid: number;
  unit: string;
}

interface InfoPropertyTarget {
  did: string;
  name: string;
  roomName: string;
  siid: number;
  piid: number;
  unit: string;
}

interface InfoMetricRange {
  min: number;
  max: number;
  count: number;
  average: number;
}

interface InfoDeviceEntry {
  did: string;
  name: string;
  roomName: string;
  valueText: string;
}

interface InfoMetricResult {
  range: InfoMetricRange;
  entries: InfoDeviceEntry[];
}

interface InfoMetricCardConfig {
  title: string;
  rangeText: string;
  moreText: string;
}

interface OverviewCardConfig {
  title: string;
  rangeText: string;
  moreText: string;
  sheetIndex: number;
  icon: Resource;
}

interface AlertItem {
  did: string;
  deviceName: string;
  roomName: string;
  type: string;
  title: string;
  detail: string;
  level: string;
}

interface AlertPropertyInfo {
  siid: number;
  piid: number;
  used: boolean;
}

@Entry
@Component
struct HomePage {
  @StorageLink('cardsFromTop') cardsFromTop: boolean = true;
  @StorageLink('homeSmoothSwitch') homeSmoothSwitch: boolean = false;
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
  @Provide('pageInfos') pageInfos: NavPathStack = new NavPathStack();
  private tabsController: HdsTabsController = new HdsTabsController();
  private homeScroller: Scroller = new Scroller();
  private mineScroller: Scroller = new Scroller();
  private infoScroller: Scroller = new Scroller();
  private smartScroller: Scroller = new Scroller();
  private alertScroller: Scroller = new Scroller();
  private allVisibleDevices: XiaomiDevice[] = [];
  private infoFetching: boolean = false;
  @StorageLink('selectedHomeId') selectedHomeId: string = '';
  @StorageLink('selectedHomeName') selectedHomeName: string = '';
  @StorageLink('homeSelectionVersion') @Watch('onHomeSelectionChanged') homeSelectionVersion: number = 0;
  @State homes: XiaomiHome[] = [];
  @State devices: XiaomiDevice[] = [];
  @State loading: boolean = true;
  @State statusMessage: string = '';
  @State errorMessage: string = '';
  @State dataState: DataSourceState = DataSourceState.ONLINE;
  @State activeTab: number = 0;
  @State accountUserId: string = '';
  @State accountNickname: string = '';
  @State accountAvatarUrl: string = '';
  @StorageLink('hideOfflineDevices') @Watch('onHideOfflineDevicesChanged') hideOfflineDevices: boolean = false;
  @StorageLink('dualColumnMode') dualColumnMode: boolean = false;
  @StorageLink('autoMultiColumn') autoMultiColumn: boolean = false;
  @StorageProp('isLargeScreen') isLargeScreen: boolean = false;
  @StorageProp('is2in1') is2in1: boolean = false;
  @StorageProp('isWearable') isWearable: boolean = false;
  @StorageProp('currentWidthBreakpoint') @Watch('onBreakpointChange')
  widthBp: WidthBreakpoint = WidthBreakpoint.WIDTH_SM;
  @StorageProp('screenWidthVp') screenWidthVp: number = 0;
  @StorageLink('pcLayoutEnabled') @Watch('onBreakpointChange') pcLayoutEnabled: boolean = false;
  @State isWideScreen: boolean = false;
  @State sideBarWidth: number = SIDE_BAR_WIDTH_DEFAULT;
  @State dragHovered: boolean = false;
  private dragStartWidth: number = SIDE_BAR_WIDTH_DEFAULT;
  @StorageLink('temperatureFahrenheit') @Watch('onTemperatureUnitChanged') temperatureFahrenheit: boolean = false;
  @StorageProp('navigationBarHeight') navigationBarHeight: number = 0;
  @StorageProp('isDarkMode') isDarkMode: boolean = false;
  @StorageLink('infoExcludedDevices') infoExcludedDevices: string[] = [];
  @StorageLink('backgroundImage') wallpaperImage: string = '';
  @StorageLink('infoShowMoreContent') infoShowMoreContent: boolean = true;
  @StorageLink('sortDevicesByRoom') sortDevicesByRoom: boolean = false;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageLink('defaultHomeTab') defaultHomeTab: string = 'home';
  @StorageLink('infoRefreshInterval') @Watch('onInfoRefreshIntervalChanged') infoRefreshInterval: string = '30';
  @State localRooms: UserRoom[] = [];
  @State selectedRoomKey: string = ROOM_ALL_KEY;
  @State roomChips: RoomChip[] = [];
  @State filteredDevices: XiaomiDevice[] = [];
  private pendingDeviceDid: string = '';
  private infoRefreshTimer: number = -1;
  private lastInfoRefreshAt: number = 0;
  @State infoLoading: boolean = false;
  @State infoError: string = '';
  @State temperatureRangeText: string = '--';
  @State humidityRangeText: string = '--';
  @State pm25RangeText: string = '--';
  @State temperatureMoreText: string = '';
  @State humidityMoreText: string = '';
  @State pm25MoreText: string = '';
  @State onDeviceCount: number = 0;
  @State infoDeviceCount: number = 0;
  @State temperatureDevices: InfoDeviceEntry[] = [];
  @State humidityDevices: InfoDeviceEntry[] = [];
  @State pm25Devices: InfoDeviceEntry[] = [];
  @State onDevices: InfoDeviceEntry[] = [];
  @State showTemperatureSheet: boolean = false;
  @State showHumiditySheet: boolean = false;
  @State showPm25Sheet: boolean = false;
  @State showOnSheet: boolean = false;
  @State showExcludeSheet: boolean = false;
  @State showFamilySheet: boolean = false;
  @State homeRefreshing: boolean = false;
  @State scenes: XiaomiScene[] = [];
  @State localScenes: LocalScene[] = [];
  @State scenesLoading: boolean = false;
  @State scenesError: string = '';
  @State alerts: AlertItem[] = [];
  @State alertsLoading: boolean = false;

  aboutToAppear(): void {
    FeedbackLogService.setCurrentPage('首页');
    this.onBreakpointChange();
    this.localRooms = RoomStore.loadRooms();
    this.loadData(true);
    this.loadAccount();
    if (!this.isWearable) {
      this.startInfoRefreshTimer();
      this.refreshInfoOnEnter();
    }
  }

  aboutToDisappear(): void {
    this.stopInfoRefreshTimer();
  }

  onPageShow(): void {
    this.localRooms = RoomStore.loadRooms();
    this.rebuildRoomChips();
    this.applyDeviceVisibility();
  }

  onHideOfflineDevicesChanged(): void {
    this.applyDeviceVisibility();
  }

  private applyDeviceVisibility(): void {
    let visible = this.allVisibleDevices;
    if (this.hideOfflineDevices) {
      visible = visible.filter((device: XiaomiDevice) => device.online);
    }
    this.devices = this.sortVisibleDevices(visible);
    this.updateFilteredDevices();
  }

  async loadData(forceRefresh: boolean, silent: boolean = false): Promise<void> {
    if (!silent) {
      this.loading = true;
    }
    this.errorMessage = '';
    this.statusMessage = '';
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const snapshot = await xiaomiDataService.getHomeSnapshot(context, forceRefresh);
      const homes = JSON.parse(snapshot.homesJson) as XiaomiHome[];
      const deviceMap = JSON.parse(snapshot.devicesJson) as Record<string, XiaomiDevice>;
      this.dataState = snapshot.state;
      this.homes = homes;
      if (this.selectedHomeId.length === 0 && homes.length > 0) {
        this.selectedHomeId = homes[0].homeId;
        this.selectedHomeName = homes[0].name;
        AppSettingsStore.setString('selectedHomeId', homes[0].homeId);
        AppSettingsStore.setString('selectedHomeName', homes[0].name);
      }
      const allDevices: XiaomiDevice[] = [];
      const dids = Object.keys(deviceMap);
      for (let i = 0; i < dids.length; i++) {
        allDevices.push(deviceMap[dids[i]]);
      }
      let visibleDevices: XiaomiDevice[] = [];
      if (this.selectedHomeId.length === 0) {
        visibleDevices = [];
      } else if (this.selectedHomeId === ALL_HOMES_ID) {
        visibleDevices = allDevices;
      } else {
        visibleDevices = allDevices.filter((device: XiaomiDevice) => device.homeId === this.selectedHomeId);
      }
      this.allVisibleDevices = visibleDevices;
      visibleDevices = DeviceRemovalStore.filter(visibleDevices);
      this.rebuildRoomChips();
      let displayDevices: XiaomiDevice[] = [];
      if (this.hideOfflineDevices) {
        displayDevices = visibleDevices.filter((device: XiaomiDevice) => device.online);
      } else {
        displayDevices = visibleDevices;
      }
      this.devices = this.sortVisibleDevices(displayDevices);
      if (this.selectedRoomKey !== ROOM_ALL_KEY && this.findChip(this.selectedRoomKey) === null) {
        this.selectedRoomKey = ROOM_ALL_KEY;
      }
      this.updateFilteredDevices();
      FeedbackLogService.recordOperation('PAGE',
        `首页设备列表: 共 ${displayDevices.length} 台，${this.deviceListSummary(displayDevices)}`);
      const excludeOptions: InfoExcludeOption[] = [];
      for (let i = 0; i < displayDevices.length; i++) {
        excludeOptions.push({
          did: displayDevices[i].did,
          name: displayDevices[i].name,
          roomName: displayDevices[i].roomName
        });
      }
      AppStorage.setOrCreate('infoDeviceOptions', excludeOptions);

      if (this.selectedHomeId.length === 0) {
        this.statusMessage = '请先选择家庭';
      } else if (this.dataState === DataSourceState.STALE) {
        this.statusMessage = '网络不可用，当前显示过期缓存';
      } else if (this.dataState === DataSourceState.CACHED) {
        this.statusMessage = '网络不可用，当前显示最近缓存';
      } else if (this.devices.length === 0) {
        this.statusMessage = this.selectedHomeId === ALL_HOMES_ID ? '没有设备' : '当前家庭没有设备';
      }
    } catch (err) {
      this.errorMessage = err instanceof Error ? err.message : '加载家庭数据失败';
      Logger.error('load home data failed, %{public}s', this.errorMessage);
      if (err instanceof XiaomiAuthError) {
        await xiaomiDataService.clearSession();
        this.getUIContext().getRouter().replaceUrl({ url: 'pages/LoginPage' });
      }
    } finally {
      if (!silent) {
        this.loading = false;
      }
    }
  }

  async loadAccount(): Promise<void> {
    try {
      const auth = await xiaomiDataService.getMijiaAuth();
      if (auth !== null) {
        this.accountUserId = auth.userId;
      }
      const profile = await xiaomiDataService.getUserProfile();
      if (profile !== null) {
        this.accountNickname = profile.nickname;
        this.accountAvatarUrl = profile.avatarUrl;
      } else {
        this.accountNickname = '';
        this.accountAvatarUrl = '';
      }
    } catch (err) {
      this.accountUserId = '';
      this.accountNickname = '';
      this.accountAvatarUrl = '';
    }
  }

  async loadScenes(force: boolean = false): Promise<void> {
    if (this.scenesLoading) {
      return;
    }
    this.scenesLoading = true;
    this.scenesError = '';
    this.loadLocalScenes();
    try {
      const list: XiaomiScene[] = [];
      // 只加载用户当前选择家庭的自动化（含共享家庭场景）
      const targetHomes: XiaomiHome[] = [];
      if (this.selectedHomeId === ALL_HOMES_ID) {
        for (let i = 0; i < this.homes.length; i++) {
          targetHomes.push(this.homes[i]);
        }
      } else {
        const home = this.currentHome();
        if (home !== null) {
          targetHomes.push(home);
        }
      }
      if (targetHomes.length === 0 && this.selectedHomeId.length > 0 &&
        this.selectedHomeId !== ALL_HOMES_ID) {
        const snapshot = await xiaomiDataService.getHomeSnapshot(getContext(this) as common.UIAbilityContext,
          false);
        const homeList = JSON.parse(snapshot.homesJson) as XiaomiHome[];
        for (let i = 0; i < homeList.length; i++) {
          if (homeList[i].homeId === this.selectedHomeId) {
            targetHomes.push(homeList[i]);
            break;
          }
        }
      }
      const seenSceneIds: string[] = [];
      for (let i = 0; i < targetHomes.length; i++) {
        const scenes = await xiaomiDataService.getScenes(targetHomes[i].homeId);
        for (let j = 0; j < scenes.length; j++) {
          if (seenSceneIds.indexOf(scenes[j].sceneId) < 0) {
            seenSceneIds.push(scenes[j].sceneId);
            list.push(scenes[j]);
          }
        }
      }
      this.scenes = list;
      FeedbackLogService.recordOperation('PAGE', `智能页自动化: ${list.length} 条`);
    } catch (err) {
      this.scenesError = err instanceof Error ? err.message : '加载自动化失败';
      Logger.error('load scenes failed, %{public}s', this.scenesError);
      if (err instanceof XiaomiAuthError) {
        await xiaomiDataService.clearSession();
        this.getUIContext().getRouter().replaceUrl({ url: 'pages/LoginPage' });
      }
    } finally {
      this.scenesLoading = false;
    }
  }

  private runSceneById(scene: XiaomiScene): void {
    this.getUIContext().showAlertDialog({
      title: '执行自动化',
      message: `确定执行「${scene.name}」吗？`,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '执行',
        fontColor: HwColor.primary,
        action: () => {
          this.execScene(scene);
        }
      }
    });
  }

  private async execScene(scene: XiaomiScene): Promise<void> {
    try {
      await xiaomiDataService.runScene(scene.sceneId, scene.homeId);
      this.getUIContext().getPromptAction().showToast({ message: `已执行「${scene.name}」` });
    } catch (err) {
      Logger.error('run scene failed, %{public}s',
        err instanceof Error ? err.message : String(err));
      this.getUIContext().getPromptAction().showToast({
        message: err instanceof Error ? err.message : '执行自动化失败'
      });
    }
  }

  loadLocalScenes(): void {
    this.localScenes = LocalSceneStore.load();
  }

  openSceneCreatePage(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/SceneCreatePage' });
  }

  private async execLocalScene(scene: LocalScene): Promise<void> {
    if (scene.actions.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '该智能没有可执行的动作' });
      return;
    }
    try {
      const controller = await xiaomiDataService.getDeviceController();
      let failed = 0;
      for (let i = 0; i < scene.actions.length; i++) {
        const action = scene.actions[i];
        try {
          await controller.setProperty(action.did, action.siid, action.piid, action.value);
        } catch (err) {
          failed++;
          Logger.error('local scene action failed, %{public}s',
            err instanceof Error ? err.message : String(err));
        }
      }
      this.getUIContext().getPromptAction().showToast({
        message: failed === 0 ? `已执行「${scene.name}」` : `执行「${scene.name}」失败 ${failed} 项`
      });
    } catch (err) {
      this.getUIContext().getPromptAction().showToast({
        message: err instanceof Error ? err.message : '执行智能失败'
      });
    }
  }

  private confirmDeleteLocalScene(scene: LocalScene): void {
    this.getUIContext().showAlertDialog({
      title: '删除智能',
      message: `确定删除「${scene.name}」吗？`,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: HwColor.danger,
        action: () => {
          LocalSceneStore.delete(scene.sceneId);
          this.loadLocalScenes();
        }
      }
    });
  }

  private findBatteryProperty(spec: MIoTSpecInstance): AlertPropertyInfo | null {
    for (let i = 0; i < spec.services.length; i++) {
      const service = spec.services[i];
      for (let j = 0; j < service.properties.length; j++) {
        const prop = service.properties[j];
        if (!prop.readable) {
          continue;
        }
        const format = prop.format.toLowerCase();
        if (format !== 'float' && format !== 'int') {
          continue;
        }
        const unitKey = prop.unit.trim().toLowerCase();
        if (unitKey !== 'percentage' && unitKey !== 'percent') {
          continue;
        }
        const text = `${prop.name} ${prop.description} ${prop.type} ${prop.unit}`.toLowerCase();
        if (!text.includes('battery') && !text.includes('电量') && !text.includes('剩余电量')) {
          continue;
        }
        if (text.includes('state') || text.includes('status') || text.includes('charging') ||
          text.includes('low') || text.includes('health')) {
          continue;
        }
        return { siid: service.iid, piid: prop.iid, used: false };
      }
    }
    return null;
  }

  private findFilterProperty(spec: MIoTSpecInstance): AlertPropertyInfo | null {
    for (let i = 0; i < spec.services.length; i++) {
      const service = spec.services[i];
      for (let j = 0; j < service.properties.length; j++) {
        const prop = service.properties[j];
        if (!prop.readable) {
          continue;
        }
        const format = prop.format.toLowerCase();
        if (format !== 'float' && format !== 'int') {
          continue;
        }
        const text = `${prop.name} ${prop.description} ${prop.type} ${prop.unit}`.toLowerCase();
        const isFilter = text.includes('filter') || text.includes('consumable') ||
          text.includes('replacement') || text.includes('maintenance') ||
          text.includes('尘盒') || text.includes('滤芯') || text.includes('耗材');
        if (!isFilter) {
          continue;
        }
        const unitKey = prop.unit.trim().toLowerCase();
        const isLifeMetric = text.includes('percent') || text.includes('remaining') ||
          text.includes('life') || text.includes('left') || text.includes('remain') ||
          unitKey === 'percentage' || unitKey === 'percent';
        if (!isLifeMetric) {
          continue;
        }
        const used = text.includes('used') || text.includes('consumption') ||
          text.includes('耗材') || text.includes('累计');
        return { siid: service.iid, piid: prop.iid, used: used };
      }
    }
    return null;
  }

  private async buildAlerts(): Promise<void> {
    if (this.alertsLoading) {
      return;
    }
    this.alertsLoading = true;
    try {
      // use all devices of current home (incl. offline) for alerts, ignore hide-offline setting
      let familyDevices = this.allVisibleDevices;
      if (familyDevices.length === 0) {
        await this.loadData(false);
        familyDevices = this.allVisibleDevices;
      }
      const items: AlertItem[] = [];
      const batteryTargets: InfoPropertyTarget[] = [];
      const filterTargets: InfoPropertyTarget[] = [];
      for (let i = 0; i < familyDevices.length; i++) {
        const device = familyDevices[i];
        if (!device.online) {
          items.push({
            did: device.did,
            deviceName: device.name,
            roomName: device.roomName,
            type: 'offline',
            title: '设备离线',
            detail: `${device.name} 当前离线，请检查电源与网络`,
            level: 'info'
          });
          continue;
        }
        let spec: MIoTSpecInstance;
        try {
          spec = await xiaomiDataService.getDeviceSpecForDevice(device);
        } catch (err) {
          Logger.warn('load alert spec failed for %{public}s, %{public}s',
            device.did, err instanceof Error ? err.message : String(err));
          continue;
        }
        const batteryProp = this.findBatteryProperty(spec);
        if (batteryProp !== null) {
          batteryTargets.push({
            did: device.did,
            name: device.name,
            roomName: device.roomName,
            siid: batteryProp.siid,
            piid: batteryProp.piid,
            unit: 'percentage'
          });
        }
        const filterProp = this.findFilterProperty(spec);
        if (filterProp !== null) {
          filterTargets.push({
            did: device.did,
            name: device.name,
            roomName: device.roomName,
            siid: filterProp.siid,
            piid: filterProp.piid,
            unit: filterProp.used ? 'used' : 'remaining'
          });
        }
      }
      const controller = await xiaomiDataService.getDeviceController();
      if (batteryTargets.length > 0) {
        const values = await this.fetchAlertValues(controller, batteryTargets);
        for (let i = 0; i < batteryTargets.length; i++) {
          const target = batteryTargets[i];
          const value = Number(values.get(`${target.did}.${target.siid}.${target.piid}`));
          if (Number.isNaN(value) || value >= 20) {
            continue;
          }
          items.push({
            did: target.did,
            deviceName: target.name,
            roomName: target.roomName,
            type: 'battery',
            title: '电量不足',
            detail: `${target.name} 电量仅剩 ${Math.round(value)}%，请及时充电`,
            level: 'warn'
          });
        }
      }
      if (filterTargets.length > 0) {
        const values = await this.fetchAlertValues(controller, filterTargets);
        for (let i = 0; i < filterTargets.length; i++) {
          const target = filterTargets[i];
          const value = Number(values.get(`${target.did}.${target.siid}.${target.piid}`));
          if (Number.isNaN(value)) {
            continue;
          }
          const exhausted = target.unit === 'used' ? value >= 90 : value <= 10;
          if (!exhausted) {
            continue;
          }
          items.push({
            did: target.did,
            deviceName: target.name,
            roomName: target.roomName,
            type: 'consumable',
            title: '耗材不足',
            detail: `${target.name} 滤芯/耗材需关注，建议及时更换`,
            level: 'warn'
          });
        }
      }
      this.alerts = items;
      FeedbackLogService.recordOperation('PAGE', `信息提醒页: ${items.length} 条提醒`);
    } catch (err) {
      Logger.error('build alerts failed, %{public}s',
        err instanceof Error ? err.message : String(err));
      if (err instanceof XiaomiAuthError) {
        await xiaomiDataService.clearSession();
        this.getUIContext().getRouter().replaceUrl({ url: 'pages/LoginPage' });
      }
    } finally {
      this.alertsLoading = false;
    }
  }

  private async fetchAlertValues(
    controller: DeviceController,
    targets: InfoPropertyTarget[]
  ): Promise<Map<string, Object | undefined>> {
    const params: DevicePropertyParam[] = [];
    for (let i = 0; i < targets.length; i++) {
      params.push({
        did: targets[i].did,
        siid: targets[i].siid,
        piid: targets[i].piid
      });
    }
    let results: DevicePropertyResult[] = [];
    try {
      results = await controller.getProperties(targets[0].did, params);
    } catch (err) {
      Logger.warn('fetch alert properties failed, %{public}s',
        err instanceof Error ? err.message : String(err));
    }
    const valueMap = new Map<string, Object | undefined>();
    for (let i = 0; i < results.length; i++) {
      const key = `${String(results[i].did)}.${results[i].siid}.${results[i].piid}`;
      valueMap.set(key, results[i].value);
    }
    return valueMap;
  }

  async onHomeSelectionChanged(): Promise<void> {
    if (this.selectedHomeId.length > 0) {
      // 先等设备列表加载完成，再刷新智能与信息提醒，避免用到旧家庭数据
      await this.loadData(true);
      await this.loadScenes(false);
      await this.buildAlerts();
    }
  }

  showLogoutDialog(): void {
    this.getUIContext().showAlertDialog({
      title: '退出登录',
      message: '确定要退出当前账号吗？',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '退出',
        fontColor: HwColor.danger,
        action: () => {
          this.confirmLogout();
        }
      }
    });
  }

  async confirmLogout(): Promise<void> {
    FeedbackLogService.recordOperation('UI', '退出登录');
    await xiaomiDataService.clearSession();
    this.getUIContext().getRouter().replaceUrl({ url: 'pages/LoginPage' });
  }

  async loadInfoData(silent: boolean = false): Promise<void> {
    if (this.infoFetching) {
      return;
    }
    this.infoFetching = true;
    if (!silent) {
      this.infoLoading = true;
      this.infoError = '';
      this.temperatureRangeText = '--';
      this.humidityRangeText = '--';
      this.pm25RangeText = '--';
      this.temperatureMoreText = '';
      this.humidityMoreText = '';
      this.pm25MoreText = '';
      this.onDeviceCount = 0;
      this.temperatureDevices = [];
      this.humidityDevices = [];
      this.pm25Devices = [];
      this.onDevices = [];
      this.infoDeviceCount = 0;
    }
    try {
      // use all devices of current home (incl. offline) for alerts, ignore hide-offline setting
      let familyDevices = this.allVisibleDevices;
      if (familyDevices.length === 0) {
        await this.loadData(false);
        familyDevices = this.allVisibleDevices;
      }
      const temperatureTargets: InfoPropertyTarget[] = [];
      const humidityTargets: InfoPropertyTarget[] = [];
      const pm25Targets: InfoPropertyTarget[] = [];
      const switchTargets: InfoPropertyTarget[] = [];
      for (let i = 0; i < familyDevices.length; i++) {
        const device = familyDevices[i];
        if (!device.online) {
          continue;
        }
        if (this.isDeviceExcluded(device.did)) {
          continue;
        }
        let spec: MIoTSpecInstance;
        try {
          spec = await xiaomiDataService.getDeviceSpecForDevice(device);
        } catch (err) {
          Logger.warn('load info spec failed for %{public}s, %{public}s',
            device.did, err instanceof Error ? err.message : String(err));
          continue;
        }
        const temperatureProp = this.findInfoProperty(spec, ['temperature'],
          ['target', 'set', 'color-temperature', 'colour-temperature', 'color temperature',
            'colour temperature', 'color.temperature', 'colour.temperature'],
          ['kelvin', 'k']);
        if (temperatureProp !== null) {
          const temperatureTarget: InfoPropertyTarget = {
            did: device.did,
            name: device.name,
            roomName: device.roomName,
            siid: temperatureProp.siid,
            piid: temperatureProp.piid,
            unit: temperatureProp.unit
          };
          temperatureTargets.push(temperatureTarget);
        }
        const humidityProp = this.findInfoProperty(spec, ['humidity'], ['target', 'set'], []);
        if (humidityProp !== null) {
          const humidityTarget: InfoPropertyTarget = {
            did: device.did,
            name: device.name,
            roomName: device.roomName,
            siid: humidityProp.siid,
            piid: humidityProp.piid,
            unit: humidityProp.unit
          };
          humidityTargets.push(humidityTarget);
        }
        const pm25Prop = this.findInfoProperty(spec, ['pm2.5'], [], []);
        if (pm25Prop !== null) {
          const pm25Target: InfoPropertyTarget = {
            did: device.did,
            name: device.name,
            roomName: device.roomName,
            siid: pm25Prop.siid,
            piid: pm25Prop.piid,
            unit: pm25Prop.unit
          };
          pm25Targets.push(pm25Target);
        }
        const switchProp = this.findSwitchProperty(spec);
        if (switchProp !== null) {
          const switchTarget: InfoPropertyTarget = {
            did: device.did,
            name: device.name,
            roomName: device.roomName,
            siid: switchProp.siid,
            piid: switchProp.piid,
            unit: ''
          };
          switchTargets.push(switchTarget);
        }
      }
      this.infoDeviceCount = temperatureTargets.length + humidityTargets.length +
        pm25Targets.length + switchTargets.length;
      const controller = await xiaomiDataService.getDeviceController();
      const temperatureResult = await this.fetchInfoMetric(controller, temperatureTargets);
      const humidityResult = await this.fetchInfoMetric(controller, humidityTargets);
      const pm25Result = await this.fetchInfoMetric(controller, pm25Targets);
      this.temperatureRangeText = this.formatInfoAverage(temperatureResult.range,
        this.infoUnitText(this.firstTargetUnit(temperatureTargets)));
      this.humidityRangeText = this.formatInfoAverage(humidityResult.range,
        this.infoUnitText(this.firstTargetUnit(humidityTargets)));
      this.pm25RangeText = this.formatInfoAverage(pm25Result.range,
        this.infoUnitText(this.firstTargetUnit(pm25Targets)));
      this.temperatureMoreText = this.formatInfoMore(temperatureResult.range,
        temperatureTargets.length, this.firstTargetUnit(temperatureTargets));
      this.humidityMoreText = this.formatInfoMore(humidityResult.range,
        humidityTargets.length, this.firstTargetUnit(humidityTargets));
      this.pm25MoreText = this.formatInfoMore(pm25Result.range,
        pm25Targets.length, this.firstTargetUnit(pm25Targets));
      this.temperatureDevices = temperatureResult.entries;
      this.humidityDevices = humidityResult.entries;
      this.pm25Devices = pm25Result.entries;
      const onEntries = await this.fetchSwitchOnDevices(controller, switchTargets);
      this.onDevices = onEntries;
      this.onDeviceCount = onEntries.length;
      FeedbackLogService.recordOperation('PAGE',
        `信息页内容: 温度=${this.temperatureRangeText} 湿度=${this.humidityRangeText} PM2.5=${this.pm25RangeText} 在线设备=${this.onDeviceCount} 设备总数=${familyDevices.length}`);
    } catch (err) {
      if (!silent) {
        this.infoError = err instanceof Error ? err.message : '加载信息页数据失败';
      }
      Logger.error('load info data failed, %{public}s',
        err instanceof Error ? err.message : String(err));
      if (err instanceof XiaomiAuthError) {
        await xiaomiDataService.clearSession();
        this.getUIContext().getRouter().replaceUrl({ url: 'pages/LoginPage' });
      }
    } finally {
      this.infoFetching = false;
      if (!silent) {
        this.infoLoading = false;
      }
    }
  }

  private deviceListSummary(devices: XiaomiDevice[]): string {
    const parts: string[] = [];
    for (let i = 0; i < devices.length; i++) {
      const device = devices[i];
      parts.push(`${device.name}(${device.did},${device.online ? '在线' : '离线'},${device.roomName})`);
    }
    return parts.join(' | ');
  }

  private findInfoProperty(
    spec: MIoTSpecInstance,
    keywords: string[],
    excludes: string[],
    excludeUnits: string[]
  ): InfoSpecProperty | null {
    for (let i = 0; i < spec.services.length; i++) {
      const service = spec.services[i];
      for (let j = 0; j < service.properties.length; j++) {
        const prop = service.properties[j];
        if (!prop.readable) {
          continue;
        }
        const format = prop.format.toLowerCase();
        if (format !== 'float' && format !== 'int') {
          continue;
        }
        const unitKey = prop.unit.trim().toLowerCase();
        let unitExcluded = false;
        for (let u = 0; u < excludeUnits.length; u++) {
          if (unitKey === excludeUnits[u]) {
            unitExcluded = true;
            break;
          }
        }
        if (unitExcluded) {
          continue;
        }
        const text = `${prop.name} ${prop.description} ${prop.type} ${prop.unit}`.toLowerCase()
          .split('_').join('.');
        let matched = false;
        for (let k = 0; k < keywords.length; k++) {
          if (text.includes(keywords[k])) {
            matched = true;
            break;
          }
        }
        if (!matched) {
          continue;
        }
        let excluded = false;
        for (let m = 0; m < excludes.length; m++) {
          if (text.includes(excludes[m])) {
            excluded = true;
            break;
          }
        }
        if (excluded) {
          continue;
        }
        return {
          siid: service.iid,
          piid: prop.iid,
          unit: prop.unit
        };
      }
    }
    return null;
  }

  private findSwitchProperty(spec: MIoTSpecInstance): InfoSpecProperty | null {
    for (let i = 0; i < spec.services.length; i++) {
      const service = spec.services[i];
      for (let j = 0; j < service.properties.length; j++) {
        const prop = service.properties[j];
        if (!prop.readable) {
          continue;
        }
        if (prop.format.toLowerCase() !== 'bool') {
          continue;
        }
        const text = `${prop.name} ${prop.description} ${prop.type}`.toLowerCase();
        const isPowerSwitch = text.includes('switch') || text.includes('power') ||
          prop.name === 'on';
        if (!isPowerSwitch) {
          continue;
        }
        if (text.includes('lock') || text.includes('physical control')) {
          continue;
        }
        return {
          siid: service.iid,
          piid: prop.iid,
          unit: ''
        };
      }
    }
    return null;
  }

  private async fetchSwitchOnDevices(
    controller: DeviceController,
    targets: InfoPropertyTarget[]
  ): Promise<InfoDeviceEntry[]> {
    if (targets.length === 0) {
      return [];
    }
    const params: DevicePropertyParam[] = [];
    for (let i = 0; i < targets.length; i++) {
      const param: DevicePropertyParam = {
        did: targets[i].did,
        siid: targets[i].siid,
        piid: targets[i].piid
      };
      params.push(param);
    }
    let results: DevicePropertyResult[] = [];
    try {
      results = await controller.getProperties(targets[0].did, params);
    } catch (err) {
      Logger.warn('fetch switch properties failed, %{public}s',
        err instanceof Error ? err.message : String(err));
    }
    const valueMap = new Map<string, Object | undefined>();
    for (let i = 0; i < results.length; i++) {
      const key = `${String(results[i].did)}.${results[i].siid}.${results[i].piid}`;
      valueMap.set(key, results[i].value);
    }
    const entries: InfoDeviceEntry[] = [];
    for (let i = 0; i < targets.length; i++) {
      const target = targets[i];
      const key = `${target.did}.${target.siid}.${target.piid}`;
      if (!this.isOnValue(valueMap.get(key))) {
        continue;
      }
      const entry: InfoDeviceEntry = {
        did: target.did,
        name: target.name,
        roomName: target.roomName,
        valueText: '开启'
      };
      entries.push(entry);
    }
    return entries;
  }

  private isOnValue(value: Object | undefined): boolean {
    return value === true || value === 1 || value === 'true' || value === '1';
  }

  private async fetchInfoMetric(
    controller: DeviceController,
    targets: InfoPropertyTarget[]
  ): Promise<InfoMetricResult> {
    if (targets.length === 0) {
      return {
        range: { min: 0, max: 0, count: 0, average: 0 },
        entries: []
      };
    }
    const params: DevicePropertyParam[] = [];
    for (let i = 0; i < targets.length; i++) {
      const param: DevicePropertyParam = {
        did: targets[i].did,
        siid: targets[i].siid,
        piid: targets[i].piid
      };
      params.push(param);
    }
    let results: DevicePropertyResult[] = [];
    try {
      results = await controller.getProperties(targets[0].did, params);
    } catch (err) {
      Logger.warn('fetch info properties failed, %{public}s',
        err instanceof Error ? err.message : String(err));
    }
    const valueMap = new Map<string, Object | undefined>();
    for (let i = 0; i < results.length; i++) {
      const key = `${String(results[i].did)}.${results[i].siid}.${results[i].piid}`;
      valueMap.set(key, results[i].value);
    }
    const entries: InfoDeviceEntry[] = [];
    let min = 0;
    let max = 0;
    let count = 0;
    let sum = 0;
    for (let i = 0; i < targets.length; i++) {
      const target = targets[i];
      const key = `${target.did}.${target.siid}.${target.piid}`;
      const value = Number(valueMap.get(key));
      if (Number.isNaN(value)) {
        continue;
      }
      const displayValue = this.displayTemperature(value, target.unit);
      const entry: InfoDeviceEntry = {
        did: target.did,
        name: target.name,
        roomName: target.roomName,
        valueText: `${this.formatInfoValue(displayValue)}${this.infoUnitText(this.displayTemperatureUnit(target.unit))}`
      };
      entries.push(entry);
      if (count === 0) {
        min = value;
        max = value;
      } else {
        min = Math.min(min, value);
        max = Math.max(max, value);
      }
      count++;
      sum += value;
    }
    let range: InfoMetricRange = { min: 0, max: 0, count: 0, average: 0 };
    if (count > 0) {
      range = { min: min, max: max, count: count, average: sum / count };
    }
    return {
      range: range,
      entries: entries
    };
  }

  private formatInfoRange(range: InfoMetricRange, unit: string): string {
    if (range.count === 0) {
      return '--';
    }
    const minText = this.formatInfoValue(this.displayTemperature(range.min, unit));
    const maxText = this.formatInfoValue(this.displayTemperature(range.max, unit));
    const displayUnit = this.infoUnitText(this.displayTemperatureUnit(unit));
    if (displayUnit.length === 0) {
      return `${minText} - ${maxText}`;
    }
    return `${minText}${displayUnit} - ${maxText}${displayUnit}`;
  }

  /** 概览卡主数值：取全部设备平均值 */
  private formatInfoAverage(range: InfoMetricRange, unit: string): string {
    if (range.count === 0) {
      return '--';
    }
    const average = this.displayTemperature(range.average, unit);
    const displayUnit = this.infoUnitText(this.displayTemperatureUnit(unit));
    return `${this.formatInfoValue(average)}${displayUnit}`;
  }

  private formatInfoMore(range: InfoMetricRange, deviceCount: number, unit: string): string {
    if (deviceCount === 0 || range.count === 0) {
      return '';
    }
    const average = this.displayTemperature(range.average, unit);
    const displayUnit = this.infoUnitText(this.displayTemperatureUnit(unit));
    return `共 ${deviceCount} 台设备 · 平均 ${average.toFixed(1)}${displayUnit}`;
  }

  private formatInfoValue(value: number): string {
    return Number.isInteger(value) ? String(value) : value.toFixed(1);
  }

  private firstTargetUnit(targets: InfoPropertyTarget[]): string {
    return targets.length > 0 ? targets[0].unit : '';
  }

  private displayTemperature(value: number, unit: string): number {
    if (!this.temperatureFahrenheit) {
      return value;
    }
    return isCelsiusUnit(unit) ? celsiusToFahrenheit(value) : value;
  }

  private displayTemperatureUnit(unit: string): string {
    if (!this.temperatureFahrenheit) {
      return unit;
    }
    return isCelsiusUnit(unit) ? 'fahrenheit' : unit;
  }

  private infoUnitText(unit: string): string {
    const key = unit.trim().toLowerCase();
    if (key === 'celsius') {
      return '°C';
    }
    if (key === 'fahrenheit') {
      return '°F';
    }
    if (key === 'percentage' || key === 'percent') {
      return '%';
    }
    if (key === 'ug/m3' || key === 'ug/m³') {
      return 'μg/m³';
    }
    return unit;
  }

  private openDeviceFromSheet(did: string): void {
    if (this.pendingDeviceDid.length > 0) {
      return;
    }
    this.pendingDeviceDid = did;
    this.closeInfoSheets();
    setTimeout(() => {
      this.pendingDeviceDid = '';
      this.pageInfos.pushPathByName('deviceDetail', new DeviceDetailRouteParam(did));
    }, 300);
  }

  private closeInfoSheets(): void {
    this.showTemperatureSheet = false;
    this.showHumiditySheet = false;
    this.showPm25Sheet = false;
    this.showOnSheet = false;
  }

  private isDeviceExcluded(did: string): boolean {
    return this.infoExcludedDevices.indexOf(did) >= 0;
  }

  private setDeviceExcluded(did: string, excluded: boolean): void {
    const next: string[] = this.infoExcludedDevices.slice();
    const idx = next.indexOf(did);
    if (excluded && idx < 0) {
      next.push(did);
    }
    if (!excluded && idx >= 0) {
      next.splice(idx, 1);
    }
    this.infoExcludedDevices = next;
    AppSettingsStore.setStringArray('infoExcludedDevices', next);
  }

  private selectAllHomesFromSheet(): void {
    this.selectedHomeId = ALL_HOMES_ID;
    this.selectedHomeName = ALL_HOMES_NAME;
    AppSettingsStore.setString('selectedHomeId', ALL_HOMES_ID);
    AppSettingsStore.setString('selectedHomeName', ALL_HOMES_NAME);
    this.homeSelectionVersion = this.homeSelectionVersion + 1;
    this.showFamilySheet = false;
  }

  private selectHomeFromSheet(home: XiaomiHome): void {
    this.selectedHomeId = home.homeId;
    this.selectedHomeName = home.name;
    AppSettingsStore.setString('selectedHomeId', home.homeId);
    AppSettingsStore.setString('selectedHomeName', home.name);
    this.homeSelectionVersion = this.homeSelectionVersion + 1;
    this.showFamilySheet = false;
  }

  private refreshInfoOnEnter(): void {
    const now = Date.now();
    if (now - this.lastInfoRefreshAt < 1000) {
      return;
    }
    this.lastInfoRefreshAt = now;
    this.loadInfoData(true);
  }

  private startInfoRefreshTimer(): void {
    this.stopInfoRefreshTimer();
    const seconds = this.infoRefreshIntervalSeconds();
    this.infoRefreshTimer = setInterval(() => {
      if (this.activeTab === 0) {
        this.refreshInfoOnEnter();
      }
    }, seconds * 1000);
  }

  private stopInfoRefreshTimer(): void {
    if (this.infoRefreshTimer >= 0) {
      clearInterval(this.infoRefreshTimer);
      this.infoRefreshTimer = -1;
    }
  }

  private infoRefreshIntervalSeconds(): number {
    const value = Number(this.infoRefreshInterval);
    // 实时状态与推送频率不低于 30 秒，防止高频请求压垮设备/云端
    return Number.isNaN(value) || value < 30 ? 30 : value;
  }

  private topOffset(): number {
    return (this.isWearable ? 64 : CONTENT_TOP_OFFSET) + this.statusBarHeight;
  }

  private contentPadding(): number {
    return this.isWearable ? 12 : 20;
  }

  onInfoRefreshIntervalChanged(): void {
    if (this.activeTab === 0) {
      this.startInfoRefreshTimer();
    }
  }

  onTemperatureUnitChanged(): void {
    if (this.activeTab === 0) {
      this.loadInfoData(true);
    }
  }

  deviceLocation(device: XiaomiDevice): string {
    if (this.selectedHomeId === ALL_HOMES_ID) {
      const homeTitle = this.homeTitleForDevice(device);
      const localTitle = this.localRoomTitleForDevice(device);
      if (localTitle.length > 0) {
        return `${homeTitle} · ${localTitle}`;
      }
      if (device.roomName.length > 0) {
        return `${homeTitle} · ${device.roomName}`;
      }
      return homeTitle;
    }
    const localTitle = this.localRoomTitleForDevice(device);
    if (localTitle.length > 0) {
      return localTitle;
    }
    return device.roomName;
  }

  private homeTitleForDevice(device: XiaomiDevice): string {
    const homeName = device.homeName;
    if (homeName.length === 0) {
      return '我的家';
    }
    if (homeName.endsWith('家')) {
      return homeName;
    }
    return `${homeName}的家`;
  }

  private localRoomTitleForDevice(device: XiaomiDevice): string {
    for (let i = 0; i < this.localRooms.length; i++) {
      const room = this.localRooms[i];
      if (room.dids.indexOf(device.did) >= 0) {
        return `${room.floor}楼 ${room.name}`;
      }
    }
    return '';
  }

  private sortVisibleDevices(devices: XiaomiDevice[]): XiaomiDevice[] {
    const working = devices.slice();
    if (!this.sortDevicesByRoom) {
      working.sort((a: XiaomiDevice, b: XiaomiDevice): number => {
        const aOnline = a.online ? 1 : 0;
        const bOnline = b.online ? 1 : 0;
        return bOnline - aOnline;
      });
      return working;
    }
    const result: XiaomiDevice[] = [];
    const added = new Set<string>();
    for (let i = 0; i < this.localRooms.length; i++) {
      const room = this.localRooms[i];
      const roomDevices: XiaomiDevice[] = [];
      for (let j = 0; j < room.dids.length; j++) {
        const did = room.dids[j];
        if (added.has(did)) {
          continue;
        }
        const matched = this.findDeviceByDid(working, did);
        if (matched !== null) {
          roomDevices.push(matched);
          added.add(did);
        }
      }
      roomDevices.sort((a: XiaomiDevice, b: XiaomiDevice): number => {
        const aOnline = a.online ? 1 : 0;
        const bOnline = b.online ? 1 : 0;
        return bOnline - aOnline;
      });
      for (let k = 0; k < roomDevices.length; k++) {
        result.push(roomDevices[k]);
      }
    }
    const rest: XiaomiDevice[] = [];
    for (let i = 0; i < working.length; i++) {
      if (!added.has(working[i].did)) {
        rest.push(working[i]);
      }
    }
    rest.sort((a: XiaomiDevice, b: XiaomiDevice): number => {
      const aOnline = a.online ? 1 : 0;
      const bOnline = b.online ? 1 : 0;
      return bOnline - aOnline;
    });
    for (let k = 0; k < rest.length; k++) {
      result.push(rest[k]);
    }
    return result;
  }

  private findDeviceByDid(devices: XiaomiDevice[], did: string): XiaomiDevice | null {
    for (let i = 0; i < devices.length; i++) {
      if (devices[i].did === did) {
        return devices[i];
      }
    }
    return null;
  }

  private currentHome(): XiaomiHome | null {
    for (let i = 0; i < this.homes.length; i++) {
      if (this.homes[i].homeId === this.selectedHomeId) {
        return this.homes[i];
      }
    }
    return null;
  }

  private findChip(key: string): RoomChip | null {
    for (let i = 0; i < this.roomChips.length; i++) {
      if (this.roomChips[i].key === key) {
        return this.roomChips[i];
      }
    }
    return null;
  }

  private deviceMatchesCandidate(device: XiaomiDevice, candidate: RoomCandidate): boolean {
    if (candidate.roomId.length > 0 && device.roomId === candidate.roomId) {
      return true;
    }
    if (candidate.name.length > 0 && device.roomName === candidate.name) {
      return true;
    }
    if (candidate.dids.indexOf(device.did) >= 0) {
      return true;
    }
    return false;
  }

  private rebuildRoomChips(): void {
    const chips: RoomChip[] = [];
    chips.push({
      key: ROOM_ALL_KEY,
      name: '全屋',
      roomId: '',
      dids: [],
      count: this.allVisibleDevices.length
    });
    const source = this.allVisibleDevices;
    const candidates: RoomCandidate[] = [];
    const knownNames = new Set<string>();
    const home = this.currentHome();
    if (home !== null) {
      for (let i = 0; i < home.roomList.length; i++) {
        const room = home.roomList[i];
        if (knownNames.has(room.name)) {
          continue;
        }
        knownNames.add(room.name);
        candidates.push({
          key: `room_${room.roomId}`,
          name: room.name,
          roomId: room.roomId,
          dids: room.dids.slice()
        });
      }
    }
    for (let i = 0; i < source.length; i++) {
      const name = source[i].roomName.trim();
      if (name.length === 0 || knownNames.has(name)) {
        continue;
      }
      knownNames.add(name);
      candidates.push({
        key: `name_${name}`,
        name: name,
        roomId: '',
        dids: []
      });
    }
    const consumed = new Set<string>();
    for (let i = 0; i < candidates.length; i++) {
      const candidate = candidates[i];
      const dids: string[] = [];
      for (let j = 0; j < source.length; j++) {
        const device = source[j];
        if (consumed.has(device.did)) {
          continue;
        }
        if (!this.deviceMatchesCandidate(device, candidate)) {
          continue;
        }
        dids.push(device.did);
        consumed.add(device.did);
      }
      if (dids.length > 0) {
        chips.push({
          key: candidate.key,
          name: candidate.name,
          roomId: candidate.roomId,
          dids: dids,
          count: dids.length
        });
      }
    }
    const unroomed: string[] = [];
    for (let i = 0; i < source.length; i++) {
      if (!consumed.has(source[i].did)) {
        unroomed.push(source[i].did);
      }
    }
    if (unroomed.length > 0) {
      chips.push({
        key: ROOM_UNROOMED_KEY,
        name: '未分类',
        roomId: '',
        dids: unroomed,
        count: unroomed.length
      });
    }
    this.roomChips = chips;
  }

  private updateFilteredDevices(): void {
    if (this.selectedRoomKey === ROOM_ALL_KEY) {
      this.filteredDevices = this.devices;
      return;
    }
    const chip = this.findChip(this.selectedRoomKey);
    if (chip === null) {
      this.filteredDevices = this.devices;
      return;
    }
    const next: XiaomiDevice[] = [];
    for (let i = 0; i < this.devices.length; i++) {
      if (chip.dids.indexOf(this.devices[i].did) >= 0) {
        next.push(this.devices[i]);
      }
    }
    this.filteredDevices = next;
  }

  private selectRoom(key: string): void {
    if (this.selectedRoomKey === key) {
      return;
    }
    this.selectedRoomKey = key;
    FeedbackLogService.recordOperation('UI', `切换房间 ${key}`);
    this.updateFilteredDevices();
    if (key === ROOM_ALL_KEY) {
      this.refreshInfoOnEnter();
    }
  }

  pageTitle(): string {
    if (this.activeTab === 0) {
      return this.selectedHomeName.length > 0 ? this.selectedHomeName : '我的家庭';
    }
    if (this.activeTab === 1) {
      return '智能';
    }
    if (this.activeTab === 2) {
      return '信息提醒';
    }
    return '我的';
  }

  onBreakpointChange(): void {
    const wideBp: boolean = this.widthBp === WidthBreakpoint.WIDTH_LG ||
      this.widthBp === WidthBreakpoint.WIDTH_XL;
    const wide: boolean = wideBp && this.pcLayoutEnabled;
    if (wide !== this.isWideScreen) {
      this.isWideScreen = wide;
      if (wide) {
        this.sideBarWidth = SIDE_BAR_WIDTH_DEFAULT;
      }
    }
  }

  private refreshCurrentTab(): void {
    if (this.isWearable && this.activeTab === 1) {
      this.loadData(true, true);
      this.loadAccount();
      return;
    }
    if (this.activeTab === 1) {
      this.loadScenes(false);
    } else if (this.activeTab === 2) {
      this.buildAlerts();
    } else if (this.activeTab === 3) {
      this.loadData(true, true);
      this.loadAccount();
    } else {
      this.refreshHomeData();
    }
  }

  private tabLabel(index: number): string {
    if (index === 0) {
      return '首页';
    }
    if (index === 1 && this.isWearable) {
      return '我的';
    }
    if (index === 1) {
      return '智能';
    }
    if (index === 2) {
      return '信息提醒';
    }
    return '我的';
  }

  @Builder
  tabIcon(index: number) {
    if (index === 0) {
      SymbolGlyph(this.activeTab === 0 ? $r('sys.symbol.house_fill') : $r('sys.symbol.house'))
        .fontSize(24)
        .fontColor([this.activeTab === 0 ? HwColor.primary : HwColor.textSecondary])
    } else if (index === 1 && this.isWearable) {
      SymbolGlyph((this.activeTab === 1 || this.activeTab === 3)
        ? $r('sys.symbol.person_fill') : $r('sys.symbol.person'))
        .fontSize(24)
        .fontColor([(this.activeTab === 1 || this.activeTab === 3)
          ? HwColor.primary : HwColor.textSecondary])
    } else if (index === 1) {
      SymbolGlyph(this.activeTab === 1 ? $r('sys.symbol.bolt_fill') : $r('sys.symbol.bolt'))
        .fontSize(24)
        .fontColor([this.activeTab === 1 ? HwColor.primary : HwColor.textSecondary])
    } else if (index === 2) {
      SymbolGlyph(this.activeTab === 2 ? $r('sys.symbol.bell_fill') : $r('sys.symbol.bell'))
        .fontSize(24)
        .fontColor([this.activeTab === 2 ? HwColor.primary : HwColor.textSecondary])
    } else {
      SymbolGlyph(this.activeTab === 3 ? $r('sys.symbol.person_fill') : $r('sys.symbol.person'))
        .fontSize(24)
        .fontColor([this.activeTab === 3 ? HwColor.primary : HwColor.textSecondary])
    }
  }

  @Builder
  tabItem(index: number) {
    Column({ space: 4 }) {
      this.tabIcon(index)
      Text(this.tabLabel(index))
        .fontFamily(this.appFontFamily(this.tabLabel(index)))
        .fontWeight(this.appFontWeight())
        .fontSize(12)
        .fontColor(this.activeTab === index ? HwColor.primary : HwColor.textSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(this.isWideScreen ? 64 : 56)
    .justifyContent(FlexAlign.Center)
  }

  tabBarStyle(index: number): BottomTabBarStyle {
    if (index === 0) {
      const homeNormal = new SymbolGlyphModifier($r('sys.symbol.house'));
      homeNormal.fontColor([HwColor.textSecondary]);
      const homeSelected = new SymbolGlyphModifier($r('sys.symbol.house_fill'));
      homeSelected.fontColor([HwColor.primary]);
      return new BottomTabBarStyle({ normal: homeNormal, selected: homeSelected }, '首页');
    }
    if (index === 1 && this.isWearable) {
      const mineNormal = new SymbolGlyphModifier($r('sys.symbol.person'));
      mineNormal.fontColor([HwColor.textSecondary]);
      const mineSelected = new SymbolGlyphModifier($r('sys.symbol.person_fill'));
      mineSelected.fontColor([HwColor.primary]);
      return new BottomTabBarStyle({ normal: mineNormal, selected: mineSelected }, '我的');
    }
    if (index === 1) {
      const smartNormal = new SymbolGlyphModifier($r('sys.symbol.bolt'));
      smartNormal.fontColor([HwColor.textSecondary]);
      const smartSelected = new SymbolGlyphModifier($r('sys.symbol.bolt_fill'));
      smartSelected.fontColor([HwColor.primary]);
      return new BottomTabBarStyle({ normal: smartNormal, selected: smartSelected }, '智能');
    }
    if (index === 2) {
      const alertNormal = new SymbolGlyphModifier($r('sys.symbol.bell'));
      alertNormal.fontColor([HwColor.textSecondary]);
      const alertSelected = new SymbolGlyphModifier($r('sys.symbol.bell_fill'));
      alertSelected.fontColor([HwColor.primary]);
      return new BottomTabBarStyle({ normal: alertNormal, selected: alertSelected }, '信息提醒');
    }
    const mineNormal = new SymbolGlyphModifier($r('sys.symbol.person'));
    mineNormal.fontColor([HwColor.textSecondary]);
    const mineSelected = new SymbolGlyphModifier($r('sys.symbol.person_fill'));
    mineSelected.fontColor([HwColor.primary]);
    return new BottomTabBarStyle({ normal: mineNormal, selected: mineSelected }, '我的');
  }

  @Builder
  tabHeader() {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text(this.pageTitle())
          .fontFamily(this.appFontFamily(this.pageTitle()))
          .fontWeight(this.appFontWeight())
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(HwColor.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.activeTab === 0 && this.selectedHomeName.length > 0) {
          Text(this.selectedHomeName)
            .fontFamily(this.appFontFamily(this.selectedHomeName))
            .fontWeight(this.appFontWeight())
            .fontSize(12)
            .fontColor(HwColor.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.activeTab === 0) {
        IconCircleButton({
          symbol: $r('sys.symbol.house'),
          buttonSize: 36,
          iconSize: 18,
          onAction: (): void => {
            FeedbackLogService.recordOperation('UI', '打开选择家庭');
            this.showFamilySheet = true;
          }
        })
      } else if (this.activeTab === 1) {
        IconCircleButton({
          symbol: $r('sys.symbol.arrow_counterclockwise'),
          buttonSize: 36,
          iconSize: 18,
          buttonEnabled: !this.scenesLoading,
          onAction: (): void => {
            FeedbackLogService.recordOperation('UI', '刷新智能页');
            this.loadScenes(false);
          }
        })
      } else if (this.activeTab === 2) {
        IconCircleButton({
          symbol: $r('sys.symbol.arrow_counterclockwise'),
          buttonSize: 36,
          iconSize: 18,
          buttonEnabled: !this.alertsLoading,
          onAction: (): void => {
            FeedbackLogService.recordOperation('UI', '刷新信息提醒页');
            this.buildAlerts();
          }
        })
      }
    }
    .width('100%')
    .height(56 + this.statusBarHeight)
    .padding({ left: 20, right: 20, top: this.statusBarHeight })
  }

  private isRouterDevice(device: XiaomiDevice): boolean {
    return device.model.includes('router') || device.name.includes('路由');
  }

  private showRouterWarningDialog(did: string): void {
    this.getUIContext().showAlertDialog({
      title: '警告',
      message: '本软件暂不支持控制路由器，但您仍可手动修改这些参数',
      primaryButton: {
        value: '取消',
        fontColor: HwColor.primary,
        action: (): void => {
        }
      },
      secondaryButton: {
        value: '我已知悉风险并继续',
        fontColor: HwColor.danger,
        action: (): void => {
          this.pageInfos.pushPathByName('deviceDetail', new DeviceDetailRouteParam(did));
        }
      }
    });
  }

  @Builder
  roomChip(chip: RoomChip) {
    Row({ space: 5 }) {
      Text(chip.name)
        .fontFamily(this.appFontFamily(chip.name))
        .fontWeight(this.appFontWeight())
        .fontSize(14)
        .fontColor(this.selectedRoomKey === chip.key ? HwColor.primary : Color.White)
        .maxLines(1)
      Text(String(chip.count))
        .fontFamily(this.appFontFamily(String(chip.count)))
        .fontWeight(this.appFontWeight())
        .fontSize(11)
        .fontColor(this.selectedRoomKey === chip.key ? HwColor.primary : Color.White)
        .opacity(0.75)
        .maxLines(1)
    }
    .height(32)
    .padding({ left: 14, right: 14 })
    .borderRadius(16)
    .backgroundColor(this.selectedRoomKey === chip.key ? Color.White : '#33FFFFFF')
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.selectRoom(chip.key);
    })
  }

  @Builder
  roomChipBar() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(this.roomChips, (chip: RoomChip) => {
          this.roomChip(chip)
        }, (chip: RoomChip) => chip.key)
      }
      .height(36)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 20, right: 20 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .width('100%')
    .height(36)
  }

  @Builder
  homeHeader() {
    Column() {
      Row({ space: 6 }) {
        Row({ space: 4 }) {
          Text(this.pageTitle())
            .fontFamily(this.appFontFamily(this.pageTitle()))
            .fontWeight(this.appFontWeight())
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(14)
            .fontColor([Color.White])
            .opacity(0.85)
        }
        .height(40)
        .padding({ left: 8, right: 8 })
        .alignItems(VerticalAlign.Center)
        .layoutWeight(1)
        .onClick(() => {
          FeedbackLogService.recordOperation('UI', '点击家庭名选择家庭');
          this.showFamilySheet = true;
        })
      }
      .width('100%')
      .height(52)
      .padding({ left: 20, right: 20 })
      .alignItems(VerticalAlign.Center)

      if (this.roomChips.length > 1) {
        this.roomChipBar()
      }
    }
    .width('100%')
    .linearGradient({
      angle: 90,
      colors: [[MijiaHeaderGradient[0], 0], [MijiaHeaderGradient[1], 0.5], [MijiaHeaderGradient[2], 1]]
    })
    .height(this.statusBarHeight + 96)
    .padding({ top: this.statusBarHeight })
  }

  @Styles
  overviewCardPressedStyle() {
    .backgroundColor(MijiaOverviewCardPressed)
  }

  /** 按设备型号/名称关键字映射系统符号，避免设备图标全是灯泡 */
  private deviceSymbol(device: XiaomiDevice): Resource {
    const text = `${device.model} ${device.name}`.toLowerCase();
    if (text.includes('acpartner') || text.includes('airconditioner') || text.includes('air_conditioner') ||
      text.includes('空调')) {
      return $r('sys.symbol.snowflake');
    }
    if (text.includes('humidifier') || text.includes('dehumidifier') || text.includes('加湿') || text.includes('除湿')) {
      return $r('sys.symbol.drop_fill');
    }
    if (text.includes('airpurifier') || text.includes('air_purifier') || text.includes('净化')) {
      return $r('sys.symbol.air');
    }
    if (text.includes('vacuum') || text.includes('rockrobo') || text.includes('mop') || text.includes('扫地') ||
      text.includes('拖地')) {
      return $r('sys.symbol.robot');
    }
    if (text.includes('camera') || text.includes('ipc') || text.includes('cctv') || text.includes('摄像头') ||
      text.includes('监控')) {
      return $r('sys.symbol.video');
    }
    if (text.includes('lock') || text.includes('门锁')) {
      return $r('sys.symbol.lock');
    }
    if (text.includes('speaker') || text.includes('sound') || text.includes('aiplayer') || text.includes('play') ||
      text.includes('音箱') || text.includes('音响')) {
      return $r('sys.symbol.speaker');
    }
    if (text.includes('curtain') || text.includes('窗帘')) {
      return $r('sys.symbol.curtain');
    }
    if (text.includes('socket') || text.includes('plug') || text.includes('插座') || text.includes('排插')) {
      return $r('sys.symbol.power');
    }
    if (text.includes('router') || text.includes('路由')) {
      return $r('sys.symbol.wifi_router');
    }
    if (text.includes('washer') || text.includes('洗衣') || text.includes('烘干')) {
      return $r('sys.symbol.washer');
    }
    if (text.includes('projector') || text.includes('投影')) {
      return $r('sys.symbol.display');
    }
    if (text.includes('tv ') || text.endsWith('tv') || text.includes('television') || text.includes('电视')) {
      return $r('sys.symbol.display');
    }
    if (text.includes('fan') || text.includes('风扇')) {
      return $r('sys.symbol.wind');
    }
    if (text.includes('heater') || text.includes('暖') || text.includes('加热')) {
      return $r('sys.symbol.thermometer');
    }
    if (text.includes('bath') || text.includes('浴') || text.includes('热水器') || text.includes('花洒')) {
      return $r('sys.symbol.bath');
    }
    if (text.includes('toilet') || text.includes('马桶')) {
      return $r('sys.symbol.toilet');
    }
    if (text.includes('fridge') || text.includes('冰箱')) {
      return $r('sys.symbol.snowflake');
    }
    if (text.includes('kettle') || text.includes('烧水') || text.includes('水壶')) {
      return $r('sys.symbol.thermometer');
    }
    if (text.includes('bed') || text.includes('床')) {
      return $r('sys.symbol.moon_fill');
    }
    if (text.includes('sensor') || text.includes('传感器') || text.includes('感应')) {
      return $r('sys.symbol.signal');
    }
    if (text.includes('switch') || text.includes('开关')) {
      return $r('sys.symbol.light');
    }
    if (text.includes('lamp') || text.includes('light') || text.includes('yeelight') || text.includes('bulb') ||
      text.includes('灯')) {
      return $r('sys.symbol.lightbulb');
    }
    return $r('sys.symbol.lightbulb');
  }

  @Builder
  overviewCard($$: OverviewCardConfig) {
    Column({ space: 6 }) {
      SymbolGlyph($$.icon)
        .fontSize(20)
        .fontColor([MijiaOverviewCardValue])
      Text($$.title)
        .fontFamily(this.appFontFamily($$.title))
        .fontWeight(this.appFontWeight())
        .fontSize(12)
        .fontColor(MijiaOverviewCardText)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text($$.rangeText)
        .fontFamily(this.appFontFamily($$.rangeText))
        .fontWeight(this.appFontWeight())
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(MijiaOverviewCardValue)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      if (this.infoShowMoreContent && $$.moreText.length > 0) {
        Text($$.moreText)
          .fontFamily(this.appFontFamily($$.moreText))
          .fontWeight(this.appFontWeight())
          .fontSize(10)
          .fontColor(MijiaOverviewCardText)
          .opacity(0.7)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
    }
    .width('100%')
    .height(118)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
    .padding(12)
    .borderRadius(HwRadius.card)
    .backgroundColor(MijiaOverviewCard)
    .stateStyles({ pressed: this.overviewCardPressedStyle })
  }

  @Builder
  deviceGridCard(device: XiaomiDevice) {
    Column({ space: 6 }) {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          if (device.icon.length > 0) {
            Image(device.icon)
              .width(44)
              .height(44)
              .objectFit(ImageFit.Contain)
          } else {
            SymbolGlyph(this.deviceSymbol(device))
              .fontSize(24)
              .fontColor([MijiaOverviewCardValue])
          }
        }
        .width(48)
        .height(48)
        .borderRadius(12)
        .backgroundColor('#5C6876')
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)

      Text(device.name)
        .fontFamily(this.appFontFamily(device.name))
        .fontWeight(this.appFontWeight())
        .fontSize(15)
        .fontColor(Color.White)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Row({ space: 4 }) {
        Column()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor(device.online ? HwColor.online : '#8A93A2')
        Text(this.deviceLocation(device).length > 0 ? this.deviceLocation(device) : (device.online ? '在线' : '离线'))
          .fontFamily(this.appFontFamily(this.deviceLocation(device).length > 0 ? this.deviceLocation(device) : (device.online ? '在线' : '离线')))
          .fontWeight(this.appFontWeight())
          .fontSize(11)
          .fontColor(MijiaOverviewCardText)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .padding(12)
    .borderRadius(HwRadius.card)
    .backgroundColor(MijiaOverviewCard)
    .stateStyles({
      pressed: {
        .opacity(0.75)
      },
      normal: {
        .opacity(1)
      }
    })
    .onClick(() => {
      FeedbackLogService.recordOperation('UI', `点击设备 ${device.name} (${device.did})`);
      if (this.isRouterDevice(device)) {
        this.showRouterWarningDialog(device.did);
      } else {
        this.pageInfos.pushPathByName('deviceDetail', new DeviceDetailRouteParam(device.did));
      }
    })
  }

  @Builder
  homeTabContent() {
    Column({ space: 12 }) {
      Blank().height(this.isWideScreen ? 12 : (this.isWearable ? this.topOffset() : 0))

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
      if (this.statusMessage.length > 0) {
        Text(this.statusMessage)
          .fontFamily(this.appFontFamily(this.statusMessage))
          .fontWeight(this.appFontWeight())
          .fontSize(14)
          .fontColor(HwColor.primary)
      }
      if (!this.loading && this.errorMessage.length === 0 && this.devices.length > 0 && this.filteredDevices.length === 0) {
        Text(this.selectedRoomKey === ROOM_ALL_KEY ? '没有设备' : '该房间暂无设备')
          .fontFamily(this.appFontFamily(this.selectedRoomKey === ROOM_ALL_KEY ? '没有设备' : '该房间暂无设备'))
          .fontWeight(this.appFontWeight())
          .fontSize(14)
          .fontColor(HwColor.textSecondary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 24, bottom: 24 })
      }

      if (this.selectedRoomKey === ROOM_ALL_KEY) {
        Flex({
          wrap: FlexWrap.Wrap,
          justifyContent: FlexAlign.SpaceBetween,
          alignItems: ItemAlign.Start
        }) {
          Column() {
            this.overviewCard({
              title: '温度',
              rangeText: this.temperatureRangeText,
              moreText: this.temperatureMoreText,
              sheetIndex: 0,
              icon: $r('sys.symbol.thermometer')
            })
          }
          .width('48.5%')
          .margin({ bottom: 12 })
          .onClick(() => {
            this.showTemperatureSheet = true;
          })
          .bindSheet($$this.showTemperatureSheet, this.temperatureDeviceSheet(), {
            height: SheetSize.MEDIUM,
            dragBar: true,
            backgroundColor: MijiaSheetBackground,
            showClose: false,
          })

          Column() {
            this.overviewCard({
              title: '湿度',
              rangeText: this.humidityRangeText,
              moreText: this.humidityMoreText,
              sheetIndex: 1,
              icon: $r('sys.symbol.drop')
            })
          }
          .width('48.5%')
          .margin({ bottom: 12 })
          .onClick(() => {
            this.showHumiditySheet = true;
          })
          .bindSheet($$this.showHumiditySheet, this.humidityDeviceSheet(), {
            height: SheetSize.MEDIUM,
            dragBar: true,
            backgroundColor: MijiaSheetBackground,
            showClose: false,
          })

          Column() {
            this.overviewCard({
              title: 'PM2.5',
              rangeText: this.pm25RangeText,
              moreText: this.pm25MoreText,
              sheetIndex: 2,
              icon: $r('sys.symbol.leaf')
            })
          }
          .width('48.5%')
          .margin({ bottom: 12 })
          .onClick(() => {
            this.showPm25Sheet = true;
          })
          .bindSheet($$this.showPm25Sheet, this.pm25DeviceSheet(), {
            height: SheetSize.MEDIUM,
            dragBar: true,
            backgroundColor: MijiaSheetBackground,
            showClose: false,
          })

          Column() {
            this.overviewCard({
              title: '开启中',
              rangeText: `${this.onDeviceCount} 台`,
              moreText: '',
              sheetIndex: 3,
              icon: $r('sys.symbol.power')
            })
          }
          .width('48.5%')
          .margin({ bottom: 12 })
          .onClick(() => {
            this.showOnSheet = true;
          })
          .bindSheet($$this.showOnSheet, this.onDeviceSheet(), {
            height: SheetSize.MEDIUM,
            dragBar: true,
            backgroundColor: MijiaSheetBackground,
            showClose: false,
          })
        }
        .width('100%')
      }

      Flex({
        wrap: FlexWrap.Wrap,
        justifyContent: FlexAlign.SpaceBetween,
        alignItems: ItemAlign.Start
      }) {
        ForEach(this.filteredDevices, (device: XiaomiDevice) => {
          Column() {
            this.deviceGridCard(device)
          }
          .width('48.5%')
          .margin({ bottom: 12 })
        }, (device: XiaomiDevice) => device.did)
      }
      .width('100%')

      Blank()
        .height(this.isWideScreen ? 24 : BOTTOM_BAR_HEIGHT + BOTTOM_BAR_MARGIN + this.navigationBarHeight + 24)
    }
    .width('100%')
    .constraintSize({
      maxWidth: this.isWideScreen ? MAX_CONTENT_WIDTH : '100%'
    })
    .padding({ left: this.contentPadding(), right: this.contentPadding() })
  }

  @Builder
  mineTabContent() {
    Column({ space: 14 }) {
      Blank().height(this.isWideScreen ? 12 : this.topOffset())

      Column({ space: 12 }) {
        Row({ space: 12 }) {
          if (this.accountAvatarUrl.length > 0) {
            Image(this.accountAvatarUrl)
              .width(56)
              .height(56)
              .borderRadius(28)
              .objectFit(ImageFit.Cover)
          } else {
            Stack({ alignContent: Alignment.Center }) {
              SymbolGlyph($r('sys.symbol.person_fill'))
                .fontSize(28)
                .fontColor([MijiaOverviewCardText])
            }
            .width(56)
            .height(56)
            .borderRadius(28)
            .backgroundColor('#5C6876')
          }
          Column({ space: 4 }) {
            Text(this.accountNickname || '已登录用户')
              .fontFamily(this.appFontFamily(this.accountNickname || '已登录用户'))
              .fontWeight(this.appFontWeight())
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.accountUserId || '未获取到账号')
              .fontFamily(this.appFontFamily(this.accountUserId || '未获取到账号'))
              .fontWeight(this.appFontWeight())
              .fontSize(13)
              .fontColor(MijiaOverviewCardText)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Divider()
          .color('#24FFFFFF')
          .margin({ top: HwSpace.md, bottom: HwSpace.md })

        Row({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.arrow_right_to_line'))
            .fontSize(18)
            .fontColor([HwColor.danger])
          Text('退出登录')
            .fontFamily(this.appFontFamily('退出登录'))
            .fontWeight(this.appFontWeight())
            .fontSize(15)
            .fontColor(HwColor.danger)
            .layoutWeight(1)
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(16)
            .fontColor([MijiaOverviewCardText])
        }
        .width('100%')
        .hoverEffect(HoverEffect.Highlight)
        .onClick(() => {
          this.showLogoutDialog();
        })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(HwSpace.lg)
      .borderRadius(HwRadius.card)
      .backgroundColor(MijiaOverviewCard)
      .border({ width: 1, color: '#24FFFFFF' })
      .clip(true)

      Column() {
        Row({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.house_fill'))
            .fontSize(20)
            .fontColor([Color.White])
          Text('房间管理')
            .fontFamily(this.appFontFamily('房间管理'))
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
        .hoverEffect(HoverEffect.Highlight)
        .onClick(() => {
          FeedbackLogService.recordOperation('UI', '进入房间管理页');
          this.getUIContext().getRouter().pushUrl({ url: 'pages/RoomsPage' });
        })

        Divider()
          .color('#24FFFFFF')
          .margin({ left: HwSpace.lg, right: HwSpace.lg })

        Row({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.gearshape'))
            .fontSize(20)
            .fontColor([Color.White])
          Text('设备管理')
            .fontFamily(this.appFontFamily('设备管理'))
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
        .hoverEffect(HoverEffect.Highlight)
        .onClick(() => {
          FeedbackLogService.recordOperation('UI', '进入设备管理页');
          this.pageInfos.pushPathByName('deviceManage', new DeviceManageRouteParam());
        })
      }
      .width('100%')
      .borderRadius(HwRadius.card)
      .backgroundColor(MijiaOverviewCard)
      .border({ width: 1, color: '#24FFFFFF' })
      .clip(true)

      Column() {
        Row({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.gearshape'))
            .fontSize(20)
            .fontColor([Color.White])
          Text('设置')
            .fontFamily(this.appFontFamily('设置'))
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
        .hoverEffect(HoverEffect.Highlight)
        .onClick(() => {
          FeedbackLogService.recordOperation('UI', '进入设置页');
          this.getUIContext().getRouter().pushUrl({ url: 'pages/SettingsPage' });
        })

        Divider()
          .color('#24FFFFFF')
          .margin({ left: HwSpace.lg, right: HwSpace.lg })

        Row({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.envelope'))
            .fontSize(20)
            .fontColor([Color.White])
          Text('反馈')
            .fontFamily(this.appFontFamily('反馈'))
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
        .hoverEffect(HoverEffect.Highlight)
        .onClick(() => {
          FeedbackLogService.recordOperation('UI', '进入反馈页');
          this.getUIContext().getRouter().pushUrl({ url: 'pages/FeedbackPage' });
        })

        Divider()
          .color('#24FFFFFF')
          .margin({ left: HwSpace.lg, right: HwSpace.lg })

        Row({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.info_circle'))
            .fontSize(20)
            .fontColor([Color.White])
          Text('关于')
            .fontFamily(this.appFontFamily('关于'))
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
        .hoverEffect(HoverEffect.Highlight)
        .onClick(() => {
          FeedbackLogService.recordOperation('UI', '进入关于页');
          this.getUIContext().getRouter().pushUrl({ url: 'pages/AboutPage' });
        })
      }
      .width('100%')
      .borderRadius(HwRadius.card)
      .backgroundColor(MijiaOverviewCard)
      .border({ width: 1, color: '#24FFFFFF' })
      .clip(true)

      Blank()
        .height(this.isWideScreen ? 24 : BOTTOM_BAR_HEIGHT + BOTTOM_BAR_MARGIN + this.navigationBarHeight + 24)
    }
    .width('100%')
    .constraintSize({
      maxWidth: this.isWideScreen ? MAX_CONTENT_WIDTH : '100%'
    })
    .padding({ left: this.contentPadding(), right: this.contentPadding() })
  }

  @Builder
  infoMetricCard($$: InfoMetricCardConfig) {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 6 }) {
        Text($$.title)
          .fontFamily(this.appFontFamily($$.title))
          .fontWeight(this.appFontWeight())
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
        Text($$.rangeText)
          .fontFamily(this.appFontFamily($$.rangeText))
          .fontWeight(this.appFontWeight())
          .fontSize(13)
          .fontColor(MijiaOverviewCardText)
        if (this.infoShowMoreContent && $$.moreText.length > 0) {
          Text($$.moreText)
            .fontFamily(this.appFontFamily($$.moreText))
            .fontWeight(this.appFontWeight())
            .fontSize(13)
            .fontColor(MijiaOverviewCardText)
        }
      }
      .width('100%')
      .padding({ left: HwSpace.lg, right: HwSpace.lg })
    }
    .width('100%')
    .height(INFO_CARD_HEIGHT)
    .borderRadius(HwRadius.card)
    .backgroundColor(MijiaOverviewCard)
    .border({ width: 1, color: '#24FFFFFF' })
    .clip(true)
  }

  @Builder
  infoDeviceRow(entry: InfoDeviceEntry) {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text(entry.name)
          .fontFamily(this.appFontFamily(entry.name))
          .fontWeight(this.appFontWeight())
          .fontSize(15)
          .fontColor(Color.White)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (entry.roomName.length > 0) {
          Text(entry.roomName)
            .fontFamily(this.appFontFamily(entry.roomName))
            .fontWeight(this.appFontWeight())
            .fontSize(12)
            .fontColor(MijiaOverviewCardText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(entry.valueText)
        .fontFamily(this.appFontFamily(entry.valueText))
        .fontWeight(this.appFontWeight())
        .fontSize(15)
        .fontColor(MijiaOverviewCardValue)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([MijiaOverviewCardText])
    }
    .width('100%')
    .padding(HwSpace.md)
    .borderRadius(HwRadius.control)
    .backgroundColor(MijiaOverviewCard)
    .stateStyles({ pressed: this.overviewCardPressedStyle })
    .onClick(() => {
      this.openDeviceFromSheet(entry.did);
    })
  }

  @Builder
  temperatureDeviceSheet() {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Text(`提供温度的设备（${this.temperatureDevices.length}）`)
          .fontFamily(this.appFontFamily(`提供温度的设备（${this.temperatureDevices.length}）`))
          .fontWeight(this.appFontWeight())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(HwColor.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        IconCircleButton({
          symbol: $r('sys.symbol.xmark'),
          buttonSize: 36,
          iconSize: 18,
          onAction: () => {
            this.showTemperatureSheet = false;
          }
        })
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)
      .padding({ left: HwSpace.lg, right: HwSpace.lg })

      Column({ space: 10 }) {
        if (this.temperatureDevices.length === 0) {
          Text('暂无提供温度的设备')
            .fontFamily(this.appFontFamily('暂无提供温度的设备'))
            .fontWeight(this.appFontWeight())
            .fontSize(14)
            .fontColor(HwColor.textSecondary)
            .padding({ top: 12, bottom: 12 })
        }
        ForEach(this.temperatureDevices, (entry: InfoDeviceEntry) => {
          this.infoDeviceRow(entry)
        }, (entry: InfoDeviceEntry) => entry.did)
      }
      .width('100%')
      .padding({ left: HwSpace.lg, right: HwSpace.lg, bottom: 24 })
      .margin({ top: 12 })
    }
    .width('100%')
    .backgroundColor(MijiaSheetBackground)
  }

  @Builder
  humidityDeviceSheet() {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Text(`提供湿度的设备（${this.humidityDevices.length}）`)
          .fontFamily(this.appFontFamily(`提供湿度的设备（${this.humidityDevices.length}）`))
          .fontWeight(this.appFontWeight())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(HwColor.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        IconCircleButton({
          symbol: $r('sys.symbol.xmark'),
          buttonSize: 36,
          iconSize: 18,
          onAction: () => {
            this.showHumiditySheet = false;
          }
        })
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)
      .padding({ left: HwSpace.lg, right: HwSpace.lg })

      Column({ space: 10 }) {
        if (this.humidityDevices.length === 0) {
          Text('暂无提供湿度的设备')
            .fontFamily(this.appFontFamily('暂无提供湿度的设备'))
            .fontWeight(this.appFontWeight())
            .fontSize(14)
            .fontColor(HwColor.textSecondary)
            .padding({ top: 12, bottom: 12 })
        }
        ForEach(this.humidityDevices, (entry: InfoDeviceEntry) => {
          this.infoDeviceRow(entry)
        }, (entry: InfoDeviceEntry) => entry.did)
      }
      .width('100%')
      .padding({ left: HwSpace.lg, right: HwSpace.lg, bottom: 24 })
      .margin({ top: 12 })
    }
    .width('100%')
    .backgroundColor(MijiaSheetBackground)
  }

  @Builder
  pm25DeviceSheet() {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Text(`提供PM2.5的设备（${this.pm25Devices.length}）`)
          .fontFamily(this.appFontFamily(`提供PM2.5的设备（${this.pm25Devices.length}）`))
          .fontWeight(this.appFontWeight())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(HwColor.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        IconCircleButton({
          symbol: $r('sys.symbol.xmark'),
          buttonSize: 36,
          iconSize: 18,
          onAction: () => {
            this.showPm25Sheet = false;
          }
        })
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)
      .padding({ left: HwSpace.lg, right: HwSpace.lg })

      Column({ space: 10 }) {
        if (this.pm25Devices.length === 0) {
          Text('暂无提供PM2.5的设备')
            .fontFamily(this.appFontFamily('暂无提供PM2.5的设备'))
            .fontWeight(this.appFontWeight())
            .fontSize(14)
            .fontColor(HwColor.textSecondary)
            .padding({ top: 12, bottom: 12 })
        }
        ForEach(this.pm25Devices, (entry: InfoDeviceEntry) => {
          this.infoDeviceRow(entry)
        }, (entry: InfoDeviceEntry) => entry.did)
      }
      .width('100%')
      .padding({ left: HwSpace.lg, right: HwSpace.lg, bottom: 24 })
      .margin({ top: 12 })
    }
    .width('100%')
    .backgroundColor(MijiaSheetBackground)
  }

  @Builder
  onDeviceSheet() {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Text(`开启中的设备（${this.onDevices.length}）`)
          .fontFamily(this.appFontFamily(`开启中的设备（${this.onDevices.length}）`))
          .fontWeight(this.appFontWeight())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(HwColor.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        IconCircleButton({
          symbol: $r('sys.symbol.xmark'),
          buttonSize: 36,
          iconSize: 18,
          onAction: () => {
            this.showOnSheet = false;
          }
        })
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)
      .padding({ left: HwSpace.lg, right: HwSpace.lg })

      Column({ space: 10 }) {
        if (this.onDevices.length === 0) {
          Text('当前没有开启中的设备')
            .fontFamily(this.appFontFamily('当前没有开启中的设备'))
            .fontWeight(this.appFontWeight())
            .fontSize(14)
            .fontColor(HwColor.textSecondary)
            .padding({ top: 12, bottom: 12 })
        }
        ForEach(this.onDevices, (entry: InfoDeviceEntry) => {
          this.infoDeviceRow(entry)
        }, (entry: InfoDeviceEntry) => entry.did)
      }
      .width('100%')
      .padding({ left: HwSpace.lg, right: HwSpace.lg, bottom: 24 })
      .margin({ top: 12 })
    }
    .width('100%')
    .backgroundColor(MijiaSheetBackground)
  }

  @Builder
  excludeDeviceRow(device: XiaomiDevice) {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text(device.name)
          .fontFamily(this.appFontFamily(device.name))
          .fontWeight(this.appFontWeight())
          .fontSize(15)
          .fontColor(Color.White)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (device.roomName.length > 0) {
          Text(device.roomName)
            .fontFamily(this.appFontFamily(device.roomName))
            .fontWeight(this.appFontWeight())
            .fontSize(12)
            .fontColor(MijiaOverviewCardText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Checkbox()
        .select(this.isDeviceExcluded(device.did))
        .selectedColor(HwColor.primary)
        .onChange((checked: boolean) => {
          this.setDeviceExcluded(device.did, checked);
        })
    }
    .width('100%')
    .padding(HwSpace.md)
    .borderRadius(HwRadius.control)
    .backgroundColor(MijiaOverviewCard)
    .stateStyles({ pressed: this.overviewCardPressedStyle })
    .onClick(() => {
      this.setDeviceExcluded(device.did, !this.isDeviceExcluded(device.did));
    })
  }

  @Builder
  excludeDeviceSheet() {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Text('信息页排除设备')
          .fontFamily(this.appFontFamily('信息页排除设备'))
          .fontWeight(this.appFontWeight())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(HwColor.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        IconCircleButton({
          symbol: $r('sys.symbol.xmark'),
          buttonSize: 36,
          iconSize: 18,
          onAction: () => {
            this.showExcludeSheet = false;
          }
        })
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)
      .padding({ left: HwSpace.lg, right: HwSpace.lg })

      Text('勾选后该设备的数据不再计入信息页')
        .fontFamily(this.appFontFamily('勾选后该设备的数据不再计入信息页'))
        .fontWeight(this.appFontWeight())
        .fontSize(12)
        .fontColor(HwColor.textSecondary)
        .width('100%')
        .padding({ left: HwSpace.lg, right: HwSpace.lg, bottom: 8 })

      if (this.devices.length === 0) {
        Text('暂无设备')
          .fontFamily(this.appFontFamily('暂无设备'))
          .fontWeight(this.appFontWeight())
          .fontSize(14)
          .fontColor(HwColor.textSecondary)
          .padding({ top: 24, bottom: 24 })
      } else {
        Scroll() {
          Column({ space: 8 }) {
            ForEach(this.devices, (device: XiaomiDevice) => {
              this.excludeDeviceRow(device)
            }, (device: XiaomiDevice) => device.did)
          }
          .width('100%')
          .padding({ left: HwSpace.lg, right: HwSpace.lg, bottom: 24 })
          .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MijiaSheetBackground)
  }

  @Builder
  familyHomeRow(home: XiaomiHome, selected: boolean) {
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
      if (selected) {
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
      width: selected ? 1 : 0,
      color: selected ? MijiaOverviewCardValue : '#00000000'
    })
    .stateStyles({ pressed: this.overviewCardPressedStyle })
    .onClick(() => {
      this.selectHomeFromSheet(home);
    })
  }

  @Builder
  familySelectSheet() {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Text('选择家庭')
          .fontFamily(this.appFontFamily('选择家庭'))
          .fontWeight(this.appFontWeight())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(HwColor.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        IconCircleButton({
          symbol: $r('sys.symbol.xmark'),
          buttonSize: 36,
          iconSize: 18,
          onAction: () => {
            this.showFamilySheet = false;
          }
        })
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)
      .padding({ left: HwSpace.lg, right: HwSpace.lg })

      if (this.homes.length === 0) {
        Text('暂无家庭，请先下拉刷新')
          .fontFamily(this.appFontFamily('暂无家庭，请先下拉刷新'))
          .fontWeight(this.appFontWeight())
          .fontSize(14)
          .fontColor(HwColor.textSecondary)
          .padding({ top: 24, bottom: 24 })
      } else {
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
            .stateStyles({ pressed: this.overviewCardPressedStyle })
            .onClick(() => {
              this.selectAllHomesFromSheet();
            })

            ForEach(this.homes, (home: XiaomiHome) => {
              this.familyHomeRow(home, this.selectedHomeId === home.homeId)
            }, (home: XiaomiHome) => home.homeId)
          }
          .width('100%')
          .padding({ left: HwSpace.lg, right: HwSpace.lg, bottom: 24 })
          .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MijiaSheetBackground)
  }

  @Builder
  infoTabContent() {
    Column({ space: 14 }) {
      Blank().height(this.isWideScreen ? 12 : (this.isWearable ? this.topOffset() : 4))

      if (this.infoLoading) {
        Text('加载中…')
          .fontFamily(this.appFontFamily('加载中…'))
          .fontWeight(this.appFontWeight())
          .fontSize(14)
          .fontColor(HwColor.textSecondary)
          .padding({ top: 24, bottom: 24 })
      }
      if (this.infoError.length > 0) {
        Text(this.infoError)
          .fontFamily(this.appFontFamily(this.infoError))
          .fontWeight(this.appFontWeight())
          .fontSize(14)
          .fontColor(HwColor.danger)
      }
      if (!this.infoLoading && this.infoError.length === 0 && this.infoDeviceCount === 0) {
        Text('当前家庭暂无可用设备数据')
          .fontFamily(this.appFontFamily('当前家庭暂无可用设备数据'))
          .fontWeight(this.appFontWeight())
          .fontSize(14)
          .fontColor(HwColor.textSecondary)
      }

      Column() {
        this.infoMetricCard({
          title: '温度',
          rangeText: this.temperatureRangeText,
          moreText: this.temperatureMoreText
        })
      }
      .width('100%')
      .hoverEffect(HoverEffect.Highlight)
      .onClick(() => {
        this.showTemperatureSheet = true;
      })
      .bindSheet($$this.showTemperatureSheet, this.temperatureDeviceSheet(), {
        height: SheetSize.MEDIUM,
        dragBar: true,
            backgroundColor: MijiaSheetBackground,
        showClose: false,
      })

      Column() {
        this.infoMetricCard({
          title: '湿度',
          rangeText: this.humidityRangeText,
          moreText: this.humidityMoreText
        })
      }
      .width('100%')
      .hoverEffect(HoverEffect.Highlight)
      .onClick(() => {
        this.showHumiditySheet = true;
      })
      .bindSheet($$this.showHumiditySheet, this.humidityDeviceSheet(), {
        height: SheetSize.MEDIUM,
        dragBar: true,
            backgroundColor: MijiaSheetBackground,
        showClose: false,
      })

      Column() {
        this.infoMetricCard({
          title: 'PM2.5',
          rangeText: this.pm25RangeText,
          moreText: this.pm25MoreText
        })
      }
      .width('100%')
      .hoverEffect(HoverEffect.Highlight)
      .onClick(() => {
        this.showPm25Sheet = true;
      })
      .bindSheet($$this.showPm25Sheet, this.pm25DeviceSheet(), {
        height: SheetSize.MEDIUM,
        dragBar: true,
            backgroundColor: MijiaSheetBackground,
        showClose: false,
      })

      Column() {
        this.infoMetricCard({
          title: '开启中',
          rangeText: `${this.onDeviceCount} 台`,
          moreText: ''
        })
      }
      .width('100%')
      .hoverEffect(HoverEffect.Highlight)
      .onClick(() => {
        this.showOnSheet = true;
      })
      .bindSheet($$this.showOnSheet, this.onDeviceSheet(), {
        height: SheetSize.MEDIUM,
        dragBar: true,
            backgroundColor: MijiaSheetBackground,
        showClose: false,
      })

      Blank()
        .height(this.isWideScreen ? 24 : BOTTOM_BAR_HEIGHT + BOTTOM_BAR_MARGIN + this.navigationBarHeight + 24)
    }
    .width('100%')
    .constraintSize({
      maxWidth: this.isWideScreen ? MAX_CONTENT_WIDTH : '100%'
    })
    .padding({ left: 20, right: 20 })
  }

  @Builder
  localSceneCard(scene: LocalScene) {
    Row({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.house'))
        .fontSize(20)
        .fontColor([MijiaOverviewCardValue])
      Column({ space: 4 }) {
        Text(scene.name)
          .fontFamily(this.appFontFamily(scene.name))
          .fontWeight(this.appFontWeight())
          .fontSize(15)
          .fontColor(Color.White)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`本地智能 · ${scene.actions.length} 个动作`)
          .fontFamily(this.appFontFamily(`本地智能 · ${scene.actions.length} 个动作`))
          .fontWeight(this.appFontWeight())
          .fontSize(12)
          .fontColor(MijiaOverviewCardText)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      IconCircleButton({
        symbol: $r('sys.symbol.trash'),
        buttonSize: 32,
        iconSize: 16,
        tint: MijiaOverviewCardText,
        onAction: () => {
          this.confirmDeleteLocalScene(scene);
        }
      })
      Row({ space: 4 }) {
        Text('执行')
          .fontFamily(this.appFontFamily('执行'))
          .fontWeight(this.appFontWeight())
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#0E1B28')
      }
      .height(30)
      .padding({ left: 16, right: 16 })
      .borderRadius(15)
      .backgroundColor(MijiaOverviewCardValue)
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.execLocalScene(scene);
      })
    }
    .width('100%')
    .padding(HwSpace.lg)
    .borderRadius(HwRadius.card)
    .backgroundColor(MijiaOverviewCard)
    .stateStyles({ pressed: this.overviewCardPressedStyle })
  }

  @Builder
  sceneCard(scene: XiaomiScene) {
    Row({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.bolt'))
        .fontSize(20)
        .fontColor([MijiaOverviewCardValue])
      Column({ space: 4 }) {
        Text(scene.name)
          .fontFamily(this.appFontFamily(scene.name))
          .fontWeight(this.appFontWeight())
          .fontSize(15)
          .fontColor(Color.White)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(scene.isEnabled ? '已启用' : '已停用')
          .fontFamily(this.appFontFamily(scene.isEnabled ? '已启用' : '已停用'))
          .fontWeight(this.appFontWeight())
          .fontSize(12)
          .fontColor(MijiaOverviewCardText)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Row({ space: 4 }) {
        Text('执行')
          .fontFamily(this.appFontFamily('执行'))
          .fontWeight(this.appFontWeight())
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#0E1B28')
      }
      .height(30)
      .padding({ left: 16, right: 16 })
      .borderRadius(15)
      .backgroundColor(MijiaOverviewCardValue)
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .padding(HwSpace.lg)
    .borderRadius(HwRadius.card)
    .backgroundColor(MijiaOverviewCard)
    .stateStyles({ pressed: this.overviewCardPressedStyle })
    .onClick(() => {
      this.runSceneById(scene);
    })
  }

  @Builder
  alertCard(alert: AlertItem) {
    Row({ space: 12 }) {
      SymbolGlyph(alert.level === 'warn'
        ? $r('sys.symbol.exclamationmark_triangle_fill') : $r('sys.symbol.info_circle'))
        .fontSize(20)
        .fontColor([alert.level === 'warn' ? '#FFB340' : MijiaOverviewCardText])
      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Text(alert.title)
            .fontFamily(this.appFontFamily(alert.title))
            .fontWeight(this.appFontWeight())
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
          if (alert.roomName.length > 0) {
            Text(alert.roomName)
              .fontFamily(this.appFontFamily(alert.roomName))
              .fontWeight(this.appFontWeight())
              .fontSize(12)
              .fontColor(MijiaOverviewCardText)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        Text(alert.detail)
          .fontFamily(this.appFontFamily(alert.detail))
          .fontWeight(this.appFontWeight())
          .fontSize(12)
          .fontColor(MijiaOverviewCardText)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(HwSpace.lg)
    .borderRadius(HwRadius.card)
    .backgroundColor(MijiaOverviewCard)
    .stateStyles({ pressed: this.overviewCardPressedStyle })
    .onClick(() => {
      if (alert.type !== 'offline') {
        this.openDeviceFromSheet(alert.did);
      }
    })
  }

  @Builder
  smartTabContent() {
    Column({ space: 12 }) {
      Blank().height(this.isWideScreen ? 12 : (this.isWearable ? this.topOffset() : 4))

      Row({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize(18)
          .fontColor([MijiaOverviewCardValue])
        Text('创建智能')
          .fontFamily(this.appFontFamily('创建智能'))
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
      .stateStyles({ pressed: this.overviewCardPressedStyle })
      .onClick(() => {
        this.openSceneCreatePage();
      })

      if (this.localScenes.length > 0) {
        Text(`我的智能（${this.localScenes.length}）`)
          .fontFamily(this.appFontFamily(`我的智能（${this.localScenes.length}）`))
          .fontWeight(this.appFontWeight())
          .fontSize(13)
          .fontColor(MijiaOverviewCardText)
          .width('100%')
          .padding({ left: 4, right: 4 })
        ForEach(this.localScenes, (scene: LocalScene) => {
          this.localSceneCard(scene)
        }, (scene: LocalScene) => scene.sceneId)
      }

      if (this.scenesLoading) {
        Text('加载中…')
          .fontFamily(this.appFontFamily('加载中…'))
          .fontWeight(this.appFontWeight())
          .fontSize(14)
          .fontColor(HwColor.textSecondary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 24, bottom: 24 })
      }
      if (this.scenesError.length > 0) {
        Text(this.scenesError)
          .fontFamily(this.appFontFamily(this.scenesError))
          .fontWeight(this.appFontWeight())
          .fontSize(14)
          .fontColor(HwColor.danger)
      }
      if (!this.scenesLoading && this.scenesError.length === 0 && this.scenes.length === 0 &&
        this.localScenes.length === 0) {
        Column({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.bolt'))
            .fontSize(30)
            .fontColor([HwColor.textSecondary])
          Text('暂无智能')
            .fontFamily(this.appFontFamily('暂无智能'))
            .fontWeight(this.appFontWeight())
            .fontSize(15)
            .fontColor(HwColor.textPrimary)
          Text('点击上方「创建智能」自建本地智能，或前往米家App创建自动化场景')
            .fontFamily(this.appFontFamily('点击上方「创建智能」自建本地智能，或前往米家App创建自动化场景'))
            .fontWeight(this.appFontWeight())
            .fontSize(12)
            .fontColor(HwColor.textSecondary)
        }
        .width('100%')
        .padding({ top: 40, bottom: 40 })
      }

      ForEach(this.scenes, (scene: XiaomiScene) => {
        this.sceneCard(scene)
      }, (scene: XiaomiScene) => scene.sceneId)

      Blank()
        .height(this.isWideScreen ? 24 : BOTTOM_BAR_HEIGHT + BOTTOM_BAR_MARGIN + this.navigationBarHeight + 24)
    }
    .width('100%')
    .constraintSize({
      maxWidth: this.isWideScreen ? MAX_CONTENT_WIDTH : '100%'
    })
    .padding({ left: this.contentPadding(), right: this.contentPadding() })
  }

  @Builder
  alertTabContent() {
    Column({ space: 12 }) {
      Blank().height(this.isWideScreen ? 12 : (this.isWearable ? this.topOffset() : 4))

      if (this.alertsLoading) {
        Text('加载中…')
          .fontFamily(this.appFontFamily('加载中…'))
          .fontWeight(this.appFontWeight())
          .fontSize(14)
          .fontColor(HwColor.textSecondary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 24, bottom: 24 })
      }
      if (!this.alertsLoading && this.alerts.length === 0) {
        Column({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.bell'))
            .fontSize(30)
            .fontColor([HwColor.textSecondary])
          Text('暂无提醒')
            .fontFamily(this.appFontFamily('暂无提醒'))
            .fontWeight(this.appFontWeight())
            .fontSize(15)
            .fontColor(HwColor.textPrimary)
          Text('耗材不足、低电量、设备离线等提醒会显示在这里')
            .fontFamily(this.appFontFamily('耗材不足、低电量、设备离线等提醒会显示在这里'))
            .fontWeight(this.appFontWeight())
            .fontSize(12)
            .fontColor(HwColor.textSecondary)
        }
        .width('100%')
        .padding({ top: 40, bottom: 40 })
      }

      ForEach(this.alerts, (alert: AlertItem) => {
        this.alertCard(alert)
      }, (alert: AlertItem) => `${alert.type}_${alert.did}`)

      Blank()
        .height(this.isWideScreen ? 24 : BOTTOM_BAR_HEIGHT + BOTTOM_BAR_MARGIN + this.navigationBarHeight + 24)
    }
    .width('100%')
    .constraintSize({
      maxWidth: this.isWideScreen ? MAX_CONTENT_WIDTH : '100%'
    })
    .padding({ left: this.contentPadding(), right: this.contentPadding() })
  }

  @Builder
  homePane() {
    Column() {
      if (this.isWideScreen) {
        this.tabHeader()
      } else if (!this.isWearable) {
        this.homeHeader()
      }
      Refresh({ refreshing: $$this.homeRefreshing }) {
        Scroll(this.homeScroller) {
          this.homeTabContent()
        }
        .width('100%')
        .align(this.cardsFromTop ? Alignment.Top : Alignment.Center)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .layoutWeight(1)
      .onRefreshing(() => {
        this.handleHomePullRefresh();
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(HwColor.background)
    .layoutWeight(this.isWearable ? 1 : 0)
  }

  @Builder
  smartPane() {
    Column() {
      if (!this.isWearable) {
        this.tabHeader()
      }
      Scroll(this.smartScroller) {
        this.smartTabContent()
      }
      .width('100%')
      .layoutWeight(1)
      .align(this.cardsFromTop ? Alignment.Top : Alignment.Center)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(HwColor.background)
    .layoutWeight(this.isWearable ? 1 : 0)
  }

  @Builder
  alertPane() {
    Column() {
      if (!this.isWearable) {
        this.tabHeader()
      }
      Scroll(this.alertScroller) {
        this.alertTabContent()
      }
      .width('100%')
      .layoutWeight(1)
      .align(this.cardsFromTop ? Alignment.Top : Alignment.Center)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(HwColor.background)
    .layoutWeight(this.isWearable ? 1 : 0)
  }

  @Builder
  minePane() {
    Column() {
      if (!this.isWearable) {
        this.tabHeader()
      }
      Scroll(this.mineScroller) {
        this.mineTabContent()
      }
      .width('100%')
      .layoutWeight(1)
      .align(this.cardsFromTop ? Alignment.Top : Alignment.Center)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(HwColor.background)
    .layoutWeight(this.isWearable ? 1 : 0)
  }

  @Builder
  wearableTabButton(index: number) {
    Column({ space: 3 }) {
      this.tabIcon(index)
      Text(this.tabLabel(index))
        .fontFamily(this.appFontFamily(this.tabLabel(index)))
        .fontWeight(this.appFontWeight())
        .fontSize(11)
        .fontColor(this.activeTab === index ? HwColor.primary : HwColor.textSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .height(52)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.onTabSelected(index);
    })
  }

  @Builder
  wearableContent() {
    Column() {
      if (this.activeTab === 0) {
        this.homePane()
      } else {
        this.minePane()
      }
      Row() {
        this.wearableTabButton(0)
        this.wearableTabButton(1)
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 8, bottom: this.navigationBarHeight })
      .backgroundColor('#CCFFFFFF')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(HwColor.background)
    .layoutWeight(this.isWearable ? 1 : 0)
  }

  /** 首页刷新：设备列表 + 概览卡（温湿度/PM2.5）一起刷新 */
  private refreshHomeData(silent: boolean = false): void {
    this.loadData(true, silent).then(() => {
      this.loadInfoData(true);
      if (!silent) {
        this.getUIContext().getPromptAction().showToast({ message: '已刷新' });
      }
    }).catch((err: Error) => {
      Logger.error('refresh home data failed, %{public}s', err.message);
      if (!silent) {
        this.getUIContext().getPromptAction().showToast({ message: '刷新失败' });
      }
    });
  }

  private handleHomePullRefresh(): void {
    this.homeRefreshing = true;
    this.loadData(true, true).then(() => {
      this.loadInfoData(true).finally(() => {
        this.homeRefreshing = false;
      });
    });
  }

  private onTabSelected(index: number): void {
    FeedbackLogService.recordOperation('UI', `切换标签 ${index}`);
    this.activeTab = index;
    if (this.isWearable) {
      if (index === 1) {
        this.loadData(true, true);
        this.loadAccount();
      }
      return;
    }
    if (index === 0) {
      this.refreshInfoOnEnter();
      this.startInfoRefreshTimer();
    } else {
      this.stopInfoRefreshTimer();
    }
    if (index === 1) {
      this.loadScenes(false);
    } else if (index === 2) {
      this.buildAlerts();
    } else if (index === 3) {
      this.loadData(true, true);
      this.loadAccount();
    }
  }

  build() {
    Column() {
      HdsNavigation(this.pageInfos) {
      Stack({ alignContent: Alignment.TopStart }) {
        AppBackground()

        if (this.isWideScreen) {
          HdsTabs({
            controller: this.tabsController,
            index: this.activeTab
          }) {
            TabContent() { this.homePane() }.tabBar(this.tabItem(0))
            TabContent() { this.smartPane() }.tabBar(this.tabItem(1))
            TabContent() { this.alertPane() }.tabBar(this.tabItem(2))
            TabContent() { this.minePane() }.tabBar(this.tabItem(3))
          }
          .width('100%')
          .height('100%')
          .barPosition(BarPosition.Start)
          .vertical(true)
          .barWidth(this.sideBarWidth)
          .barHeight('100%')
          .barOverlap(false)
          .scrollable(false)
          .animationDuration(this.homeSmoothSwitch ? 300 : 0)
          .onSelected((index: number) => {
            this.onTabSelected(index);
          })

          Stack({ alignContent: Alignment.Center }) {
            Column()
              .width(1)
              .height('100%')
              .backgroundColor('#14000000')
          }
          .width(12)
          .height('100%')
          .position({ x: this.sideBarWidth - 6, y: 0 })
          .backgroundColor(this.dragHovered ? '#0A000000' : Color.Transparent)
          .onHover((isHover: boolean) => {
            this.dragHovered = isHover;
          })
          .gesture(
            PanGesture({ fingers: 1, direction: PanDirection.Horizontal })
              .onActionStart(() => {
                this.dragStartWidth = this.sideBarWidth;
              })
              .onActionUpdate((event: GestureEvent) => {
                const maxWidth: number = Math.min(this.screenWidthVp * 0.4, SIDE_BAR_WIDTH_MAX);
                this.sideBarWidth = Math.max(SIDE_BAR_WIDTH_MIN,
                  Math.min(this.dragStartWidth + event.offsetX, maxWidth));
              })
          )
        } else if (this.isWearable) {
          this.wearableContent()
        } else {
          HdsTabs({
            controller: this.tabsController,
            index: this.activeTab
          }) {
            TabContent() { this.homePane() }.tabBar(this.tabBarStyle(0))
            TabContent() { this.smartPane() }.tabBar(this.tabBarStyle(1))
            TabContent() { this.alertPane() }.tabBar(this.tabBarStyle(2))
            TabContent() { this.minePane() }.tabBar(this.tabBarStyle(3))
          }
          .width('100%')
          .height('100%')
          .barPosition(BarPosition.End)
          .vertical(false)
          .barOverlap(true)
          .scrollable(false)
          .animationDuration(this.homeSmoothSwitch ? 300 : 0)
          .onSelected((index: number) => {
            this.onTabSelected(index);
          })
          .barFloatingStyle({
            barBottomMargin: this.navigationBarHeight,
            barSideMargin: 0,
            gradientMask: {
              maskColor: '#00000000',
              maskHeight: 0
            },
            lightColor: Color.White,
            systemMaterialEffect: {
              materialType: hdsMaterial.MaterialType.IMMERSIVE,
              materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
            }
          })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
      .clip(this.isWearable)
      .borderRadius(this.isWearable ? '50%' : 0)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isDarkMode ? HwColor.backgroundDark : HwColor.background)
    .mode(this.isLargeScreen && !this.pcLayoutEnabled && this.autoMultiColumn ? NavigationMode.Auto : NavigationMode.Stack)
    .titleBar({
      avoidLayoutSafeArea: true,
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR
        }
      },
      content: {
        title: {
          mainTitle: this.pageTitle(),
          subTitle: this.activeTab === 1 && this.selectedHomeName.length > 0
            ? this.selectedHomeName
            : undefined
        },
        menu: this.activeTab === 0 ? {
          value: [
            {
              content: {
                label: '选择家庭',
                icon: $r('sys.symbol.house'),
                isEnabled: true,
                action: () => {
                  FeedbackLogService.recordOperation('UI', '打开选择家庭');
                  this.showFamilySheet = true;
                }
              }
            }
          ]
        } : this.activeTab === 1 ? {
          value: [
            {
              content: {
                label: '刷新',
                icon: $r('sys.symbol.arrow_counterclockwise'),
                isEnabled: !this.scenesLoading,
                action: () => {
                  FeedbackLogService.recordOperation('UI', '刷新智能页');
                  this.loadScenes(false);
                }
              }
            }
          ]
        } : this.activeTab === 2 ? {
          value: [
            {
              content: {
                label: '刷新',
                icon: $r('sys.symbol.arrow_counterclockwise'),
                isEnabled: !this.alertsLoading,
                action: () => {
                  FeedbackLogService.recordOperation('UI', '刷新信息提醒页');
                  this.buildAlerts();
                }
              }
            }
          ]
        } : undefined
      }
    })
    .titleMode(HdsNavigationTitleMode.FREE)
    .hideTitleBar(true)
    .hideBackButton(true)
    .hideToolBar(true, true)
    .bindToScrollable([this.homeScroller, this.mineScroller, this.infoScroller])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .keyboardShortcut('R', [ModifierKey.CTRL], () => {
      FeedbackLogService.recordOperation('KEYBOARD', 'Ctrl+R 刷新当前页');
      this.refreshCurrentTab();
    })
    .keyboardShortcut(FunctionKey.ESC, [], () => {
      if (this.pageInfos.size() > 0) {
        this.pageInfos.pop();
      }
    })
  }
  .width('100%')
  .height('100%')
  .bindSheet($$this.showFamilySheet, this.familySelectSheet(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
            backgroundColor: MijiaSheetBackground,
      showClose: false
    })
  }
}
