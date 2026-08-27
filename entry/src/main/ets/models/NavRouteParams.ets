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

export class DeviceDetailRouteParam {
  readonly did: string;

  constructor(did: string) {
    this.did = did;
  }
}

export class DeviceManageRouteParam {
  constructor() {
  }
}

export class AboutDeviceRouteParam {
  readonly name: string;
  readonly manufacturer: string;
  readonly model: string;
  readonly serial: string;
  readonly firmware: string;

  constructor(name: string, manufacturer: string, model: string, serial: string, firmware: string) {
    this.name = name;
    this.manufacturer = manufacturer;
    this.model = model;
    this.serial = serial;
    this.firmware = firmware;
  }
}
