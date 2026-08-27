/*
 * 鸿米家（miha）— 本地智能创建页。
 *
 * 用户可自建「智能」：设置名称，选择设备并调整动作（如打开灯、调亮度），
 * 保存后在本应用内一键执行（通过 miot spec 属性写入），不同步米家云端。
 *
 * Copyright (C) 2026 鸿米家（miha）项目开发者
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import { router } from '@kit.ArkUI';
import { HwColor, HwRadius, HwSpace, MijiaOverviewCard, MijiaOverviewCardText, MijiaOverviewCardValue, MijiaSheetBackground } from '../utils/DesignTokens';
import { IconCircleButton } from '../components/IconCircleButton';
import { AppBackground } from '../components/AppBackground';
import { xiaomiDataService } from '../services/XiaomiDataService';
import { XiaomiDevice, LocalScene, LocalSceneAction, ALL_HOMES_ID } from '../models/XiaomiHomeModels';
import { LocalSceneStore } from '../storage/LocalSceneStore';
import { DeviceController } from '../controllers/DeviceController';
import { DevicePropertyParam, DevicePropertyResult } from '../controllers/DeviceTransport';
import { DeviceRemovalStore } from '../storage/DeviceRemovalStore';
import { MIoTSpecInstance } from '../models/MIotSpecModels';
import { PropertyControlDescriptor, buildServiceControls, CapabilityControlType, translateMiotText } from '../components/CapabilityRenderer';
import { PropertyControl } from '../components/PropertyControl';

interface PickerValueState {
  key: string;
  value: Object | undefined;
}

@Entry
@Component
struct SceneCreatePage {
  @StorageLink('fontMode') fontMode: string = 'system';
  @StorageLink('fontFamilyEn') fontFamilyEn: string = 'system';
  @StorageLink('fontFamilyZh') fontFamilyZh: string = 'system';
  @StorageLink('fontWeightMode') fontWeightMode: string = 'system';
  @StorageLink('fontWeightValue') fontWeightValue: number = 400;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('navigationBarHeight') navigationBarHeight: number = 0;
  @StorageLink('selectedHomeId') selectedHomeId: string = '';

  @State sceneName: string = '';
  @State actions: LocalSceneAction[] = [];
  @State message: string = '';

  @State devices: XiaomiDevice[] = [];
  @State devicesLoading: boolean = false;
  @State showDeviceSheet: boolean = false;

  @State pickerDevice: XiaomiDevice | undefined = undefined;
  @State pickerControls: PropertyControlDescriptor[] = [];
  @State pickerValues: PickerValueState[] = [];
  @State pickerLoading: boolean = false;
  @State pickerError: string = '';
  @State pickerSaving: boolean = false;

  private controller: DeviceController | null = null;

  aboutToAppear(): void {
    this.loadDevices();
  }

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

  async loadDevices(): Promise<void> {
    if (this.devicesLoading) {
      return;
    }
    this.devicesLoading = true;
    try {
      const map = await xiaomiDataService.getDevices();
      const keys = Object.keys(map);
      const list: XiaomiDevice[] = [];
      for (let i = 0; i < keys.length; i++) {
        const device = map[keys[i]];
        if (device === undefined || !device.online) {
          continue;
        }
        // 仅显示当前家庭的在线设备；未选择或选择「全部家庭」时显示全部
        if (this.selectedHomeId.length > 0 && this.selectedHomeId !== ALL_HOMES_ID &&
          device.homeId !== this.selectedHomeId) {
          continue;
        }
        list.push(device);
      }
      list.sort((a: XiaomiDevice, b: XiaomiDevice) => {
        if (a.roomName === b.roomName) {
          return a.name.localeCompare(b.name);
        }
        return a.roomName.localeCompare(b.roomName);
      });
      this.devices = DeviceRemovalStore.filter(list);
    } catch (err) {
      this.message = err instanceof Error ? err.message : '加载设备失败';
    } finally {
      this.devicesLoading = false;
    }
  }

  buildControls(spec: MIoTSpecInstance): PropertyControlDescriptor[] {
    const result: PropertyControlDescriptor[] = [];
    for (let i = 0; i < spec.services.length; i++) {
      const controls = buildServiceControls(spec.services[i]);
      for (let j = 0; j < controls.length; j++) {
        if (controls[j].writable && controls[j].type !== CapabilityControlType.READOUT) {
          result.push(controls[j]);
        }
      }
    }
    return result;
  }

  async pickDevice(device: XiaomiDevice): Promise<void> {
    this.pickerDevice = device;
    this.pickerLoading = true;
    this.pickerError = '';
    this.pickerControls = [];
    this.pickerValues = [];
    try {
      const spec = await xiaomiDataService.getDeviceSpecForDevice(device);
      const controls = this.buildControls(spec);
      this.pickerControls = controls;
      this.controller = await xiaomiDataService.getDeviceController();
      await this.prefillPickerValues(device.did, controls);
    } catch (err) {
      this.pickerError = err instanceof Error ? err.message : '加载设备控制失败';
    } finally {
      this.pickerLoading = false;
    }
  }

  async prefillPickerValues(did: string, controls: PropertyControlDescriptor[]): Promise<void> {
    if (this.controller === null) {
      return;
    }
    const params: DevicePropertyParam[] = [];
    for (let i = 0; i < controls.length; i++) {
      if (controls[i].readable) {
        params.push({ did: did, siid: controls[i].siid, piid: controls[i].piid });
      }
    }
    let results: DevicePropertyResult[] = [];
    if (params.length > 0) {
      try {
        results = await this.controller.getProperties(did, params);
      } catch (err) {
        results = [];
      }
    }
    const valueMap = new Map<string, Object | undefined>();
    for (let i = 0; i < results.length; i++) {
      valueMap.set(`${results[i].siid}.${results[i].piid}`, results[i].value);
    }
    const states: PickerValueState[] = [];
    for (let i = 0; i < controls.length; i++) {
      states.push({
        key: `${controls[i].siid}.${controls[i].piid}`,
        value: valueMap.get(`${controls[i].siid}.${controls[i].piid}`)
      });
    }
    this.pickerValues = states;
  }

  pickerValueOf(control: PropertyControlDescriptor): Object | undefined {
    const key = `${control.siid}.${control.piid}`;
    for (let i = 0; i < this.pickerValues.length; i++) {
      if (this.pickerValues[i].key === key) {
        return this.pickerValues[i].value;
      }
    }
    return undefined;
  }

  updatePickerValue(control: PropertyControlDescriptor, value: Object): void {
    const key = `${control.siid}.${control.piid}`;
    const next: PickerValueState[] = [];
    let found = false;
    for (let i = 0; i < this.pickerValues.length; i++) {
      if (this.pickerValues[i].key === key) {
        next.push({ key: key, value: value });
        found = true;
      } else {
        next.push(this.pickerValues[i]);
      }
    }
    if (!found) {
      next.push({ key: key, value: value });
    }
    this.pickerValues = next;
  }

  /** 枚举反查中文选项文本；布尔转开关；非数值兜底走全局词典 */
  private actionValueText(control: PropertyControlDescriptor, value: Object): string {
    for (let i = 0; i < control.optionValues.length; i++) {
      if (String(control.optionValues[i]) === String(value)) {
        return control.options[i];
      }
    }
    const raw = String(value);
    if (raw === 'true') {
      return '开启';
    }
    if (raw === 'false') {
      return '关闭';
    }
    if (Number.isNaN(Number(raw))) {
      return translateMiotText(raw);
    }
    return raw;
  }

  confirmAddActions(): void {
    if (this.pickerDevice === undefined) {
      return;
    }
    const device = this.pickerDevice;
    const next: LocalSceneAction[] = this.actions.slice();
    let added = 0;
    for (let i = 0; i < this.pickerControls.length; i++) {
      const control = this.pickerControls[i];
      const value = this.pickerValueOf(control);
      if (value === undefined) {
        continue;
      }
      next.push({
        did: device.did,
        deviceName: device.name,
        siid: control.siid,
        piid: control.piid,
        label: control.label,
        value: value,
        valueText: this.actionValueText(control, value)
      });
      added++;
    }
    this.actions = next;
    this.pickerDevice = undefined;
    this.pickerControls = [];
    this.pickerValues = [];
    this.showDeviceSheet = false;
    if (added === 0) {
      this.message = '请调整至少一个动作后确认';
    }
  }

  removeAction(index: number): void {
    const next: LocalSceneAction[] = this.actions.slice();
    next.splice(index, 1);
    this.actions = next;
  }

  saveScene(): void {
    const name = this.sceneName.trim();
    if (name.length === 0) {
      this.message = '请输入智能名称';
      return;
    }
    if (this.actions.length === 0) {
      this.message = '请至少添加一个设备动作';
      return;
    }
    const scene: LocalScene = {
      sceneId: `${Date.now()}`,
      name: name,
      actions: this.actions.slice()
    };
    const list = LocalSceneStore.load();
    list.push(scene);
    LocalSceneStore.save(list);
    this.getUIContext().getPromptAction().showToast({ message: `已创建「${name}」` });
    router.back();
  }

  @Builder
  devicePickerSheet() {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Text(this.pickerDevice === undefined ? '选择设备' : this.pickerDevice.name)
          .fontFamily(this.appFontFamily(this.pickerDevice === undefined ? '选择设备' : this.pickerDevice.name))
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
            this.showDeviceSheet = false;
            this.pickerDevice = undefined;
            this.pickerControls = [];
            this.pickerValues = [];
          }
        })
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)
      .padding({ left: HwSpace.lg, right: HwSpace.lg })

      if (this.pickerDevice === undefined) {
        this.deviceListContent()
      } else {
        this.pickerControlsContent()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MijiaSheetBackground)
  }

  @Builder
  deviceListContent() {
    Column({ space: 0 }) {
      if (this.devicesLoading) {
        Text('加载中…')
          .fontFamily(this.appFontFamily('加载中…'))
          .fontWeight(this.appFontWeight())
          .fontSize(14)
          .fontColor(HwColor.textSecondary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 24, bottom: 24 })
      } else if (this.devices.length === 0) {
        Column({ space: 8 }) {
          Text('暂无在线设备')
            .fontFamily(this.appFontFamily('暂无在线设备'))
            .fontWeight(this.appFontWeight())
            .fontSize(15)
            .fontColor(HwColor.textPrimary)
          Text('请先返回首页确认设备已加载')
            .fontFamily(this.appFontFamily('请先返回首页确认设备已加载'))
            .fontWeight(this.appFontWeight())
            .fontSize(12)
            .fontColor(HwColor.textSecondary)
        }
        .width('100%')
        .padding({ top: 40, bottom: 40 })
      } else {
        Scroll() {
          Column({ space: 8 }) {
            ForEach(this.devices, (device: XiaomiDevice) => {
              Row({ space: 12 }) {
                Column({ space: 2 }) {
                  Text(device.name)
                    .fontFamily(this.appFontFamily(device.name))
                    .fontWeight(this.appFontWeight())
                    .fontSize(15)
                    .fontColor(Color.White)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(device.roomName.length > 0 ? device.roomName : device.homeName)
                    .fontFamily(this.appFontFamily(device.roomName.length > 0 ? device.roomName : device.homeName))
                    .fontWeight(this.appFontWeight())
                    .fontSize(12)
                    .fontColor(MijiaOverviewCardText)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(16)
                  .fontColor([MijiaOverviewCardText])
              }
              .width('100%')
              .padding(HwSpace.md)
              .borderRadius(HwRadius.control)
              .backgroundColor(MijiaOverviewCard)
              .border({ width: 1, color: '#24FFFFFF' })
              .clip(true)
              .onClick(() => {
                this.pickDevice(device);
              })
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
  }

  @Builder
  pickerControlsContent() {
    Column({ space: 0 }) {
      if (this.pickerLoading) {
        Text('加载中…')
          .fontFamily(this.appFontFamily('加载中…'))
          .fontWeight(this.appFontWeight())
          .fontSize(14)
          .fontColor(HwColor.textSecondary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 24, bottom: 24 })
      } else if (this.pickerError.length > 0) {
        Column({ space: 8 }) {
          Text(this.pickerError)
            .fontFamily(this.appFontFamily(this.pickerError))
            .fontWeight(this.appFontWeight())
            .fontSize(14)
            .fontColor(HwColor.danger)
          Button('返回设备列表')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .onClick(() => {
              this.pickerDevice = undefined;
              this.pickerControls = [];
              this.pickerValues = [];
            })
        }
        .width('100%')
        .padding({ top: 24, bottom: 24 })
      } else if (this.pickerControls.length === 0) {
        Column({ space: 8 }) {
          Text('该设备没有可控制的属性')
            .fontFamily(this.appFontFamily('该设备没有可控制的属性'))
            .fontWeight(this.appFontWeight())
            .fontSize(14)
            .fontColor(HwColor.textSecondary)
          Button('返回设备列表')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .onClick(() => {
              this.pickerDevice = undefined;
              this.pickerControls = [];
              this.pickerValues = [];
            })
        }
        .width('100%')
        .padding({ top: 24, bottom: 24 })
      } else {
        Scroll() {
          Column({ space: 10 }) {
            Text('调整动作后点击下方「添加这些动作」')
              .fontFamily(this.appFontFamily('调整动作后点击下方「添加这些动作」'))
              .fontWeight(this.appFontWeight())
              .fontSize(12)
              .fontColor(HwColor.textSecondary)
              .width('100%')

            ForEach(this.pickerControls, (control: PropertyControlDescriptor) => {
              PropertyControl({
                control: control,
                value: this.pickerValueOf(control),
                onChanged: (value: Object) => {
                  this.updatePickerValue(control, value);
                }
              })
            }, (control: PropertyControlDescriptor) => `${control.siid}.${control.piid}`)

            Blank().height(8)
          }
          .width('100%')
          .padding({ left: HwSpace.lg, right: HwSpace.lg, bottom: 12 })
          .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)

        // 确认按钮固定在底部，避免控件过多时被滚动内容挤出屏幕
        Row({ space: 12 }) {
          Button('返回设备列表')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .height(44)
            .fontSize(15)
            .fontColor(HwColor.primary)
            .layoutWeight(1)
            .onClick(() => {
              this.pickerDevice = undefined;
              this.pickerControls = [];
              this.pickerValues = [];
            })
          Button('添加这些动作')
            .width('55%')
            .height(44)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(HwColor.primary)
            .fontColor(Color.White)
            .stateEffect(true)
            .onClick(() => {
              this.confirmAddActions();
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({
          left: HwSpace.lg,
          right: HwSpace.lg,
          top: 8,
          bottom: this.navigationBarHeight + 20
        })
        .backgroundColor(MijiaSheetBackground)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  actionRow(action: LocalSceneAction, index: number) {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text(action.deviceName)
          .fontFamily(this.appFontFamily(action.deviceName))
          .fontWeight(this.appFontWeight())
          .fontSize(15)
          .fontColor(Color.White)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${action.label} = ${action.valueText !== undefined ? action.valueText : String(action.value)}`)
          .fontFamily(this.appFontFamily(`${action.label} = ${action.valueText !== undefined ? action.valueText : String(action.value)}`))
          .fontWeight(this.appFontWeight())
          .fontSize(12)
          .fontColor(MijiaOverviewCardText)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      IconCircleButton({
        symbol: $r('sys.symbol.trash'),
        buttonSize: 32,
        iconSize: 16,
        tint: MijiaOverviewCardText,
        onAction: () => {
          this.removeAction(index);
        }
      })
    }
    .width('100%')
    .padding(HwSpace.md)
    .borderRadius(HwRadius.control)
    .backgroundColor(MijiaOverviewCard)
    .border({ width: 1, color: '#24FFFFFF' })
    .clip(true)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      AppBackground()
      Column() {
        Scroll() {
          Column({ space: 12 }) {
            Blank().height(56 + this.statusBarHeight)

            if (this.message.length > 0) {
              Text(this.message)
                .fontFamily(this.appFontFamily(this.message))
                .fontWeight(this.appFontWeight())
                .fontSize(13)
                .fontColor(HwColor.danger)
                .width('100%')
                .padding({ left: 4, right: 4 })
            }

            Column({ space: 4 }) {
              Text('智能名称')
                .fontFamily(this.appFontFamily('智能名称'))
                .fontWeight(this.appFontWeight())
                .fontSize(12)
                .fontColor(MijiaOverviewCardText)
                .width('100%')
              TextInput({ text: this.sceneName, placeholder: '例如：回家模式' })
                .fontFamily(this.appFontFamily('例如：回家模式'))
                .fontWeight(this.appFontWeight())
                .fontColor(Color.White)
                .placeholderColor(MijiaOverviewCardText)
                .backgroundColor(Color.Transparent)
                .caretColor(MijiaOverviewCardValue)
                .fontSize(15)
                .height(44)
                .width('100%')
                .onChange((value: string) => {
                  this.sceneName = value;
                })
            }
            .width('100%')
            .padding(HwSpace.lg)
            .borderRadius(HwRadius.card)
            .backgroundColor(MijiaOverviewCard)
            .border({ width: 1, color: '#24FFFFFF' })
            .clip(true)

            Row({ space: 12 }) {
              SymbolGlyph($r('sys.symbol.plus'))
                .fontSize(18)
                .fontColor([MijiaOverviewCardValue])
              Text('添加设备动作')
                .fontFamily(this.appFontFamily('添加设备动作'))
                .fontWeight(this.appFontWeight())
                .fontSize(15)
                .fontColor(Color.White)
                .layoutWeight(1)
            }
            .width('100%')
            .padding(HwSpace.lg)
            .borderRadius(HwRadius.card)
            .backgroundColor(MijiaOverviewCard)
            .border({ width: 1, color: '#24FFFFFF' })
            .clip(true)
            .onClick(() => {
              this.showDeviceSheet = true;
            })
            .bindSheet($$this.showDeviceSheet, this.devicePickerSheet(), {
              height: SheetSize.LARGE,
              dragBar: true,
            backgroundColor: MijiaSheetBackground,
              showClose: false
            })

            if (this.actions.length > 0) {
              Text(`动作（${this.actions.length}）`)
                .fontFamily(this.appFontFamily(`动作（${this.actions.length}）`))
                .fontWeight(this.appFontWeight())
                .fontSize(13)
                .fontColor(MijiaOverviewCardText)
                .width('100%')
                .padding({ left: 4, right: 4 })

              ForEach(this.actions, (action: LocalSceneAction, index: number) => {
                this.actionRow(action, index)
              }, (action: LocalSceneAction, index: number) => `${action.did}_${action.siid}_${action.piid}_${index}`)
            }

            Blank().height(HwSpace.xl)

            Button('保存智能')
              .width('100%')
              .height(46)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .backgroundColor(HwColor.primary)
              .fontColor(Color.White)
              .stateEffect(true)
              .onClick(() => {
                this.saveScene();
              })

            Blank().height(HwSpace.xl)
          }
          .width('100%')
          .constraintSize({ maxWidth: 1080 })
          .padding({ left: HwSpace.lg, right: HwSpace.lg, top: HwSpace.lg, bottom: HwSpace.xl })
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
        Text('创建智能')
          .fontFamily(this.appFontFamily('创建智能'))
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
    .backgroundColor(HwColor.background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
