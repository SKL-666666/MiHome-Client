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

import { HdsNavDestination } from '@kit.UIDesignKit';
import { common } from '@kit.AbilityKit';
import {
  ActionControlDescriptor,
  ActionArgumentDescriptor,
  buildServiceActions,
  buildServiceControls,
  CapabilityControlType,
  dedupeControlLabels,
  markPrimaryPower,
  PropertyControlDescriptor,
  resolveServiceDisplayNames
} from '../components/CapabilityRenderer';
import { PropertyControl } from '../components/PropertyControl';
import { DeviceController } from '../controllers/DeviceController';
import { DevicePropertyParam, DevicePropertyResult } from '../controllers/DeviceTransport';
import { MIoTSpecInstance } from '../models/MIotSpecModels';
import { XiaomiDevice, XiaomiHome } from '../models/XiaomiHomeModels';
import { xiaomiDataService } from '../services/XiaomiDataService';
import { FeedbackLogService } from '../services/FeedbackLogService';
import { Logger } from '../utils/Logger';
import { HwColor, HwRadius, HwSpace, MijiaOffButton, MijiaOnButton, MijiaOverviewCard, MijiaOverviewCardPressed, MijiaOverviewCardText, MijiaOverviewCardValue, MijiaSheetBackground } from '../utils/DesignTokens';
import { AppBackground } from '../components/AppBackground';
import { IconCircleButton } from '../components/IconCircleButton';
import { AboutDeviceRouteParam, DeviceDetailRouteParam } from '../models/NavRouteParams';
import { RoomStore, UserRoom } from '../storage/RoomStore';
import { DeviceOverrideStore } from '../storage/DeviceOverrideStore';

interface PropertyValueState {
  key: string;
  value: Object | undefined;
}

interface ActionArgumentValueState {
  key: string;
  value: Object | undefined;
}

/** 属性卡片布局项：single 为 1×1，group 为 1×2（合并同服务只读读数） */
interface ControlLayoutItem {
  key: string;
  kind: 'single' | 'group';
  controls: PropertyControlDescriptor[];
}

interface TrendPoint {
  label: string;
  value: number;
}

interface TrendCandidate {
  key: string;
  label: string;
}

/** 管理弹窗中的本地房间选项 */
interface ManageRoomOption {
  id: string;
  title: string;
}

@Builder
export function DeviceDetailBuilder(name: string, param: Object) {
  DeviceDetailPage({ did: (param as DeviceDetailRouteParam).did })
}

@Component
export struct DeviceDetailPage {
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
  @Consume('pageInfos') pageInfos: NavPathStack;
  @Prop did: string = '';
  private scroller: Scroller = new Scroller();
  @State deviceName: string = '';
  @State controls: PropertyControlDescriptor[] = [];
  @State extendedControls: PropertyControlDescriptor[] = [];
  @State showExtended: boolean = false;
  // 明面分区：电源（整排）/ 模式类选择（整排）/ 小控件（1×1）/ 只读读数（合并大卡）
  @State powerControlList: PropertyControlDescriptor[] = [];
  @State selectControlList: PropertyControlDescriptor[] = [];
  @State smallControlList: PropertyControlDescriptor[] = [];
  @State readoutControlList: PropertyControlDescriptor[] = [];
  @State actions: ActionControlDescriptor[] = [];
  @State values: PropertyValueState[] = [];
  @State loading: boolean = true;
  @State refreshing: boolean = false;
  @State refreshInFlight: boolean = false;
  @State activeTab: string = 'status';
  @State offline: boolean = false;
  @State errorMessage: string = '';
  @State actionLoadingKey: string = '';
  @State actionArgumentValues: ActionArgumentValueState[] = [];
  @State todayEnergy: string = '';
  @State monthEnergy: string = '';
  @State currentPower: string = '';
  @State showPowerInfo: boolean = false;
  @State trendPoints: TrendPoint[] = [];
  @State trendTitle: string = '';
  @State trendGranularity: string = 'day';
  @State showManageSheet: boolean = false;
  @State manageName: string = '';
  @State manageRoomId: string = '';
  @State manageRooms: ManageRoomOption[] = [];
  @State manageCurrentRoom: string = '';
  private trendDevice: XiaomiDevice | null = null;
  private trendSpec: MIoTSpecInstance | null = null;
  @StorageProp('navigationBarHeight') navigationBarHeight: number = 0;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('isDarkMode') isDarkMode: boolean = false;
  @StorageProp('isWearable') isWearable: boolean = false;

  private device: XiaomiDevice | null = null;
  private controller: DeviceController | null = null;

  private topOffset(): number {
    return (this.isWearable ? 52 : 56) + this.statusBarHeight;
  }

  private detailPadding(): number {
    return this.isWearable ? 12 : HwSpace.xl;
  }

  aboutToAppear(): void {
    FeedbackLogService.setCurrentPage('设备详情页');
    this.loadDevice();
  }

