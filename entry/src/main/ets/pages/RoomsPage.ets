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
import { router } from '@kit.ArkUI';
import { HwColor, HwRadius, HwSpace, MijiaOverviewCard, MijiaOverviewCardText, MijiaOverviewCardValue, MijiaSheetBackground } from '../utils/DesignTokens';
import { IconCircleButton } from '../components/IconCircleButton';
import { AppBackground } from '../components/AppBackground';
import { xiaomiDataService } from '../services/XiaomiDataService';
import { FeedbackLogService } from '../services/FeedbackLogService';
import { XiaomiDevice, XiaomiHome, XiaomiRoom } from '../models/XiaomiHomeModels';
import { RoomStore, UserRoom } from '../storage/RoomStore';

interface RoomDeviceEntry {
  did: string;
  name: string;
  online: boolean;
  location: string;
  homeId: string;
}

interface HomeOption {
  id: string;
  name: string;
}

const EMPTY_ROOM: UserRoom = {
  id: '',
  floor: '',
  name: '',
  homeId: '',
  homeName: '',
  dids: []
};

@Entry
@Component
struct RoomsPage {
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
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('isDarkMode') isDarkMode: boolean = false;
  @StorageProp('currentWidthBreakpoint') @Watch('onBreakpointChange')
  widthBp: WidthBreakpoint = WidthBreakpoint.WIDTH_SM;
  @State isWideScreen: boolean = false;
  @State rooms: UserRoom[] = [];
  @State homes: XiaomiHome[] = [];
  @State devices: RoomDeviceEntry[] = [];
  @State homeOptions: HomeOption[] = [];
  @State selectedHomeIndex: number = 0;
  @State selectedHomeId: string = '';
  @State selectedHomeName: string = '';
  @State loading: boolean = true;
  @State errorMessage: string = '';
  @State selectedRoomId: string = '';
  @State showRoomSheet: boolean = false;
  @State showAddRoomSheet: boolean = false;
  @State showAddDevicesSheet: boolean = false;
  @State floorDraft: string = '';
  @State roomNameDraft: string = '';
  @State selectedDids: string[] = [];

  private topOffset(): number {
    return 56 + this.statusBarHeight;
  }

  aboutToAppear(): void {
    FeedbackLogService.setCurrentPage('房间页');
    this.onBreakpointChange();
    this.loadDevices();
    this.loadHomes();
  }

  onBreakpointChange(): void {
    this.isWideScreen = this.widthBp === WidthBreakpoint.WIDTH_LG ||
      this.widthBp === WidthBreakpoint.WIDTH_XL;
  }

