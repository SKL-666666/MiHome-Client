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
import {
  ActionControlDescriptor,
  ActionArgumentDescriptor,
  buildServiceActions,
  buildServiceControls,
  CapabilityControlType,
  PropertyControlDescriptor
} from '../components/CapabilityRenderer';
import { ActionControl } from '../components/ActionControl';
import { ActionArgumentControl } from '../components/ActionArgumentControl';
import { PropertyControl } from '../components/PropertyControl';
import { DeviceController } from '../controllers/DeviceController';
import { DevicePropertyParam, DevicePropertyResult } from '../controllers/DeviceTransport';
import { MIoTSpecInstance } from '../models/MIotSpecModels';
import { XiaomiDevice } from '../models/XiaomiHomeModels';
import { xiaomiDataService } from '../services/XiaomiDataService';
import { FeedbackLogService } from '../services/FeedbackLogService';
import { Logger } from '../utils/Logger';
import { HwColor, HwRadius, HwSpace, MijiaOverviewCard, MijiaOverviewCardText, MijiaOverviewCardValue } from '../utils/DesignTokens';
import { AppBackground } from '../components/AppBackground';
import { IconCircleButton } from '../components/IconCircleButton';
import { AboutDeviceRouteParam, DeviceDetailRouteParam } from '../models/NavRouteParams';

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
  @State actions: ActionControlDescriptor[] = [];
  @State values: PropertyValueState[] = [];
  @State loading: boolean = true;
  @State refreshing: boolean = false;
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
      this.deviceName = device.name;
      this.offline = !device.online;
      FeedbackLogService.recordOperation('PAGE',
        `设备详情: ${device.name} did=${device.did} model=${device.model} 在线=${device.online ? '是' : '否'}`);
      if (device.online) {
        const spec = await xiaomiDataService.getDeviceSpecForDevice(device);
        this.controls = this.buildControls(spec);
        this.actions = this.buildActions(spec);
        this.buildValueStates(this.controls);
        this.buildActionArgumentStates(this.actions);
        this.controller = await xiaomiDataService.getDeviceController();
        await this.refreshValues();
        this.recordDeviceValues();
        await this.loadPowerInfo(device, spec);
        await this.loadTrendInfo(device, spec);
      } else {
        this.controls = [];
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

  buildControls(spec: MIoTSpecInstance): PropertyControlDescriptor[] {
    const result: PropertyControlDescriptor[] = [];
    // 去重：同标签 + 同类型 + 同格式的重复控件（设备 spec 常重复声明同一开关），
    // 只保留第一个，保证“有多少功能就显示多少按钮”，避免多个相同的“开关”。
    const seen = new Set<string>();
    for (let i = 0; i < spec.services.length; i++) {
      const controls = buildServiceControls(spec.services[i]);
      for (let j = 0; j < controls.length; j++) {
        const signature = `${controls[j].label}|${controls[j].type}|${controls[j].format}`;
        if (seen.has(signature)) {
          continue;
        }
        seen.add(signature);
        result.push(controls[j]);
      }
    }
    return result;
  }

  buildActions(spec: MIoTSpecInstance): ActionControlDescriptor[] {
    const result: ActionControlDescriptor[] = [];
    for (let i = 0; i < spec.services.length; i++) {
      const actions = buildServiceActions(spec.services[i]);
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
        states.push({
          key: `${actions[i].siid}.${actions[i].aiid}.${args[j].piid}`,
          value: undefined
        });
      }
    }
    this.actionArgumentValues = states;
  }

  async refreshValues(): Promise<void> {
    if (this.controller === null || this.offline) {
      return;
    }
    this.refreshing = true;
    try {
      const params: DevicePropertyParam[] = [];
      for (let i = 0; i < this.controls.length; i++) {
        if (!this.controls[i].readable) {
          continue;
        }
        params.push({
          did: this.did,
          siid: this.controls[i].siid,
          piid: this.controls[i].piid
        });
      }
      let results: DevicePropertyResult[] = [];
      if (params.length > 0) {
        try {
          results = await this.controller.getProperties(this.did, params);
        } catch (err) {
          results = [];
        }
      }
      const valueMap = new Map<string, Object | undefined>();
      for (let i = 0; i < results.length; i++) {
        valueMap.set(`${results[i].siid}.${results[i].piid}`, results[i].value);
      }
      const newValues: PropertyValueState[] = [];
      for (let i = 0; i < this.controls.length; i++) {
        const control = this.controls[i];
        newValues.push({
          key: `${control.siid}.${control.piid}`,
          value: valueMap.get(`${control.siid}.${control.piid}`)
        });
      }
      this.values = newValues;
    } finally {
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
      if (previous !== undefined) {
        this.updateValueState(key, previous);
      }
      this.errorMessage = err instanceof Error ? err.message : '设置属性失败';
      Logger.error('set property failed, %{public}s', this.errorMessage);
    }
  }

  async callAction(action: ActionControlDescriptor): Promise<void> {
    if (this.controller === null || this.offline) {
      this.errorMessage = '设备离线';
      return;
    }
    const key = `${action.siid}.${action.aiid}`;
    this.actionLoadingKey = key;
    try {
      const inList: Object[] = [];
      for (let i = 0; i < action.argumentPiids.length; i++) {
        inList.push(this.getActionArgumentValue(action, action.argumentPiids[i]) ?? '');
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
    this.trendPoints = [];
    this.trendTitle = '';
    const candidates = this.findTrendCandidates(spec);
    if (candidates.length === 0) {
      return;
    }
    const now = Math.floor(Date.now() / 1000);
    const weekStart = now - 7 * 24 * 3600;
    for (let i = 0; i < candidates.length; i++) {
      const keys = this.statisticsKeys(candidates[i].key);
      const items = await this.tryStatistics(
        device.did,
        keys,
        ['stat_day_v3', 'stat_day'],
        7,
        weekStart,
        now
      );
      const points = this.parseTrendPoints(items);
      if (points.length >= 2) {
        this.trendTitle = candidates[i].label;
        this.trendPoints = points;
        break;
      }
    }
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

  private parseTrendPoints(items: Object[]): TrendPoint[] {
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
        label = `${date.getMonth() + 1}/${date.getDate()}`;
      } else {
        label = `${i + 1}`;
      }
      points.push({ label: label, value: value });
    }
    if (points.length > 7) {
      return points.slice(points.length - 7);
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

  updateValueState(key: string, value: Object): void {
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

  openAboutDevice(): void {
    const device = this.device;
    if (device === null) {
      return;
    }
    this.pageInfos.pushPathByName('aboutDevice', new AboutDeviceRouteParam(
      device.name,
      device.manufacturer,
      device.model,
      device.did,
      device.fwVersion
    ));
  }

  @Builder
  trendChart() {
    if (this.trendPoints.length >= 2) {
      Column({ space: 10 }) {
      Row() {
        Text(this.trendTitle.length > 0 ? `近7天趋势：${this.trendTitle}` : '近7天趋势')
          .fontFamily(this.appFontFamily(this.trendTitle.length > 0 ? `近7天趋势：${this.trendTitle}` : '近7天趋势'))
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
        ForEach(this.trendPoints, (point: TrendPoint, index: number) => {
          this.trendBar(point, index)
        }, (point: TrendPoint, index: number) => `${index}`)
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
      Text(this.formatTrendValue(point.value))
        .fontFamily(this.appFontFamily(this.formatTrendValue(point.value)))
        .fontWeight(this.appFontWeight())
        .fontSize(9)
        .fontColor(MijiaOverviewCardText)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
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
  private buildLayoutItems(): ControlLayoutItem[] {
    const items: ControlLayoutItem[] = [];
    const groups = new Map<number, PropertyControlDescriptor[]>();
    const singles: PropertyControlDescriptor[] = [];
    for (let i = 0; i < this.controls.length; i++) {
      const control = this.controls[i];
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

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        AppBackground()

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

            if (this.loading) {
              Text('加载中…')
                .fontFamily(this.appFontFamily('加载中…'))
                .fontWeight(this.appFontWeight())
                .fontSize(14)
                .fontColor(HwColor.textSecondary)
                .padding({ top: 24, bottom: 24 })
            } else if (!this.offline) {
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

              this.trendChart()

              Text('实时状态')
                .fontFamily(this.appFontFamily('实时状态'))
                .fontWeight(this.appFontWeight())
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(HwColor.textPrimary)

              // 属性卡片：1×1 与 1×2 混合布局。
              // 相关的只读读数（如电流/电压/功率）合并为 1×2 卡片；
              // 读取不到数值的只读项自动隐藏。
              if (this.controls.length > 0) {
                Flex({
                  wrap: FlexWrap.Wrap,
                  justifyContent: FlexAlign.SpaceBetween,
                  alignItems: ItemAlign.Start
                }) {
                  ForEach(this.buildLayoutItems(), (item: ControlLayoutItem) => {
                    if (item.kind === 'group') {
                      this.readoutGroupCard(item.controls)
                    } else {
                      this.singleControlCard(item.controls[0])
                    }
                  }, (item: ControlLayoutItem) => item.key)
                }
                .width('100%')
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
        .edgeEffect(EdgeEffect.Spring)

        Row({ space: 10 }) {
          IconCircleButton({
            symbol: $r('sys.symbol.chevron_left'),
            onAction: () => {
              this.pageInfos.pop();
            }
          })
          Text(this.deviceName)
            .fontFamily(this.appFontFamily(this.deviceName))
            .fontWeight(this.appFontWeight())
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(HwColor.textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          IconCircleButton({
            symbol: $r('sys.symbol.arrow_counterclockwise'),
            buttonEnabled: !this.refreshing,
            spinning: this.refreshing,
            onAction: () => {
              this.refreshValues();
            }
          })
          IconCircleButton({
            symbol: $r('sys.symbol.info_circle'),
            onAction: () => {
              this.openAboutDevice();
            }
          })
        }
        .width('100%')
        .height((this.isWearable ? 52 : 56) + this.statusBarHeight)
        .padding({ left: this.isWearable ? 10 : 16, right: this.isWearable ? 10 : 16, top: this.statusBarHeight })
        .backgroundColor('#FFFFFF')
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
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