  async loadDevice(): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    this.offline = false;
    try {
      if (this.did.length === 0) {
        throw new Error('invalid device id');
      }
      const devices = await xiaomiDataService.getDevices();
      const device = devices[this.did];
      if (device === undefined) {
        throw new Error('device not found');
      }
      this.device = device;
      this.deviceName = DeviceOverrideStore.getDisplayName(device.did, device.name);
      this.offline = !device.online;
      FeedbackLogService.recordOperation('PAGE',
        `设备详情: ${device.name} did=${device.did} model=${device.model} 在线=${device.online ? '是' : '否'}`);
      if (device.online) {
        // 磁盘缓存优先：网络抖动不再导致详情页整页空白
        const context = getContext(this) as common.UIAbilityContext;
        const spec = await xiaomiDataService.getDeviceSpecForDeviceCached(device, context);
        this.logSpecSummary(device, spec);
        this.splitControls(this.buildControls(spec));
        this.actions = this.buildActions(spec);
        this.buildValueStates(this.controls.concat(this.extendedControls));
        this.buildActionArgumentStates(this.actions);
        this.controller = await xiaomiDataService.getDeviceController(device);
        await this.refreshValues();
        this.recordDeviceValues();
        await this.loadPowerInfo(device, spec);
        // 趋势图仅温湿度计加载，其余设备不再请求统计
        if (this.isTempHumiditySensor(device)) {
          await this.loadTrendInfo(device, spec);
        }
      } else {
        this.controls = [];
        this.extendedControls = [];
        this.showExtended = false;
        this.actions = [];
      }
    } catch (err) {
      this.errorMessage = err instanceof Error ? err.message : '加载设备失败';
      Logger.error('load device detail failed, %{public}s', this.errorMessage);
    } finally {
      this.loading = false;
    }
  }

  private recordDeviceValues(): void {
    const parts: string[] = [];
    for (let i = 0; i < this.values.length; i++) {
      const state = this.values[i];
      const valueText = state.value === undefined ? 'undefined' : JSON.stringify(state.value);
      parts.push(`${state.key}=${valueText}`);
    }
    FeedbackLogService.recordOperation('PAGE', `设备详情页属性: ${parts.join(' | ')}`);
  }

  /** 诊断日志：输出 spec 服务/属性清单（键/读写），用于精准修正标签与常用分级 */
  private logSpecSummary(device: XiaomiDevice, spec: MIoTSpecInstance): void {
    const parts: string[] = [];
    for (let i = 0; i < spec.services.length; i++) {
      const service = spec.services[i];
      const segments = service.type.split(':');
      const serviceKey = segments.length >= 4 ? segments[3] : service.type;
      const props: string[] = [];
      for (let j = 0; j < service.properties.length; j++) {
        const prop = service.properties[j];
        const propSegments = prop.type.split(':');
        const propKey = propSegments.length >= 4 ? propSegments[3] : prop.type;
        const access = `${prop.readable ? 'r' : ''}${prop.writable ? 'w' : ''}`;
        props.push(`${prop.iid}:${propKey}(${access})`);
      }
      parts.push(`s${service.iid}:${serviceKey}{${props.join(',')}}`);
    }
    Logger.info('spec summary did=%{public}s model=%{public}s urn=%{public}s :: %{public}s',
      device.did, device.model, device.urn, parts.join(' | '));
  }

  buildControls(spec: MIoTSpecInstance): PropertyControlDescriptor[] {
    const result: PropertyControlDescriptor[] = [];
    // 多实例服务（排插多路、多键墙开）先编号（开关1/开关2…）再参与去重；
    // 去重键为 siid.piid + 类型 + 格式：同一属性重复声明只保留第一个，
    // 不同属性即使标签相同（如多路开关都叫"开关"）也不会被误隐藏。
    const displayNames = resolveServiceDisplayNames(spec.services);
    const seen = new Set<string>();
    for (let i = 0; i < spec.services.length; i++) {
      const controls = buildServiceControls(spec.services[i], displayNames);
      for (let j = 0; j < controls.length; j++) {
        const signature = `${controls[j].siid}.${controls[j].piid}|${controls[j].type}|${controls[j].format}`;
        if (seen.has(signature)) {
          continue;
        }
        seen.add(signature);
        result.push(controls[j]);
      }
    }
    // 多主电源收敛：只保留第一个电源圆钮并置顶，其余降级为普通开关；
    // 重名标签消歧：仍完全同名的控制追加 ·2/·3 序号
    markPrimaryPower(result);
    dedupeControlLabels(result);
    return result;
  }

  /**
   * 按 isCommon 把属性拆成明面常用区与「更多功能」折叠区。
   * 兜底保护：常用区没有任何可写控制而设备本身有可写属性时，不折叠、全部平铺，
   * 避免未知品类设备详情页空白。
   */
  private splitControls(all: PropertyControlDescriptor[]): void {
    const common: PropertyControlDescriptor[] = [];
    const extended: PropertyControlDescriptor[] = [];
    let commonWritable = 0;
    let anyWritable = 0;
    for (let i = 0; i < all.length; i++) {
      const control = all[i];
      if (control.writable) {
        anyWritable++;
      }
      if (control.isCommon) {
        common.push(control);
        if (control.writable) {
          commonWritable++;
        }
      } else {
        extended.push(control);
      }
    }
    let layout = common;
    if (common.length === 0 || (commonWritable === 0 && anyWritable > 0)) {
      // 兜底保护：常用区没有可写控制时全部平铺，避免未知品类设备详情页空白
      layout = all;
      extended.length = 0;
    }
    this.controls = layout;
    this.extendedControls = extended;
    this.showExtended = false;
    // 除智能插座/排插外，消歧产生的「开关·N」重复开关收纳进折叠区
    if (!this.isPlugDevice()) {
      for (let i = layout.length - 1; i >= 0; i--) {
        if (/·\d+$/.test(layout[i].label)) {
          extended.push(layout[i]);
          layout.splice(i, 1);
        }
      }
    }
    this.partitionLayoutControls(layout);
  }

  /** 插座/排插判断：多路插孔的编号开关（开关1/开关2…）保留在明面 */
  private isPlugDevice(): boolean {
    if (this.device === null) {
      return false;
    }
    const text = `${this.device.model} ${this.device.name}`.toLowerCase();
    return text.includes('plug') || text.includes('socket') || text.includes('outlet') ||
      text.includes('插座') || text.includes('排插') || text.includes('插线板');
  }

  /** 明面分区：电源整排卡、模式类选择整排卡、其余 1×1 小卡、只读读数合并大卡 */
  private partitionLayoutControls(controls: PropertyControlDescriptor[]): void {
    this.powerControlList = [];
    this.selectControlList = [];
    this.smallControlList = [];
    this.readoutControlList = [];
    for (let i = 0; i < controls.length; i++) {
      const control = controls[i];
      if (control.isPower && control.type === CapabilityControlType.TOGGLE) {
        this.powerControlList.push(control);
      } else if (control.type === CapabilityControlType.SELECT) {
        this.selectControlList.push(control);
      } else if (control.type === CapabilityControlType.READOUT && !control.writable) {
        this.readoutControlList.push(control);
      } else {
        this.smallControlList.push(control);
      }
    }
  }

  buildActions(spec: MIoTSpecInstance): ActionControlDescriptor[] {
    const result: ActionControlDescriptor[] = [];
    const displayNames = resolveServiceDisplayNames(spec.services);
    for (let i = 0; i < spec.services.length; i++) {
      const actions = buildServiceActions(spec.services[i], displayNames);
      for (let j = 0; j < actions.length; j++) {
        result.push(actions[j]);
      }
    }
    return result;
  }

  buildValueStates(controls: PropertyControlDescriptor[]): void {
    const states: PropertyValueState[] = [];
    for (let i = 0; i < controls.length; i++) {
      states.push({
        key: `${controls[i].siid}.${controls[i].piid}`,
        value: undefined
      });
    }
    this.values = states;
  }

  buildActionArgumentStates(actions: ActionControlDescriptor[]): void {
    const states: ActionArgumentValueState[] = [];
    for (let i = 0; i < actions.length; i++) {
      const args = actions[i].arguments;
      for (let j = 0; j < args.length; j++) {
        const arg = args[j];
        let defaultValue: Object | undefined = undefined;
        if (arg.format === 'bool') {
          defaultValue = false;
        } else if (arg.options.length > 0 && arg.optionValues.length > 0) {
          defaultValue = arg.optionValues[0];
        }
        states.push({
          key: `${actions[i].siid}.${actions[i].aiid}.${arg.piid}`,
          value: defaultValue
        });
      }
    }
    this.actionArgumentValues = states;
  }

  async refreshValues(): Promise<void> {
    if (this.refreshInFlight) {
      return;
    }
    this.refreshInFlight = true;
    this.refreshing = true;
    try {
      if (this.controller === null || this.offline) {
        return;
      }
      const params: DevicePropertyParam[] = [];
      // 折叠区属性同样参与取值，展开「更多功能」时读数立即可见
      const allControls = this.controls.concat(this.extendedControls);
      for (let i = 0; i < allControls.length; i++) {
        if (!allControls[i].readable) {
          continue;
        }
        params.push({
          did: this.did,
          siid: allControls[i].siid,
          piid: allControls[i].piid
        });
      }
      if (params.length === 0) {
        return;
      }
      const results: DevicePropertyResult[] = await this.controller.getProperties(this.did, params);
      const valueMap = new Map<string, Object | undefined>();
      for (let i = 0; i < results.length; i++) {
        valueMap.set(`${results[i].siid}.${results[i].piid}`, results[i].value);
      }
      const newValues: PropertyValueState[] = [];
      for (let i = 0; i < allControls.length; i++) {
        const control = allControls[i];
        newValues.push({
          key: `${control.siid}.${control.piid}`,
          value: valueMap.get(`${control.siid}.${control.piid}`)
        });
      }
      this.values = newValues;
    } catch (err) {
      this.errorMessage = err instanceof Error ? err.message : '刷新属性失败';
      Logger.error('refresh values failed, %{public}s', this.errorMessage);
    } finally {
      this.refreshInFlight = false;
      this.refreshing = false;
    }
  }

  getValue(control: PropertyControlDescriptor): Object | undefined {
    const key = `${control.siid}.${control.piid}`;
    for (let i = 0; i < this.values.length; i++) {
      if (this.values[i].key === key) {
        return this.values[i].value;
      }
    }
    return undefined;
  }

  async setValue(control: PropertyControlDescriptor, value: Object): Promise<void> {
    if (this.controller === null || this.offline) {
      this.errorMessage = '设备离线';
      return;
    }
    const key = `${control.siid}.${control.piid}`;
    const previous: Object | undefined = this.getValue(control);
    this.updateValueState(key, value);
    try {
      await this.controller.setProperty(this.did, control.siid, control.piid, value);
    } catch (err) {
      this.updateValueState(key, previous);
      this.errorMessage = err instanceof Error ? err.message : '设置属性失败';
      Logger.error('set property failed, %{public}s', this.errorMessage);
    }
  }

  async callAction(action: ActionControlDescriptor): Promise<void> {
    if (this.controller === null || this.offline) {
      this.errorMessage = '设备离线';
      return;
    }
    const missing = this.firstMissingArgument(action);
    if (missing !== null) {
      this.errorMessage = `请先设置参数「${missing.label}」`;
      return;
    }
    const key = `${action.siid}.${action.aiid}`;
    this.actionLoadingKey = key;
    try {
      const inList: Object[] = [];
      for (let i = 0; i < action.argumentPiids.length; i++) {
        const piid = action.argumentPiids[i];
        const arg = this.findArgument(action, piid);
        inList.push(this.coerceArgumentValue(arg, this.getActionArgumentValue(action, piid)));
      }
      await this.controller.callAction(this.did, action.siid, action.aiid, inList);
    } catch (err) {
      this.errorMessage = err instanceof Error ? err.message : '执行动作失败';
      Logger.error('call action failed, %{public}s', this.errorMessage);
    } finally {
      this.actionLoadingKey = '';
    }
  }

  async loadPowerInfo(device: XiaomiDevice, spec: MIoTSpecInstance): Promise<void> {
    // 燃气热水器以燃气加热，不展示用电信息（电量统计/当前功率对用户无意义）。
    if (this.isGasWaterHeater(device, spec)) {
      this.showPowerInfo = false;
      return;
    }
    const energyCandidates = this.findPropertiesByKeywords(
      spec,
      ['consumption', 'electric', 'energy', 'kwh'],
      true
    );
    const powerCandidates = this.findPowerCandidates(spec);
    if (energyCandidates.length === 0 && powerCandidates.length === 0) {
      this.showPowerInfo = false;
      return;
    }
    this.showPowerInfo = true;

    if (energyCandidates.length > 0) {
      const now = Math.floor(Date.now() / 1000);
      const dayStart = now - 24 * 3600;
      const monthStart = now - 30 * 24 * 3600;
      let dayStats: Object[] = [];
      let monthStats: Object[] = [];
      for (let i = 0; i < energyCandidates.length; i++) {
        const keys = this.statisticsKeys(energyCandidates[i].key);
        dayStats = await this.tryStatistics(
          device.did,
          keys,
          ['stat_day_v3', 'stat_day'],
          1,
          dayStart,
          now
        );
        monthStats = await this.tryStatistics(
          device.did,
          keys,
          ['stat_month_v3', 'stat_month'],
          30,
          monthStart,
          now
        );
        if (dayStats.length > 0 || monthStats.length > 0) {
          break;
        }
      }
      this.todayEnergy = this.formatStat(dayStats);
      this.monthEnergy = this.formatStat(monthStats);
    } else {
      this.todayEnergy = '--';
      this.monthEnergy = '--';
    }

    if (powerCandidates.length > 0 && this.controller !== null) {
      let powerValue: Object | undefined;
      for (let i = 0; i < powerCandidates.length; i++) {
        try {
          powerValue = await this.controller.getProperty(
            device.did,
            powerCandidates[i].siid,
            powerCandidates[i].piid
          );
        } catch (err) {
          powerValue = undefined;
        }
        const numeric = Number(powerValue);
        if (powerValue !== undefined && powerValue !== null && !Number.isNaN(numeric)) {
          break;
        }
      }
      this.currentPower = powerValue === undefined || powerValue === null
        ? '--'
        : `${String(powerValue)} W`;
    } else {
      this.currentPower = '--';
    }
  }

  private async loadTrendInfo(device: XiaomiDevice, spec: MIoTSpecInstance): Promise<void> {
    this.trendDevice = device;
    this.trendSpec = spec;
    this.trendPoints = [];
    this.trendTitle = '';
    const candidates = this.findTrendCandidates(spec);
    Logger.info('trend candidates did=%{public}s model=%{public}s count=%{public}d keys=%{public}s',
      device.did, device.model, candidates.length,
      candidates.map((c) => c.key).join(','));
    if (candidates.length === 0) {
      return;
    }
    const now = Math.floor(Date.now() / 1000);
    let types: string[] = ['stat_day_v3', 'stat_day'];
    let limit = 7;
    let start = now - 7 * 24 * 3600;
    if (this.trendGranularity === 'hour') {
      types = ['stat_hour_v3', 'stat_hour'];
      limit = 24;
      start = now - 24 * 3600;
    } else if (this.trendGranularity === 'month') {
      types = ['stat_month_v3', 'stat_month'];
      limit = 6;
      start = now - 180 * 24 * 3600;
    }
    for (let i = 0; i < candidates.length; i++) {
      const keys = this.statisticsKeys(candidates[i].key);
      const items = await this.tryStatistics(
        device.did,
        keys,
        types,
        limit,
        start,
        now
      );
      Logger.info('trend fetch did=%{public}s key=%{public}s type=%{public}s items=%{public}d',
        device.did, candidates[i].key, this.trendGranularity, items.length);
      const points = this.parseTrendPoints(items, this.trendGranularity);
      if (points.length >= 2) {
        this.trendTitle = candidates[i].label;
        this.trendPoints = points;
        break;
      }
    }
  }

  private trendWindowLabel(): string {
    if (this.trendGranularity === 'hour') {
      return '近24小时';
    }
    if (this.trendGranularity === 'month') {
      return '近6个月';
    }
    return '近7天';
  }

  async switchTrendGranularity(mode: string): Promise<void> {
    if (this.trendGranularity === mode) {
      return;
    }
    this.trendGranularity = mode;
    const device = this.trendDevice;
    const spec = this.trendSpec;
    if (device === null || spec === null) {
      return;
    }
    await this.loadTrendInfo(device, spec);
  }

  private findTrendCandidates(spec: MIoTSpecInstance): TrendCandidate[] {
    const result: TrendCandidate[] = [];
    for (let i = 0; i < spec.services.length; i++) {
      const service = spec.services[i];
      for (let j = 0; j < service.properties.length; j++) {
        const prop = service.properties[j];
        const format = prop.format.toLowerCase();
        if (format === 'bool' || format === 'string') {
          continue;
        }
        const text = `${prop.name} ${prop.description} ${prop.type} ${prop.unit}`.toLowerCase();
        const isTemp = text.includes('temperature');
        const isHumid = text.includes('humidity');
        const isAir = text.includes('pm2.5') || text.includes('aqi') || text.includes('co2');
        if (isTemp || isHumid || isAir) {
          let label = prop.name;
          if (isTemp) {
            label = '温度';
          } else if (isHumid) {
            label = '湿度';
          } else if (text.includes('co2')) {
            label = 'CO₂';
          } else {
            label = 'PM2.5';
          }
          result.push({ key: `${service.iid}.${prop.iid}`, label: label });
        }
      }
    }
    return result;
  }

  private parseTrendPoints(items: Object[], granularity: string): TrendPoint[] {
    const points: TrendPoint[] = [];
    for (let i = 0; i < items.length; i++) {
      const raw = (items[i] as Record<string, Object>)['value'];
      const text = String(raw ?? '');
      const match = /-?\d+(\.\d+)?/.exec(text);
      if (match === null) {
        continue;
      }
      const value = Number(match[0]);
      if (Number.isNaN(value)) {
        continue;
      }
      const ts = Number((items[i] as Record<string, Object>)['time']);
      let label = '';
      if (!Number.isNaN(ts) && ts > 0) {
        const date = new Date(ts * 1000);
        if (granularity === 'hour') {
          label = `${date.getHours()}时`;
        } else if (granularity === 'month') {
          label = `${date.getMonth() + 1}月`;
        } else {
          label = `${date.getMonth() + 1}/${date.getDate()}`;
        }
      } else {
        label = `${i + 1}`;
      }
      points.push({ label: label, value: value });
    }
    const limit = granularity === 'hour' ? 24 : (granularity === 'month' ? 6 : 7);
    if (points.length > limit) {
      return points.slice(points.length - limit);
    }
    return points;
  }

  private isGasWaterHeater(device: XiaomiDevice, spec: MIoTSpecInstance): boolean {
    const parts: string[] = [device.model, device.name, device.manufacturer];
    for (let i = 0; i < spec.services.length; i++) {
      parts.push(spec.services[i].name);
      parts.push(spec.services[i].description);
      parts.push(spec.services[i].type);
      for (let j = 0; j < spec.services[i].properties.length; j++) {
        parts.push(spec.services[i].properties[j].name);
        parts.push(spec.services[i].properties[j].description);
      }
    }
    const text = parts.join(' ').toLowerCase();
    const isWaterHeater = text.includes('waterheater') ||
      text.includes('water-heater') ||
      text.includes('water heater') ||
      text.includes('热水器');
    const isGas = text.includes('gas') || text.includes('燃气');
    return isWaterHeater && isGas;
  }

  async tryStatistics(
    did: string,
    keys: string[],
    dataTypes: string[],
    limit: number,
    timeStart: number,
    timeEnd: number
  ): Promise<Object[]> {
    for (let keyIndex = 0; keyIndex < keys.length; keyIndex++) {
      for (let i = 0; i < dataTypes.length; i++) {
        try {
          const items = await xiaomiDataService.getDeviceStatistics(
            did,
            keys[keyIndex],
            dataTypes[i],
            limit,
            timeStart,
            timeEnd
          );
          if (items.length > 0) {
            return items;
          }
        } catch (err) {
          // Try the next supported data type or key variant.
        }
      }
    }
    return [] as Object[];
  }

  private statisticsKeys(key: string): string[] {
    // UNVERIFIED: most MIoT statistics use `siid.piid`; some public specs
    // document `prop.siid.piid` for statistics generated from an event. Try
    // both without inventing additional variants.
    return [key, `prop.${key}`];
  }

  findPropertiesByKeywords(
    spec: MIoTSpecInstance,
    keywords: string[],
    numericOnly: boolean
  ): PropertyCandidate[] {
    const result: PropertyCandidate[] = [];
    for (let i = 0; i < spec.services.length; i++) {
      const service = spec.services[i];
      for (let j = 0; j < service.properties.length; j++) {
        const prop = service.properties[j];
        const format = prop.format.toLowerCase();
        if (numericOnly && (format === 'bool' || format === 'string')) {
          continue;
        }
        const text = `${prop.name} ${prop.description} ${prop.type} ${prop.format} ${prop.unit}`.toLowerCase();
        for (let k = 0; k < keywords.length; k++) {
          if (text.includes(keywords[k])) {
            result.push(new PropertyCandidate(
              service.iid,
              prop.iid,
              `${service.iid}.${prop.iid}`
            ));
            break;
          }
        }
      }
    }
    return result;
  }

  private findPowerCandidates(spec: MIoTSpecInstance): PropertyCandidate[] {
    const result: PropertyCandidate[] = [];
    for (let i = 0; i < spec.services.length; i++) {
      const service = spec.services[i];
      for (let j = 0; j < service.properties.length; j++) {
        const prop = service.properties[j];
        const format = prop.format.toLowerCase();
        if (format === 'bool' || format === 'string') {
          continue;
        }
        const text = `${prop.name} ${prop.description} ${prop.type} ${prop.unit}`.toLowerCase();
        const isEnergy = text.includes('consumption') || text.includes('energy') ||
          text.includes('kwh') || text.includes('charge') || text.includes('accumulate');
        const isPower = text.includes('power') || text.includes('watt') ||
          text.includes('current') || text.includes('electric') || text.includes('load');
        if (isPower && !isEnergy) {
          result.push(new PropertyCandidate(
            service.iid,
            prop.iid,
            `${service.iid}.${prop.iid}`
          ));
        }
      }
    }
    return result;
  }

  formatStat(items: Object[]): string {
    if (items.length === 0) {
      return '--';
    }
    // 对近一个月等多日数据求和，得到该时段累计用量
    let sum = 0;
    for (let i = 0; i < items.length; i++) {
      const raw = (items[i] as Record<string, Object>)['value'];
      const text = String(raw ?? '');
      const match = /-?\d+(\.\d+)?/.exec(text);
      if (match !== null) {
        sum += Number(match[0]);
      }
    }
    return Number.isInteger(sum) ? `${sum}` : sum.toFixed(1);
  }

  updateValueState(key: string, value: Object | undefined): void {
    const next: PropertyValueState[] = [];
    for (let i = 0; i < this.values.length; i++) {
      next.push(this.values[i].key === key
        ? { key: this.values[i].key, value: value }
        : this.values[i]);
    }
    this.values = next;
  }

  getActionArgumentValue(action: ActionControlDescriptor, piid: number): Object | undefined {
    const key = `${action.siid}.${action.aiid}.${piid}`;
    for (let i = 0; i < this.actionArgumentValues.length; i++) {
      if (this.actionArgumentValues[i].key === key) {
        return this.actionArgumentValues[i].value;
      }
    }
    return undefined;
  }

  updateActionArgumentValue(action: ActionControlDescriptor, piid: number, value: Object): void {
    const key = `${action.siid}.${action.aiid}.${piid}`;
    const next: ActionArgumentValueState[] = [];
    for (let i = 0; i < this.actionArgumentValues.length; i++) {
      next.push(this.actionArgumentValues[i].key === key
        ? { key: this.actionArgumentValues[i].key, value: value }
        : this.actionArgumentValues[i]);
    }
    this.actionArgumentValues = next;
  }

  private boolOf(input: Object | undefined): boolean {
    return input === true || input === 1 || input === 'true' || input === '1';
  }

  private optionIndexOf(arg: ActionArgumentDescriptor, value: Object | undefined): number {
    for (let i = 0; i < arg.optionValues.length; i++) {
      if (arg.optionValues[i] === value) {
        return i;
      }
    }
    return -1;
  }

  private argumentInputText(action: ActionControlDescriptor, arg: ActionArgumentDescriptor): string {
    return String(this.getActionArgumentValue(action, arg.piid) ?? '');
  }

  private argumentValueText(arg: ActionArgumentDescriptor, value: Object | undefined): string {
    if (arg.format === 'bool') {
      return this.boolOf(value) ? '开' : '关';
    }
    const optionIndex = this.optionIndexOf(arg, value);
    if (optionIndex >= 0) {
      return arg.options[optionIndex];
    }
    const text = String(value ?? '');
    return text.length > 0 ? text : '未设置';
  }

  private actionSummary(action: ActionControlDescriptor): string {
    if (action.arguments.length === 0) {
      return '点击右上角执行';
    }
    const parts: string[] = [];
    for (let i = 0; i < action.arguments.length; i++) {
      const arg = action.arguments[i];
      parts.push(`${arg.label}：${this.argumentValueText(arg, this.getActionArgumentValue(action, arg.piid))}`);
    }
    return `参数 · ${parts.join('，')}`;
  }

  private findArgument(action: ActionControlDescriptor, piid: number): ActionArgumentDescriptor | null {
    for (let i = 0; i < action.arguments.length; i++) {
      if (action.arguments[i].piid === piid) {
        return action.arguments[i];
      }
    }
    return null;
  }

  private firstMissingArgument(action: ActionControlDescriptor): ActionArgumentDescriptor | null {
    for (let i = 0; i < action.arguments.length; i++) {
      const arg = action.arguments[i];
      if (arg.format === 'bool') {
        continue;
      }
      const value = this.getActionArgumentValue(action, arg.piid);
      if (value === undefined || value === null) {
        return arg;
      }
      if (typeof value === 'string' && value.trim().length === 0) {
        return arg;
      }
    }
    return null;
  }

  private coerceArgumentValue(arg: ActionArgumentDescriptor | null, value: Object | undefined): Object {
    if (arg !== null && typeof value === 'string' && (arg.format === 'int' || arg.format === 'float')) {
      const text = value.trim();
      if (/^-?\d+(\.\d+)?$/.test(text)) {
        const num = Number(text);
        return arg.format === 'int' ? Math.round(num) : num;
      }
    }
    return value ?? '';
  }

  openAboutDevice(): void {
    const device = this.device;
    if (device === null) {
      return;
    }
    this.pageInfos.pushPathByName('aboutDevice', new AboutDeviceRouteParam(
      DeviceOverrideStore.getDisplayName(device.did, device.name),
      device.manufacturer,
      device.model,
      device.did,
      device.fwVersion
    ));
  }

  private buildManageRoomOptions(): ManageRoomOption[] {
    const options: ManageRoomOption[] = [];
    const rooms = RoomStore.loadRooms();
    for (let i = 0; i < rooms.length; i++) {
      const room = rooms[i];
      const title = room.floor.length > 0 ? `${room.floor}楼 ${room.name}` : room.name;
      options.push({ id: room.id, title: title });
    }
    return options;
  }

  private openManageSheet(): void {
    const device = this.device;
    if (device === null) {
      return;
    }
    this.manageName = this.deviceName;
    this.manageRooms = this.buildManageRoomOptions();
    this.manageRoomId = '';
    this.manageCurrentRoom = this.currentRoomTitle(device);
    const rooms = RoomStore.loadRooms();
    for (let i = 0; i < rooms.length; i++) {
      if (rooms[i].dids.indexOf(device.did) >= 0) {
        this.manageRoomId = rooms[i].id;
        break;
      }
    }
    this.showManageSheet = true;
    this.mergeCloudRoomOptions(device);
  }

  /** 当前所在房间：优先本地房间，其次云端房间名 */
  private currentRoomTitle(device: XiaomiDevice): string {
    const rooms = RoomStore.loadRooms();
    for (let i = 0; i < rooms.length; i++) {
      if (rooms[i].dids.indexOf(device.did) >= 0) {
        const room = rooms[i];
        return room.floor.length > 0 ? `${room.floor}楼 ${room.name}` : room.name;
      }
    }
    return device.roomName.length > 0 ? device.roomName : '未分配';
  }

  /** 把设备所在家庭的云端房间并入可选项（标记 cloud: 前缀，保存时映射为同名本地房间） */
  private async mergeCloudRoomOptions(device: XiaomiDevice): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const snapshot = await xiaomiDataService.getHomeSnapshot(context, false);
      const homes = JSON.parse(snapshot.homesJson) as XiaomiHome[];
      // 房间归属反查：房间 → dids 列表包含该设备（roomId/roomName 常为空）
      if (this.manageCurrentRoom === '未分配') {
        for (let h = 0; h < homes.length && this.manageCurrentRoom === '未分配'; h++) {
          const rooms = homes[h].roomList;
          for (let r = 0; r < rooms.length; r++) {
            if (rooms[r].dids.indexOf(device.did) >= 0 && rooms[r].name.trim().length > 0) {
              this.manageCurrentRoom = rooms[r].name.trim();
              break;
            }
          }
        }
      }
      let targetHome: XiaomiHome | null = null;
      for (let i = 0; i < homes.length; i++) {
        if (homes[i].homeId === device.homeId) {
          targetHome = homes[i];
          break;
        }
      }
      if (targetHome === null) {
        return;
      }
      const options = this.manageRooms.slice();
      for (let i = 0; i < targetHome.roomList.length; i++) {
        const room = targetHome.roomList[i];
        // 按 roomId 解析设备所在房间（设备列表接口可能不带 roomName）
        if (this.manageCurrentRoom === '未分配' && room.roomId === device.roomId && room.name.length > 0) {
          this.manageCurrentRoom = room.name;
        }
        if (room.name.trim().length === 0) {
          continue;
        }
        let exists = false;
        for (let j = 0; j < options.length; j++) {
          if (options[j].title === room.name) {
            exists = true;
            break;
          }
        }
        if (!exists) {
          options.push({ id: `cloud:${room.roomId}`, title: room.name });
        }
      }
      this.manageRooms = options;
    } catch (err) {
      // 云端房间获取失败时仅展示本地房间
    }
  }

  private saveManageSheet(): void {
    const device = this.device;
    if (device === null) {
      this.showManageSheet = false;
      return;
    }
    const trimmed = this.manageName.trim();
    if (trimmed.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '设备名称不能为空' });
      return;
    }
    DeviceOverrideStore.setNameOverride(device.did, trimmed);
    this.deviceName = DeviceOverrideStore.getDisplayName(device.did, device.name);
    let roomChanged = false;
    const rooms = RoomStore.loadRooms();
    // 云端房间选项映射为同名本地房间（不存在则自动创建并入库）
    let targetRoomId = this.manageRoomId;
    if (targetRoomId.startsWith('cloud:')) {
      let optionTitle = '';
      for (let i = 0; i < this.manageRooms.length; i++) {
        if (this.manageRooms[i].id === targetRoomId) {
          optionTitle = this.manageRooms[i].title;
          break;
        }
      }
      if (optionTitle.length > 0) {
        let localRoom: UserRoom | null = null;
        for (let i = 0; i < rooms.length; i++) {
          if (rooms[i].name === optionTitle) {
            localRoom = rooms[i];
            break;
          }
        }
        if (localRoom === null) {
          localRoom = {
            id: `local_${Date.now()}`,
            floor: '',
            name: optionTitle,
            homeId: device.homeId,
            homeName: '',
            dids: []
          };
          rooms.push(localRoom);
          RoomStore.upsertRoom(localRoom);
        }
        targetRoomId = localRoom.id;
      }
    }
    for (let i = 0; i < rooms.length; i++) {
      const room = rooms[i];
      const had = room.dids.indexOf(device.did) >= 0;
      const should = room.id === targetRoomId;
      if (had === should) {
        continue;
      }
      const nextDids: string[] = [];
      for (let j = 0; j < room.dids.length; j++) {
        if (room.dids[j] !== device.did) {
          nextDids.push(room.dids[j]);
        }
      }
      if (should) {
        nextDids.push(device.did);
      }
      room.dids = nextDids;
      RoomStore.upsertRoom(room);
      roomChanged = true;
    }
    this.showManageSheet = false;
    FeedbackLogService.recordOperation('UI',
      `管理设备 did=${device.did} 改名=${trimmed} 换房=${roomChanged ? '是' : '否'}`);
    this.getUIContext().getPromptAction().showToast({ message: '已保存设备管理' });
  }

  @Builder
  manageSheetBuilder() {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Text('管理设备')
          .fontFamily(this.appFontFamily('管理设备'))
          .fontWeight(this.appFontWeight())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(HwColor.textPrimary)
          .layoutWeight(1)
        IconCircleButton({
          symbol: $r('sys.symbol.xmark'),
          buttonSize: 36,
          iconSize: 18,
          onAction: () => {
            this.showManageSheet = false;
          }
        })
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)
      .padding({ left: HwSpace.lg, right: HwSpace.lg })

      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 8 }) {
            Text('设备名称')
              .fontFamily(this.appFontFamily('设备名称'))
              .fontWeight(this.appFontWeight())
              .fontSize(14)
              .fontColor(MijiaOverviewCardText)
            TextInput({ text: this.manageName, placeholder: '输入新的设备名称' })
              .width('100%')
              .height(44)
              .fontSize(15)
              .fontColor(Color.White)
              .placeholderColor(MijiaOverviewCardText)
              .backgroundColor(Color.Transparent)
              .caretColor(MijiaOverviewCardValue)
              .onChange((value: string) => {
                this.manageName = value;
              })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(14)
          .borderRadius(HwRadius.card)
          .backgroundColor(MijiaOverviewCard)

          Column({ space: 10 }) {
            Text('所在房间')
              .fontFamily(this.appFontFamily('所在房间'))
              .fontWeight(this.appFontWeight())
              .fontSize(14)
              .fontColor(HwColor.textSecondary)
            Text(`当前：${this.manageCurrentRoom}`)
              .fontFamily(this.appFontFamily(`当前：${this.manageCurrentRoom}`))
              .fontWeight(this.appFontWeight())
              .fontSize(14)
              .fontColor(MijiaOverviewCardValue)
            if (this.manageRooms.length === 0) {
              Text('正在加载可选房间…')
                .fontFamily(this.appFontFamily('正在加载可选房间…'))
                .fontWeight(this.appFontWeight())
                .fontSize(13)
                .fontColor(HwColor.textSecondary)
            } else {
              Flex({ wrap: FlexWrap.Wrap }) {
                this.manageRoomChip('', '跟随云端')
                ForEach(this.manageRooms, (room: ManageRoomOption) => {
                  this.manageRoomChip(room.id, room.title)
                }, (room: ManageRoomOption) => room.id)
              }
            }
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')

          Button('保存')
            .width('100%')
            .height(46)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(HwColor.primary)
            .fontColor(Color.White)
            .stateEffect(true)
            .margin({ top: 6 })
            .onClick(() => {
              this.saveManageSheet();
            })
        }
        .width('100%')
        .padding({ left: HwSpace.lg, right: HwSpace.lg, bottom: 24 })
        .margin({ top: 12 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MijiaSheetBackground)
  }

  @Builder
  manageRoomChip(roomId: string, title: string) {
    Text(title)
      .fontFamily(this.appFontFamily(title))
      .fontWeight(this.appFontWeight())
      .fontSize(13)
      // 未选中胶囊为白底，深浅模式下都用固定深色文字保证可读
      .fontColor(this.manageRoomId === roomId ? Color.White : '#333333')
      .height(32)
      .padding({ left: 14, right: 14 })
      .borderRadius(16)
      .backgroundColor(this.manageRoomId === roomId ? HwColor.primary : Color.White)
      .margin({ right: 8, bottom: 8 })
      .onClick(() => {
        this.manageRoomId = roomId;
      })
  }

  private trendTitleText(): string {
    const windowLabel = this.trendWindowLabel();
    return this.trendTitle.length > 0 ? `${windowLabel}趋势：${this.trendTitle}` : `${windowLabel}趋势`;
  }

  @Builder
  trendTab(mode: string, label: string) {
    Text(label)
      .fontFamily(this.appFontFamily(label))
      .fontSize(12)
      .fontWeight(this.trendGranularity === mode ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.trendGranularity === mode ? HwColor.textPrimary : HwColor.textSecondary)
      .padding({ left: 12, right: 12, top: 5, bottom: 5 })
      .borderRadius(14)
      .backgroundColor(this.trendGranularity === mode ? MijiaOverviewCardPressed : Color.Transparent)
      .border({ width: 1, color: this.trendGranularity === mode ? Color.Transparent : '#337A8089' })
      .onClick(() => {
        this.switchTrendGranularity(mode);
      })
  }

  @Builder
  trendChart() {
    if (this.trendPoints.length >= 2) {
      Column({ space: 10 }) {
      Row() {
        Text(this.trendTitleText())
          .fontFamily(this.appFontFamily(this.trendTitleText()))
          .fontWeight(this.appFontWeight())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(HwColor.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')

      Row({ space: 8 }) {
        this.trendTab('day', '近7天')
        this.trendTab('hour', '近24小时')
        this.trendTab('month', '近6个月')
        Blank()
      }
      .width('100%')

      Row({ space: 8 }) {
        ForEach(this.trendPoints, (point: TrendPoint, index: number) => {
          this.trendBar(point, index)
        }, (point: TrendPoint, index: number) => `${index}:${point.label}:${point.value}`)
      }
      .width('100%')
      .height(120)
      .alignItems(VerticalAlign.Bottom)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(HwSpace.lg)
    .borderRadius(HwRadius.card)
    .backgroundColor(MijiaOverviewCard)
    .border({ width: 1, color: '#24FFFFFF' })
    .clip(true)
    }
  }

  @Builder
  trendBar(point: TrendPoint, index: number) {
    Column({ space: 4 }) {
      if (this.trendPoints.length <= 12) {
        Text(this.formatTrendValue(point.value))
          .fontFamily(this.appFontFamily(this.formatTrendValue(point.value)))
          .fontWeight(this.appFontWeight())
          .fontSize(9)
          .fontColor(MijiaOverviewCardText)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      Column()
        .width('100%')
        .height(this.trendBarHeight(point.value))
        .borderRadius(3)
        .backgroundColor(HwColor.primary)
      Text(point.label)
        .fontFamily(this.appFontFamily(point.label))
        .fontWeight(this.appFontWeight())
        .fontSize(9)
        .fontColor(MijiaOverviewCardText)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.End)
  }

  private trendMax(): number {
    let max = 0;
    for (let i = 0; i < this.trendPoints.length; i++) {
      const v = this.trendPoints[i].value;
      if (v > max) {
        max = v;
      }
    }
    return max <= 0 ? 1 : max;
  }

  private trendBarHeight(value: number): number {
    const chartHeight = 84;
    const h = (value / this.trendMax()) * chartHeight;
    return h < 6 ? 6 : h;
  }

  private formatTrendValue(value: number): string {
    if (Number.isInteger(value)) {
      return `${value}`;
    }
    return value.toFixed(1);
  }

  /**
   * 生成属性卡片布局：同服务的只读读数（如电流/电压/功率）合并为 1×2 卡片，
   * 其余控件保持 1×1 卡片。读取不到数值的只读项会被过滤隐藏。
   */
  private buildLayoutItems(controls: PropertyControlDescriptor[]): ControlLayoutItem[] {
    const items: ControlLayoutItem[] = [];
    const groups = new Map<number, PropertyControlDescriptor[]>();
    const singles: PropertyControlDescriptor[] = [];
    for (let i = 0; i < controls.length; i++) {
      const control = controls[i];
      if (control.type === CapabilityControlType.READOUT && !control.writable) {
        let arr = groups.get(control.siid);
        if (arr === undefined) {
          arr = [];
          groups.set(control.siid, arr);
        }
        arr.push(control);
      } else {
        singles.push(control);
      }
    }
    const groupKeys = Array.from(groups.keys());
    for (let i = 0; i < groupKeys.length; i++) {
      const group = groups.get(groupKeys[i]) as PropertyControlDescriptor[];
      if (group.length <= 1) {
        for (let j = 0; j < group.length; j++) {
          singles.push(group[j]);
        }
      } else {
        items.push({
          key: `group_${groupKeys[i]}`,
          kind: 'group',
          controls: group
        });
      }
    }
    for (let i = 0; i < singles.length; i++) {
      const control = singles[i];
      items.push({
        key: `single_${control.siid}_${control.piid}`,
        kind: 'single',
        controls: [control]
      });
    }
    return items;
  }

  private hasReadableValue(control: PropertyControlDescriptor): boolean {
    const value = this.getValue(control);
    return value !== undefined && value !== null && String(value).trim().length > 0;
  }

  private groupValueText(control: PropertyControlDescriptor): string {
    const value = this.getValue(control);
    if (value === undefined || value === null) {
      return '--';
    }
    if (control.options.length > 0) {
      const idx = control.optionValues.indexOf(value);
      if (idx >= 0) {
        return control.options[idx];
      }
    }
    return `${String(value)}${control.unit}`;
  }

  // 1×1 属性卡片：读取不到数值的只读项自动隐藏
  @Builder
  singleControlCard(control: PropertyControlDescriptor) {
    if (control.type !== CapabilityControlType.READOUT || this.hasReadableValue(control)) {
      Column() {
        PropertyControl({
          control: control,
          value: this.getValue(control),
          compact: true,
          onChanged: (value: Object) => {
            this.setValue(control, value);
          }
        })
      }
      .width('48.5%')
      .margin({ bottom: 10 })
    }
  }

  // 1×2 分组卡片：同服务只读读数横向排列，无值的子项隐藏
  @Builder
  readoutGroupCard(controls: PropertyControlDescriptor[]) {
    if (this.groupVisibleCount(controls) > 0) {
      Row({ space: 8 }) {
        ForEach(controls, (control: PropertyControlDescriptor) => {
          if (this.hasReadableValue(control)) {
            Column({ space: 4 }) {
              Text(control.label)
                .fontFamily(this.appFontFamily(control.label))
                .fontWeight(this.appFontWeight())
                .fontSize(12)
                .fontColor(MijiaOverviewCardText)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
              Text(this.groupValueText(control))
                .fontFamily(this.appFontFamily(this.groupValueText(control)))
                .fontWeight(this.appFontWeight())
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(MijiaOverviewCardValue)
                .maxLines(2)
                .minFontSize(12)
                .maxFontSize(18)
                .heightAdaptivePolicy(TextHeightAdaptivePolicy.MIN_FONT_SIZE_FIRST)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
        }, (control: PropertyControlDescriptor) => `${control.siid}.${control.piid}`)
      }
      .width('100%')
      .constraintSize({ minHeight: 96 })
      .alignItems(VerticalAlign.Center)
      .padding(HwSpace.md)
      .borderRadius(HwRadius.card)
      .backgroundColor(MijiaOverviewCard)
      .border({ width: 1, color: '#24FFFFFF' })
      .clip(true)
      .margin({ bottom: 10 })
    }
  }

  private groupVisibleCount(controls: PropertyControlDescriptor[]): number {
    let count = 0;
    for (let i = 0; i < controls.length; i++) {
      if (this.hasReadableValue(controls[i])) {
        count++;
      }
    }
    return count;
  }

  // 实时状态 / 动作 页签：标题即开关，点击切换下方卡片，默认展示实时状态。
  @Builder
  tabPill(tab: string, label: string) {
    Text(label)
      .fontFamily(this.appFontFamily(label))
      .fontWeight(this.appFontWeight())
      .fontSize(16)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.activeTab === tab ? Color.White : HwColor.textPrimary)
      .padding({ left: 26, right: 26, top: 10, bottom: 10 })
      .borderRadius(HwRadius.control)
      .backgroundColor(this.activeTab === tab ? HwColor.primary : '#14000000')
      .onClick(() => {
        if (this.activeTab !== tab) {
          this.activeTab = tab;
          this.scroller.scrollTo({
            xOffset: 0,
            yOffset: 0,
            animation: { duration: 200, curve: Curve.EaseOut }
          });
        }
      })
  }

  private boolValueOf(control: PropertyControlDescriptor): boolean {
    return this.getValue(control) === true;
  }

  /** 温湿度计判断：趋势图仅对温湿度计类设备展示（对齐米家） */
  private isTempHumiditySensor(device: XiaomiDevice): boolean {
    const text = `${device.model} ${device.name}`.toLowerCase();
    return text.includes('sensor') || text.includes('thermometer') || text.includes('hygro') ||
      text.includes('miaomiaoce') || text.includes('温湿度') || text.includes('温度计') ||
      text.includes('湿度计');
  }

  private showTrendChart(): boolean {
    return this.trendPoints.length >= 2 && this.device !== null && this.isTempHumiditySensor(this.device);
  }

  private anyReadableValue(readouts: PropertyControlDescriptor[]): boolean {
    for (let i = 0; i < readouts.length; i++) {
      if (this.hasReadableValue(readouts[i])) {
        return true;
      }
    }
    return false;
  }

  // 电源卡：占满整排，圆形电源按钮 + 名称/状态，对齐米家「关闭」行
  @Builder
  powerCard(control: PropertyControlDescriptor) {
    Row({ space: 14 }) {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(56)
          .height(56)
          .fill(this.boolValueOf(control) ? MijiaOnButton : MijiaOffButton)
        SymbolGlyph($r('sys.symbol.power'))
          .fontSize(22)
          .fontColor([this.boolValueOf(control) ? Color.White : MijiaOverviewCardText])
      }
      .width(56)
      .height(56)
      .onClick(() => {
        this.setValue(control, !this.boolValueOf(control));
      })

      Column({ space: 3 }) {
        Text('电源')
          .fontFamily(this.appFontFamily('电源'))
          .fontWeight(this.appFontWeight())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(MijiaOverviewCardValue)
        Text(this.boolValueOf(control) ? '已开启' : '已关闭')
          .fontFamily(this.appFontFamily(this.boolValueOf(control) ? '已开启' : '已关闭'))
          .fontWeight(this.appFontWeight())
          .fontSize(13)
          .fontColor(MijiaOverviewCardText)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(HwSpace.md)
    .borderRadius(HwRadius.card)
    .backgroundColor(MijiaOverviewCard)
    .border({ width: 1, color: '#24FFFFFF' })
    .clip(true)
  }

  // 只读读数合并大卡：当前温度/湿度/功率等并排展示（对齐米家用电信息卡）
  @Builder
  readoutSummaryCard(readouts: PropertyControlDescriptor[]) {
    Flex({
      wrap: FlexWrap.Wrap,
      justifyContent: FlexAlign.SpaceBetween
    }) {
      ForEach(readouts, (readout: PropertyControlDescriptor) => {
        if (this.hasReadableValue(readout)) {
          Column({ space: 4 }) {
            Text(readout.label)
              .fontFamily(this.appFontFamily(readout.label))
              .fontWeight(this.appFontWeight())
              .fontSize(12)
              .fontColor(MijiaOverviewCardText)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
            Text(this.groupValueText(readout))
              .fontFamily(this.appFontFamily(this.groupValueText(readout)))
              .fontWeight(this.appFontWeight())
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(MijiaOverviewCardValue)
              .maxLines(2)
              .minFontSize(12)
              .maxFontSize(20)
              .heightAdaptivePolicy(TextHeightAdaptivePolicy.MIN_FONT_SIZE_FIRST)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .constraintSize({ minWidth: '30%' })
          .margin({ bottom: 8 })
        }
      }, (readout: PropertyControlDescriptor) => `ro_${readout.siid}_${readout.piid}`)
    }
    .width('100%')
    .padding(HwSpace.lg)
    .borderRadius(HwRadius.card)
    .backgroundColor(MijiaOverviewCard)
    .border({ width: 1, color: '#24FFFFFF' })
    .clip(true)
  }

  // 「更多功能」折叠入口：样式对齐页面既有 MijiaOverviewCard 卡片，
  // 行为对齐米家扩展键——默认收起，点击展开扩展属性网格。
  @Builder
  extendedToggleRow() {
    Row({ space: 10 }) {
      Text(`更多功能 (${this.extendedControls.length})`)
        .fontFamily(this.appFontFamily(`更多功能 (${this.extendedControls.length})`))
        .fontWeight(this.appFontWeight())
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(MijiaOverviewCardText)
        .layoutWeight(1)
      Text('›')
        .fontFamily(this.appFontFamily('›'))
        .fontWeight(this.appFontWeight())
        .fontSize(20)
        .fontColor(MijiaOverviewCardText)
        .rotate({ angle: this.showExtended ? 90 : 0 })
    }
    .width('100%')
    .padding(HwSpace.md)
    .borderRadius(HwRadius.card)
    .backgroundColor(MijiaOverviewCard)
    .border({ width: 1, color: '#24FFFFFF' })
    .clip(true)
    .onClick(() => {
      this.showExtended = !this.showExtended;
    })
  }

  // 动作区：仅在「动作」页签下展示，集中收纳设备 spec 声明的动作（aiid）。
  @Builder
  advancedActionsSection() {
    Column({ space: 12 }) {
      ForEach(this.actions, (action: ActionControlDescriptor) => {
        this.actionItem(action)
      }, (action: ActionControlDescriptor) => `${action.siid}.${action.aiid}`)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // 单个动作：标题 + 实时参数摘要 + 参数控件 + 执行按钮合并为一张自解释卡片
  @Builder
  actionItem(action: ActionControlDescriptor) {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.bolt'))
          .fontSize(18)
          .fontColor([HwColor.primary])
        Column({ space: 3 }) {
          Text(action.label)
            .fontFamily(this.appFontFamily(action.label))
            .fontWeight(this.appFontWeight())
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(MijiaOverviewCardText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.actionSummary(action))
            .fontFamily(this.appFontFamily(this.actionSummary(action)))
            .fontWeight(this.appFontWeight())
            .fontSize(12)
            .fontColor(MijiaOverviewCardText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        this.actionExecuteButton(action)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      ForEach(action.arguments, (arg: ActionArgumentDescriptor) => {
        this.actionArgumentEditor(action, arg)
      }, (arg: ActionArgumentDescriptor) => `${arg.piid}`)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(HwSpace.md)
    .borderRadius(HwRadius.card)
    .backgroundColor(MijiaOverviewCard)
    .border({ width: 1, color: '#24FFFFFF' })
    .clip(true)
  }

  @Builder
  actionExecuteButton(action: ActionControlDescriptor) {
    Row({ space: 5 }) {
      if (this.actionLoadingKey === `${action.siid}.${action.aiid}`) {
        LoadingProgress()
          .width(14)
          .height(14)
          .color(Color.White)
        Text('执行中')
          .fontFamily(this.appFontFamily('执行中'))
          .fontWeight(this.appFontWeight())
          .fontSize(13)
          .fontColor(Color.White)
      } else {
        SymbolGlyph($r('sys.symbol.bolt'))
          .fontSize(13)
          .fontColor([Color.White])
        Text('执行')
          .fontFamily(this.appFontFamily('执行'))
          .fontWeight(this.appFontWeight())
          .fontSize(13)
          .fontColor(Color.White)
      }
    }
    .alignItems(VerticalAlign.Center)
    .padding({ left: 14, right: 14, top: 8, bottom: 8 })
    .borderRadius(HwRadius.control)
    .backgroundColor(HwColor.primary)
    .onClick(() => {
      this.callAction(action);
    })
  }

  // 参数行：标明参数名与当前值；bool 为开关、枚举为选项、其它为输入框
  @Builder
  actionArgumentEditor(action: ActionControlDescriptor, arg: ActionArgumentDescriptor) {
    if (arg.format === 'bool') {
      Row({ space: 10 }) {
        Text(arg.label)
          .fontFamily(this.appFontFamily(arg.label))
          .fontWeight(this.appFontWeight())
          .fontSize(13)
          .fontColor(MijiaOverviewCardText)
          .layoutWeight(1)
        Text(this.boolOf(this.getActionArgumentValue(action, arg.piid)) ? '开' : '关')
          .fontFamily(this.appFontFamily('开'))
          .fontWeight(this.appFontWeight())
          .fontSize(13)
          .fontColor(MijiaOverviewCardValue)
        Toggle({ type: ToggleType.Switch, isOn: this.boolOf(this.getActionArgumentValue(action, arg.piid)) })
          .selectedColor(HwColor.primary)
          .onChange((isOn: boolean) => {
            this.updateActionArgumentValue(action, arg.piid, isOn);
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    } else if (arg.options.length > 0) {
      Text(arg.label)
        .fontFamily(this.appFontFamily(arg.label))
        .fontWeight(this.appFontWeight())
        .fontSize(13)
        .fontColor(MijiaOverviewCardText)
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(arg.options, (option: string, index?: number) => {
          Text(option)
            .fontFamily(this.appFontFamily(option))
            .fontWeight(this.appFontWeight())
            .fontSize(13)
            .fontColor(this.optionIndexOf(arg, this.getActionArgumentValue(action, arg.piid)) === (index ?? -1)
              ? MijiaOverviewCardValue : MijiaOverviewCardText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .borderRadius(HwRadius.control)
            .backgroundColor(this.optionIndexOf(arg, this.getActionArgumentValue(action, arg.piid)) === (index ?? -1)
              ? '#263379B7' : '#1A000000')
            .border({
              width: 1,
              color: this.optionIndexOf(arg, this.getActionArgumentValue(action, arg.piid)) === (index ?? -1)
                ? MijiaOverviewCardValue : '#24FFFFFF'
            })
            .margin({ right: 8, bottom: 8 })
            .onClick(() => {
              this.updateActionArgumentValue(action, arg.piid, arg.optionValues[index ?? 0]);
            })
        }, (option: string) => option)
      }
      .width('100%')
    } else {
      Text(arg.label)
        .fontFamily(this.appFontFamily(arg.label))
        .fontWeight(this.appFontWeight())
        .fontSize(13)
        .fontColor(MijiaOverviewCardText)
      TextInput({ text: this.argumentInputText(action, arg) })
        .type(arg.format === 'int' || arg.format === 'float' ? InputType.Number : InputType.Normal)
        .onChange((text: string) => {
          this.updateActionArgumentValue(action, arg.piid, text);
        })
    }
  }

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        AppBackground()

        Refresh({ refreshing: $$this.refreshing }) {
        Scroll(this.scroller) {
          Column({ space: 14 }) {
            Blank().height(this.topOffset())

            if (this.offline) {
              Text('设备离线')
                .fontFamily(this.appFontFamily('设备离线'))
                .fontWeight(this.appFontWeight())
                .fontSize(16)
                .fontColor(HwColor.danger)
            }

            if (this.errorMessage.length > 0) {
              Text(this.errorMessage)
                .fontFamily(this.appFontFamily(this.errorMessage))
                .fontWeight(this.appFontWeight())
                .fontSize(14)
                .fontColor(HwColor.danger)
            }

            if (!this.loading && !this.offline) {
              if (this.showPowerInfo) {
                Column({ space: 6 }) {
                  Text('用电信息')
                    .fontFamily(this.appFontFamily('用电信息'))
                    .fontWeight(this.appFontWeight())
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Color.White)
                  Text(`今日用电：${this.todayEnergy}`)
                    .fontFamily(this.appFontFamily(`今日用电：${this.todayEnergy}`))
                    .fontWeight(this.appFontWeight())
                    .fontSize(14)
                    .fontColor(MijiaOverviewCardText)
                  Text(`近一个月用电：${this.monthEnergy}`)
                    .fontFamily(this.appFontFamily(`近一个月用电：${this.monthEnergy}`))
                    .fontWeight(this.appFontWeight())
                    .fontSize(14)
                    .fontColor(MijiaOverviewCardText)
                  Text(`当前功率：${this.currentPower}`)
                    .fontFamily(this.appFontFamily(`当前功率：${this.currentPower}`))
                    .fontWeight(this.appFontWeight())
                    .fontSize(14)
                    .fontColor(MijiaOverviewCardText)
                }
                .alignItems(HorizontalAlign.Start)
                .width('100%')
                .padding(HwSpace.lg)
                .borderRadius(HwRadius.card)
                .backgroundColor(MijiaOverviewCard)
                .border({ width: 1, color: '#24FFFFFF' })
                .clip(true)
              }

              // 趋势图仅温湿度计展示
              if (this.showTrendChart()) {
                this.trendChart()
              }

              if (this.actions.length > 0) {
                Row({ space: 12 }) {
                  this.tabPill('status', '实时状态')
                  this.tabPill('actions', '动作')
                }
                .width('100%')
                .justifyContent(FlexAlign.Center)
              } else {
                Text('实时状态')
                  .fontFamily(this.appFontFamily('实时状态'))
                  .fontWeight(this.appFontWeight())
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(HwColor.textPrimary)
              }

              // 红外遥控虚拟设备（单向通信、无可读属性）：实时状态为空时给出引导，
              // 指引用户到「动作」页签发送指令，而不是白屏。
              if (this.activeTab === 'status' && this.controls.length === 0 &&
                this.extendedControls.length === 0 && this.actions.length > 0) {
                Text('红外遥控设备：单向通信、无实时状态反馈，请切换到「动作」页签发送指令')
                  .fontFamily(this.appFontFamily('红外遥控设备'))
                  .fontWeight(this.appFontWeight())
                  .fontSize(14)
                  .fontColor(MijiaOverviewCardText)
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding(HwSpace.lg)
              }

              // 布局：电源整排卡 → 模式类整排卡 → 1×1 小卡（滑块/开关）
              // → 只读读数合并大卡 → 更多功能折叠区
              if (this.activeTab === 'status' && this.powerControlList.length > 0) {
                this.powerCard(this.powerControlList[0])
              }

              if (this.activeTab === 'status' && this.selectControlList.length > 0) {
                ForEach(this.selectControlList, (select: PropertyControlDescriptor) => {
                  PropertyControl({
                    control: select,
                    value: this.getValue(select),
                    compact: false,
                    selectSingleRow: true,
                    onChanged: (value: Object) => {
                      this.setValue(select, value);
                    }
                  })
                }, (select: PropertyControlDescriptor) => `sel_${select.siid}_${select.piid}`)
              }

              if (this.activeTab === 'status' && this.smallControlList.length > 0) {
                Flex({
                  wrap: FlexWrap.Wrap,
                  justifyContent: FlexAlign.SpaceBetween,
                  alignItems: ItemAlign.Start
                }) {
                  ForEach(this.buildLayoutItems(this.smallControlList), (item: ControlLayoutItem) => {
                    if (item.kind === 'group') {
                      this.readoutGroupCard(item.controls)
                    } else {
                      this.singleControlCard(item.controls[0])
                    }
                  }, (item: ControlLayoutItem) => item.key)
                }
                .width('100%')
              }

              if (this.activeTab === 'status' && this.readoutControlList.length > 0 &&
                this.anyReadableValue(this.readoutControlList)) {
                this.readoutSummaryCard(this.readoutControlList)
              }

              // 「更多功能」折叠区：收纳原版米家明面之外的扩展属性，点击展开/收起。
              if (this.activeTab === 'status' && this.extendedControls.length > 0) {
                this.extendedToggleRow()
              }
              if (this.activeTab === 'status' && this.showExtended && this.extendedControls.length > 0) {
                Flex({
                  wrap: FlexWrap.Wrap,
                  justifyContent: FlexAlign.SpaceBetween,
                  alignItems: ItemAlign.Start
                }) {
                  ForEach(this.buildLayoutItems(this.extendedControls), (item: ControlLayoutItem) => {
                    if (item.kind === 'group') {
                      this.readoutGroupCard(item.controls)
                    } else {
                      this.singleControlCard(item.controls[0])
                    }
                  }, (item: ControlLayoutItem) => `ext_${item.key}`)
                }
                .width('100%')
              }

              if (this.activeTab === 'actions') {
                this.advancedActionsSection()
              }
            }

            Blank()
              .height(this.navigationBarHeight + 24)
          }
          .width('100%')
          .padding({ left: this.detailPadding(), right: this.detailPadding() })
        }
        .width('100%')
        .height('100%')
        .align(this.cardsFromTop ? Alignment.Top : Alignment.Center)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
        }
        .width('100%')
        .height('100%')
        .onRefreshing(() => {
          this.refreshValues();
        })

        Row({ space: 10 }) {
          IconCircleButton({
            symbol: $r('sys.symbol.chevron_left'),
            tint: '#FFFFFF',
            onAction: () => {
              this.pageInfos.pop();
            }
          })
          Text(this.deviceName)
            .fontFamily(this.appFontFamily(this.deviceName))
            .fontWeight(this.appFontWeight())
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          IconCircleButton({
            symbol: $r('sys.symbol.square_and_pencil'),
            tint: '#FFFFFF',
            onAction: () => {
              this.openManageSheet();
            }
          })
          IconCircleButton({
            symbol: $r('sys.symbol.arrow_counterclockwise'),
            tint: '#FFFFFF',
            buttonEnabled: !this.refreshing,
            spinning: this.refreshing,
            onAction: () => {
              this.refreshValues();
            }
          })
          IconCircleButton({
            symbol: $r('sys.symbol.info_circle'),
            tint: '#FFFFFF',
            onAction: () => {
              this.openAboutDevice();
            }
          })
        }
        .width('100%')
        .height((this.isWearable ? 52 : 56) + this.statusBarHeight)
        .padding({ left: this.isWearable ? 10 : 16, right: this.isWearable ? 10 : 16, top: this.statusBarHeight })
        .linearGradient({
          angle: 90,
          colors: [['#E62F658C', 0], ['#E63B7094', 0.5], ['#E646789C', 1]]
        })
        .backgroundEffect({ radius: 30, saturation: 1.5, color: '#33FFFFFF' })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
      .bindSheet($$this.showManageSheet, this.manageSheetBuilder(), {
        height: SheetSize.MEDIUM,
        dragBar: true,
        backgroundColor: MijiaSheetBackground,
        showClose: false
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isDarkMode ? HwColor.backgroundDark : HwColor.background)
    .clip(this.isWearable)
    .borderRadius(this.isWearable ? '50%' : 0)
    .hideTitleBar(true)
    .hideBackButton(true)
    .hideToolBar(true, true)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .keyboardShortcut(FunctionKey.ESC, [], () => {
      this.pageInfos.pop();
    })
  }
}

class PropertyCandidate {
  readonly siid: number;
  readonly piid: number;
  readonly key: string;

  constructor(siid: number, piid: number, key: string) {
    this.siid = siid;
    this.piid = piid;
    this.key = key;
  }
}