  async loadDevices(silent: boolean = false): Promise<void> {
    if (!silent) {
      this.loading = true;
    }
    this.errorMessage = '';
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const snapshot = await xiaomiDataService.getHomeSnapshot(context, false);
      const deviceMap = JSON.parse(snapshot.devicesJson) as Record<string, XiaomiDevice>;
      const entries: RoomDeviceEntry[] = [];
      const dids = Object.keys(deviceMap);
      for (let i = 0; i < dids.length; i++) {
        const device = deviceMap[dids[i]];
        entries.push({
          did: device.did,
          name: device.name,
          online: device.online,
          location: this.deviceLocation(device),
          homeId: device.homeId
        });
      }
      entries.sort((a: RoomDeviceEntry, b: RoomDeviceEntry): number => {
        const aOnline = a.online ? 1 : 0;
        const bOnline = b.online ? 1 : 0;
        return bOnline - aOnline;
      });
      this.devices = entries;
    } catch (err) {
      this.errorMessage = err instanceof Error ? err.message : '设备加载失败';
    } finally {
      if (!silent) {
        this.loading = false;
      }
    }
  }

  refreshPageSilently(): void {
    this.loadDevices(true);
    this.loadHomes();
  }

  async loadHomes(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const snapshot = await xiaomiDataService.getHomeSnapshot(context, false);
      const homes = JSON.parse(snapshot.homesJson) as XiaomiHome[];
      this.homes = homes;
      const options: HomeOption[] = [];
      for (let i = 0; i < homes.length; i++) {
        options.push({
          id: homes[i].homeId,
          name: homes[i].name
        });
      }
      this.homeOptions = options;
      if (options.length > 0) {
        const currentHomeId = AppStorage.get<string>('selectedHomeId') ?? '';
        let currentIndex = 0;
        for (let i = 0; i < options.length; i++) {
          if (options[i].id === currentHomeId) {
            currentIndex = i;
            break;
          }
        }
        this.selectedHomeIndex = currentIndex;
        this.selectedHomeId = options[currentIndex].id;
        this.selectedHomeName = options[currentIndex].name;
      }
      this.rebuildRooms();
    } catch (err) {
      // 家庭列表加载失败时保持空选项，房间仍可创建（家庭字段为空）
      this.rebuildRooms();
    }
  }

  /**
   * 合并米家云端已有房间（home.roomList）与本应用内自建的本地房间，
   * 按房间 id 去重，保证「已有房间」也能在房间管理中显示出来。
   */
  private rebuildRooms(): void {
    const merged: UserRoom[] = [];
    const seen = new Set<string>();
    for (let i = 0; i < this.homes.length; i++) {
      const home = this.homes[i];
      const roomList = home.roomList;
      for (let j = 0; j < roomList.length; j++) {
        const room = roomList[j] as XiaomiRoom;
        if (seen.has(room.roomId)) {
          continue;
        }
        seen.add(room.roomId);
        merged.push({
          id: room.roomId,
          floor: '',
          name: room.name,
          homeId: home.homeId,
          homeName: home.name,
          dids: room.dids
        });
      }
    }
    const localRooms = RoomStore.loadRooms();
    for (let i = 0; i < localRooms.length; i++) {
      const room = localRooms[i];
      if (seen.has(room.id)) {
        continue;
      }
      seen.add(room.id);
      merged.push(room);
    }
    merged.sort((a: UserRoom, b: UserRoom) => {
      return a.homeName.localeCompare(b.homeName) ||
        a.name.localeCompare(b.name);
    });
    this.rooms = merged;
  }

  deviceLocation(device: XiaomiDevice): string {
    if (device.homeName.length > 0 && device.roomName.length > 0) {
      return `${device.homeName} · ${device.roomName}`;
    }
    return device.homeName.length > 0 ? device.homeName : device.roomName;
  }

  roomTitle(room: UserRoom): string {
    return room.floor.length > 0 ? `${room.floor}楼 ${room.name}` : room.name;
  }

  roomDeviceCountText(room: UserRoom): string {
    if (room.homeName.length > 0) {
      return `${room.homeName} · ${room.dids.length} 台设备`;
    }
    return `${room.dids.length} 台设备`;
  }

  findDevice(did: string): RoomDeviceEntry | null {
    for (let i = 0; i < this.devices.length; i++) {
      if (this.devices[i].did === did) {
        return this.devices[i];
      }
    }
    return null;
  }

  roomDevices(room: UserRoom): RoomDeviceEntry[] {
    const result: RoomDeviceEntry[] = [];
    for (let i = 0; i < room.dids.length; i++) {
      const entry = this.findDevice(room.dids[i]);
      if (entry !== null) {
        result.push(entry);
      }
    }
    return result;
  }

  isDeviceInAnyRoom(did: string): boolean {
    for (let i = 0; i < this.rooms.length; i++) {
      if (this.rooms[i].dids.indexOf(did) >= 0) {
        return true;
      }
    }
    return false;
  }

  availableDevices(): RoomDeviceEntry[] {
    const result: RoomDeviceEntry[] = [];
    for (let i = 0; i < this.devices.length; i++) {
      const device = this.devices[i];
      if (this.isDeviceInAnyRoom(device.did)) {
        continue;
      }
      const room = this.selectedRoomData();
      if (room.homeId.length > 0 && device.homeId !== room.homeId) {
        continue;
      }
      result.push(device);
    }
    return result;
  }

  private findRoomById(roomId: string): UserRoom | null {
    for (let i = 0; i < this.rooms.length; i++) {
      if (this.rooms[i].id === roomId) {
        return this.rooms[i];
      }
    }
    return null;
  }

  selectedRoomData(): UserRoom {
    const room = this.findRoomById(this.selectedRoomId);
    return room !== null ? room : EMPTY_ROOM;
  }

  private latestRoomTitle(roomId: string): string {
    const room = this.findRoomById(roomId);
    return room !== null ? this.roomTitle(room) : '';
  }

  private latestRoomCountText(roomId: string): string {
    const room = this.findRoomById(roomId);
    return room !== null ? this.roomDeviceCountText(room) : '';
  }

  openRoomSheetById(roomId: string): void {
    const room = this.findRoomById(roomId);
    if (room !== null) {
      this.selectedRoomId = roomId;
      this.showRoomSheet = true;
    }
  }

  confirmRemoveDevice(device: RoomDeviceEntry): void {
    const room = this.selectedRoomData();
    if (room.id.length === 0) {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: '移出房间',
      message: `确定将「${device.name}」移出「${this.roomTitle(room)}」吗？`,
      primaryButton: {
        value: '取消',
        action: (): void => {
        }
      },
      secondaryButton: {
        value: '移出',
        fontColor: HwColor.danger,
        action: (): void => {
          this.removeDeviceFromRoom(device);
        }
      }
    });
  }

  removeDeviceFromRoom(device: RoomDeviceEntry): void {
    const room = this.selectedRoomData();
    if (room.id.length === 0) {
      return;
    }
    const nextDids: string[] = [];
    for (let i = 0; i < room.dids.length; i++) {
      if (room.dids[i] !== device.did) {
        nextDids.push(room.dids[i]);
      }
    }
    const nextRoom: UserRoom = {
      id: room.id,
      floor: room.floor,
      name: room.name,
      homeId: room.homeId,
      homeName: room.homeName,
      dids: nextDids
    };
    RoomStore.upsertRoom(nextRoom);
    this.rooms = RoomStore.loadRooms();
    this.getUIContext().getPromptAction().showToast({ message: `已将「${device.name}」移出房间` });
  }

  openAddDevicesSheet(): void {
    this.selectedDids = [];
    this.showAddDevicesSheet = true;
  }

  toggleDeviceSelection(did: string): void {
    const next: string[] = this.selectedDids.slice();
    const idx = next.indexOf(did);
    if (idx >= 0) {
      next.splice(idx, 1);
    } else {
      next.push(did);
    }
    this.selectedDids = next;
  }

  confirmAddDevices(): void {
    const room = this.selectedRoomData();
    if (room.id.length === 0) {
      return;
    }
    const existing = new Set<string>(room.dids);
    const added: string[] = [];
    for (let i = 0; i < this.selectedDids.length; i++) {
      const did = this.selectedDids[i];
      if (!existing.has(did)) {
        added.push(did);
      }
    }
    if (added.length > 0) {
      const nextRoom: UserRoom = {
        id: room.id,
        floor: room.floor,
        name: room.name,
        homeId: room.homeId,
        homeName: room.homeName,
        dids: room.dids.concat(added)
      };
      RoomStore.upsertRoom(nextRoom);
      this.rooms = RoomStore.loadRooms();
    }
    this.showAddDevicesSheet = false;
    if (added.length > 0) {
      this.getUIContext().getPromptAction().showToast({ message: `已添加 ${added.length} 台设备到房间` });
    }
  }

  createRoom(): void {
    const floor = this.floorDraft.trim();
    const name = this.roomNameDraft.trim();
    if (floor.length === 0 || name.length === 0) {
      return;
    }
    const duplicated = this.rooms.some((room: UserRoom): boolean =>
      room.floor === floor && room.name === name && room.homeId === this.selectedHomeId);
    if (duplicated) {
      this.getUIContext().getPromptAction().showToast({ message: '已存在相同楼层和名称的房间' });
      return;
    }
    const room: UserRoom = {
      id: `room_${Date.now()}`,
      floor: floor,
      name: name,
      homeId: this.selectedHomeId,
      homeName: this.selectedHomeName,
      dids: []
    };
    RoomStore.upsertRoom(room);
    this.rooms = RoomStore.loadRooms();
    this.floorDraft = '';
    this.roomNameDraft = '';
    this.showAddRoomSheet = false;
    this.getUIContext().getPromptAction().showToast({ message: '房间已创建' });
  }

  confirmDeleteRoom(): void {
    const room = this.selectedRoomData();
    if (room.id.length === 0) {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: '删除房间',
      message: `确定删除「${this.roomTitle(room)}」吗？房间内的设备不会被删除，只会移出该房间。`,
      primaryButton: {
        value: '取消',
        action: (): void => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: HwColor.danger,
        action: (): void => {
          this.deleteRoom(room);
        }
      }
    });
  }

  deleteRoom(room: UserRoom): void {
    const next: UserRoom[] = [];
    for (let i = 0; i < this.rooms.length; i++) {
      if (this.rooms[i].id !== room.id) {
        next.push(this.rooms[i]);
      }
    }
    RoomStore.saveRooms(next);
    this.rooms = next;
    this.selectedRoomId = '';
    this.showRoomSheet = false;
    this.getUIContext().getPromptAction().showToast({ message: '房间已删除' });
  }

  @Builder
  roomCard(room: UserRoom) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(this.latestRoomTitle(room.id))
          .fontFamily(this.appFontFamily(this.latestRoomTitle(room.id)))
          .fontWeight(this.appFontWeight())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.latestRoomCountText(room.id))
          .fontFamily(this.appFontFamily(this.latestRoomCountText(room.id)))
          .fontWeight(this.appFontWeight())
          .fontSize(13)
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
    .hoverEffect(HoverEffect.Highlight)
    .onClick(() => {
      this.openRoomSheetById(room.id);
    })
  }

  @Builder
  roomDeviceRow(device: RoomDeviceEntry) {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text(device.name)
          .fontFamily(this.appFontFamily(device.name))
          .fontWeight(this.appFontWeight())
          .fontSize(15)
          .fontColor(Color.White)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (device.location.length > 0) {
          Text(device.location)
            .fontFamily(this.appFontFamily(device.location))
            .fontWeight(this.appFontWeight())
            .fontSize(12)
            .fontColor(MijiaOverviewCardText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(device.online ? '在线' : '离线')
        .fontFamily(this.appFontFamily(device.online ? '在线' : '离线'))
        .fontWeight(this.appFontWeight())
        .fontSize(12)
        .fontColor(device.online ? HwColor.online : MijiaOverviewCardText)
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
      this.confirmRemoveDevice(device);
    })
  }

  @Builder
  roomDeviceSheet() {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Text(this.roomTitle(this.selectedRoomData()))
          .fontFamily(this.appFontFamily(this.roomTitle(this.selectedRoomData())))
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
          onAction: (): void => {
            this.showRoomSheet = false;
          }
        })
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)
      .padding({ left: HwSpace.lg, right: HwSpace.lg })

      if (this.selectedRoomData().id.length > 0) {
        if (this.loading) {
          Text('加载中…')
            .fontFamily(this.appFontFamily('加载中…'))
            .fontWeight(this.appFontWeight())
            .fontSize(14)
            .fontColor(HwColor.textSecondary)
            .padding({ top: 24, bottom: 24 })
        } else if (this.roomDevices(this.selectedRoomData()).length === 0) {
          Text('该房间暂无设备，点击下方按钮添加')
            .fontFamily(this.appFontFamily('该房间暂无设备，点击下方按钮添加'))
            .fontWeight(this.appFontWeight())
            .fontSize(14)
            .fontColor(HwColor.textSecondary)
            .padding({ top: 24, bottom: 24 })
        } else {
          Scroll() {
            Column({ space: 8 }) {
              ForEach(this.roomDevices(this.selectedRoomData()), (device: RoomDeviceEntry) => {
                this.roomDeviceRow(device)
              }, (device: RoomDeviceEntry) => device.did)
            }
            .width('100%')
            .padding({ left: HwSpace.lg, right: HwSpace.lg })
            .margin({ top: 12 })
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      }

      Row({ space: 12 }) {
        Button('添加到本房间', { type: ButtonType.Capsule, stateEffect: true })
          .height(44)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(MijiaOverviewCardValue)
          .backgroundColor(MijiaOverviewCard)
          .border({ width: 1, color: '#24FFFFFF' })
          .layoutWeight(1)
          .onClick(() => {
            this.openAddDevicesSheet();
          })
          .bindSheet($$this.showAddDevicesSheet, this.addDevicesSheet(), {
            height: SheetSize.MEDIUM,
            dragBar: true,
            backgroundColor: MijiaSheetBackground,
            showClose: false,
          })
        Button('删除本房间', { type: ButtonType.Capsule, stateEffect: true })
          .height(44)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(HwColor.danger)
          .backgroundColor(MijiaOverviewCard)
          .border({ width: 1, color: '#24FFFFFF' })
          .layoutWeight(1)
          .onClick(() => {
            this.confirmDeleteRoom();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ left: HwSpace.lg, right: HwSpace.lg })
      .margin({ top: 6, bottom: 24 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  addDeviceRow(device: RoomDeviceEntry) {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text(device.name)
          .fontFamily(this.appFontFamily(device.name))
          .fontWeight(this.appFontWeight())
          .fontSize(15)
          .fontColor(Color.White)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (device.location.length > 0) {
          Text(device.location)
            .fontFamily(this.appFontFamily(device.location))
            .fontWeight(this.appFontWeight())
            .fontSize(12)
            .fontColor(MijiaOverviewCardText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Stack({ alignContent: Alignment.Center }) {
        if (this.selectedDids.indexOf(device.did) >= 0) {
          Row()
            .width(22)
            .height(22)
            .borderRadius(11)
            .backgroundColor(MijiaOverviewCardValue)
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(14)
            .fontColor([Color.White])
        } else {
          Row()
            .width(22)
            .height(22)
            .borderRadius(11)
            .border({ width: 1.5, color: MijiaOverviewCardText })
        }
      }
      .width(22)
      .height(22)
    }
    .width('100%')
    .padding(HwSpace.md)
    .borderRadius(HwRadius.control)
    .backgroundColor(MijiaOverviewCard)
    .border({ width: 1, color: '#24FFFFFF' })
    .clip(true)
    .onClick(() => {
      this.toggleDeviceSelection(device.did);
    })
  }

  @Builder
  addDevicesSheet() {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Text(`添加到「${this.selectedRoomData().name}」`)
          .fontFamily(this.appFontFamily(`添加到「${this.selectedRoomData().name}」`))
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
          onAction: (): void => {
            this.showAddDevicesSheet = false;
          }
        })
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)
      .padding({ left: HwSpace.lg, right: HwSpace.lg })

      Text('选择要添加到该房间的设备')
        .fontFamily(this.appFontFamily('选择要添加到该房间的设备'))
        .fontWeight(this.appFontWeight())
        .fontSize(12)
        .fontColor(HwColor.textSecondary)
        .width('100%')
        .padding({ left: HwSpace.lg, right: HwSpace.lg, bottom: 8 })

      if (this.availableDevices().length === 0) {
        Text('暂无可用设备')
          .fontFamily(this.appFontFamily('暂无可用设备'))
          .fontWeight(this.appFontWeight())
          .fontSize(14)
          .fontColor(HwColor.textSecondary)
          .padding({ top: 24, bottom: 24 })
      } else {
        Scroll() {
          Column({ space: 8 }) {
            ForEach(this.availableDevices(), (device: RoomDeviceEntry) => {
              this.addDeviceRow(device)
            }, (device: RoomDeviceEntry) => device.did)
          }
          .width('100%')
          .padding({ left: HwSpace.lg, right: HwSpace.lg })
          .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }

      Button(`添加（${this.selectedDids.length}）`, { type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.EMPHASIZED })
        .width('100%')
        .height(48)
        .fontSize(16)
        .fontColor(Color.White)
        .backgroundColor(HwColor.primary)
        .margin({ left: HwSpace.lg, right: HwSpace.lg, top: 12, bottom: 24 })
        .enabled(this.selectedDids.length > 0)
        .opacity(this.selectedDids.length > 0 ? 1 : 0.4)
        .onClick(() => {
          this.confirmAddDevices();
        })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  addRoomSheet() {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Text('添加房间')
          .fontFamily(this.appFontFamily('添加房间'))
          .fontWeight(this.appFontWeight())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(HwColor.textPrimary)
          .layoutWeight(1)
        IconCircleButton({
          symbol: $r('sys.symbol.xmark'),
          buttonSize: 36,
          iconSize: 18,
          onAction: (): void => {
            this.showAddRoomSheet = false;
          }
        })
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)
      .padding({ left: HwSpace.lg, right: HwSpace.lg })

      Column({ space: 12 }) {
        Column({ space: 6 }) {
          Text('所在家庭')
            .fontFamily(this.appFontFamily('所在家庭'))
            .fontWeight(this.appFontWeight())
            .fontSize(14)
            .fontColor(HwColor.textPrimary)
          if (this.homeOptions.length > 0) {
            Select(this.homeOptions.map((option: HomeOption): SelectOption => ({ value: option.name })))
              .selected(this.selectedHomeIndex)
              .value(this.selectedHomeName)
              .font({ size: 15 })
              .fontColor(HwColor.textPrimary)
              .selectedOptionFontColor(HwColor.textPrimary)
              .optionFontColor(HwColor.textPrimary)
              .width('100%')
              .onSelect((index: number, value?: string) => {
                this.selectedHomeIndex = index;
                this.selectedHomeId = this.homeOptions[index].id;
                this.selectedHomeName = this.homeOptions[index].name;
              })
          } else {
            Text('暂无家庭可选，请先返回首页加载家庭')
              .fontFamily(this.appFontFamily('暂无家庭可选，请先返回首页加载家庭'))
              .fontWeight(this.appFontWeight())
              .fontSize(13)
              .fontColor(HwColor.textSecondary)
          }
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')

        Column({ space: 6 }) {
          Text('楼层')
            .fontFamily(this.appFontFamily('楼层'))
            .fontWeight(this.appFontWeight())
            .fontSize(14)
            .fontColor(HwColor.textPrimary)
          TextInput({ placeholder: '例如：3、B1', text: this.floorDraft })
            .width('100%')
            .height(44)
            .fontSize(15)
            .fontColor(HwColor.textPrimary)
            .placeholderColor(MijiaOverviewCardText)
            .backgroundColor(MijiaOverviewCard)
            .borderRadius(HwRadius.control)
            .border({ width: 1, color: '#24FFFFFF' })
            .clip(true)
            .padding({ left: HwSpace.md, right: HwSpace.md })
            .onChange((text: string) => {
              this.floorDraft = text;
            })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')

        Column({ space: 6 }) {
          Text('房间名')
            .fontFamily(this.appFontFamily('房间名'))
            .fontWeight(this.appFontWeight())
            .fontSize(14)
            .fontColor(HwColor.textPrimary)
          TextInput({ placeholder: '例如：卧室、客厅', text: this.roomNameDraft })
            .width('100%')
            .height(44)
            .fontSize(15)
            .fontColor(HwColor.textPrimary)
            .placeholderColor(HwColor.textSecondary)
            .backgroundColor(MijiaOverviewCard)
            .border({ width: 1, color: '#24FFFFFF' })
            .borderRadius(HwRadius.control)
            .clip(true)
            .padding({ left: HwSpace.md, right: HwSpace.md })
            .onChange((text: string) => {
              this.roomNameDraft = text;
            })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
      }
      .width('100%')
      .padding({ left: HwSpace.lg, right: HwSpace.lg, top: 12 })

      Row() {
        Button('确认创建', { type: ButtonType.Capsule, stateEffect: true })
          .width(220)
          .height(44)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(MijiaOverviewCardValue)
          .backgroundColor(MijiaOverviewCard)
          .border({ width: 1, color: '#24FFFFFF' })
          .enabled(this.floorDraft.trim().length > 0 && this.roomNameDraft.trim().length > 0)
          .opacity(this.floorDraft.trim().length > 0 && this.roomNameDraft.trim().length > 0 ? 1 : 0.4)
          .onClick(() => {
            this.createRoom();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ top: 24, bottom: 24 })
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      AppBackground()
      Column() {
        Scroll() {
          Column({ space: 0 }) {
            Blank().height(this.topOffset())
            Column({ space: 12 }) {
              if (this.errorMessage.length > 0) {
                Text(this.errorMessage)
                  .fontFamily(this.appFontFamily(this.errorMessage))
                  .fontWeight(this.appFontWeight())
                  .fontSize(14)
                  .fontColor(HwColor.danger)
              }
              if (this.loading && this.devices.length === 0) {
                Text('加载中…')
                  .fontFamily(this.appFontFamily('加载中…'))
                  .fontWeight(this.appFontWeight())
                  .fontSize(14)
                  .fontColor(HwColor.textSecondary)
              }
              if (this.rooms.length === 0 && !this.loading) {
                Text('暂无房间，请点击下方添加')
                  .fontFamily(this.appFontFamily('暂无房间，请点击下方添加'))
                  .fontWeight(this.appFontWeight())
                  .fontSize(14)
                  .fontColor(HwColor.textSecondary)
                  .padding({ top: 24, bottom: 24 })
              }
              ForEach(this.rooms, (room: UserRoom) => {
                this.roomCard(room)
              }, (room: UserRoom) => room.id)
              if (this.rooms.length === 0) {
                Row({ space: 10 }) {
                  SymbolGlyph($r('sys.symbol.plus'))
                    .fontSize(18)
                    .fontColor([MijiaOverviewCardText])
                  Text('添加房间')
                    .fontFamily(this.appFontFamily('添加房间'))
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
                  this.showAddRoomSheet = true;
                })
                .bindSheet($$this.showAddRoomSheet, this.addRoomSheet(), {
                  height: SheetSize.MEDIUM,
                  dragBar: true,
            backgroundColor: MijiaSheetBackground,
                  showClose: false,
                })
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
          onAction: (): void => {
            router.back();
          }
        })
        Text('房间')
          .fontFamily(this.appFontFamily('房间'))
          .fontWeight(this.appFontWeight())
          .margin({ left: HwSpace.md })
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(HwColor.textPrimary)
        Blank()
        if (this.rooms.length > 0) {
          Column() {
            IconCircleButton({
              symbol: $r('sys.symbol.plus'),
              buttonSize: 40,
              iconSize: 20,
              onAction: (): void => {
                this.showAddRoomSheet = true;
              }
            })
          }
          .bindSheet($$this.showAddRoomSheet, this.addRoomSheet(), {
            height: SheetSize.MEDIUM,
            dragBar: true,
            backgroundColor: MijiaSheetBackground,
            showClose: false,
          })
        }
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
    .bindSheet($$this.showRoomSheet, this.roomDeviceSheet(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
            backgroundColor: MijiaSheetBackground,
      showClose: false,
      onDisappear: () => {
        this.refreshPageSilently();
      }
    })
    .keyboardShortcut(FunctionKey.ESC, [], () => {
      router.back();
    })
  }
}
