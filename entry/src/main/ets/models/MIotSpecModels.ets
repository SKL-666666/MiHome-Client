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

import { asBoolean, asNumber, asString } from './XiaomiAuthInfo';

export interface MIoTSpecValueRange {
  min: number;
  max: number;
  step: number;
}

export interface MIoTSpecValueItem {
  name: string;
  value: Object;
  description: string;
}

export interface MIoTSpecProperty {
  iid: number;
  type: string;
  name: string;
  description: string;
  format: string;
  access: string[];
  readable: boolean;
  writable: boolean;
  notifiable: boolean;
  unit: string;
  valueRange: MIoTSpecValueRange | null;
  valueList: MIoTSpecValueItem[];
  precision: number;
  expr: string;
  proprietary: boolean;
  needFilter: boolean;
}

export interface MIoTSpecEvent {
  iid: number;
  type: string;
  name: string;
  description: string;
  argumentPiids: number[];
  proprietary: boolean;
  needFilter: boolean;
}

export interface MIoTSpecAction {
  iid: number;
  type: string;
  name: string;
  description: string;
  inPiids: number[];
  outPiids: number[];
  proprietary: boolean;
  needFilter: boolean;
}

export interface MIoTSpecService {
  iid: number;
  type: string;
  name: string;
  description: string;
  properties: MIoTSpecProperty[];
  events: MIoTSpecEvent[];
  actions: MIoTSpecAction[];
  proprietary: boolean;
  needFilter: boolean;
}

export interface MIoTSpecInstance {
  urn: string;
  name: string;
  description: string;
  services: MIoTSpecService[];
}

export function parseMIoTSpecInstance(raw: Record<string, Object>): MIoTSpecInstance {
  const urn = asString(raw['type']);
  if (urn.length === 0) {
    throw new Error('missing miot instance type');
  }
  const instance: MIoTSpecInstance = {
    urn: urn,
    name: lastTypeSegment(urn),
    description: asString(raw['description']),
    services: []
  };
  const services = raw['services'];
  if (!(services instanceof Array)) {
    return instance;
  }
  for (let i = 0; i < services.length; i++) {
    const service = parseMIoTSpecService(services[i] as Record<string, Object>);
    if (service.iid <= 0 || service.type.length === 0) {
      continue;
    }
    instance.services.push(service);
  }
  return instance;
}

export function parseMijiaSpecPageJson(raw: Record<string, Object>): MIoTSpecInstance {
  const props = raw['props'];
  if (props === undefined || props === null) {
    throw new Error('missing mijia spec props');
  }
  const propsObj = props as Record<string, Object>;
  const product = propsObj['product'] as Record<string, Object>;
  const tree = propsObj['tree'] as Record<string, Object>;
  const model = asString(product['model']);
  const servicesRaw = tree['services'];
  const instance: MIoTSpecInstance = {
    urn: `urn:miot-spec-v2:device:${model}`,
    name: asString(product['name']),
    description: asString(product['name']),
    services: []
  };
  if (!(servicesRaw instanceof Array)) {
    return instance;
  }
  for (let i = 0; i < servicesRaw.length; i++) {
    const service = parseMijiaSpecService(servicesRaw[i] as Record<string, Object>);
    if (service.iid > 0) {
      instance.services.push(service);
    }
  }
  return instance;
}

function parseMijiaSpecService(raw: Record<string, Object>): MIoTSpecService {
  const iid = asNumber(raw['iid']);
  const service: MIoTSpecService = {
    iid: iid,
    type: asString(raw['type']),
    name: lastTypeSegment(asString(raw['type'])),
    description: asString(raw['description']),
    properties: [],
    events: [],
    actions: [],
    proprietary: false,
    needFilter: false
  };
  const properties = raw['properties'];
  if (properties instanceof Array) {
    for (let i = 0; i < properties.length; i++) {
      const prop = parseMijiaSpecProperty(properties[i] as Record<string, Object>);
      if (prop.iid > 0) {
        service.properties.push(prop);
      }
    }
  }
  const actions = raw['actions'];
  if (actions instanceof Array) {
    for (let i = 0; i < actions.length; i++) {
      const action = parseMijiaSpecAction(actions[i] as Record<string, Object>);
      if (action.iid > 0) {
        service.actions.push(action);
      }
    }
  }
  return service;
}

function parseMijiaSpecProperty(raw: Record<string, Object>): MIoTSpecProperty {
  const access = parseStringList(raw['access']);
  return {
    iid: asNumber(raw['iid']),
    type: asString(raw['type']),
    name: lastTypeSegment(asString(raw['type'])),
    description: asString(raw['description']),
    format: normalizeFormat(asString(raw['format'])),
    access: access,
    readable: access.indexOf('read') >= 0,
    writable: access.indexOf('write') >= 0,
    notifiable: access.indexOf('notify') >= 0,
    unit: '',
    valueRange: parseValueRange(raw['valueRange']),
    valueList: parseMijiaValueList(raw['valueList']),
    precision: 1,
    expr: '',
    proprietary: false,
    needFilter: false
  };
}

function parseMijiaSpecAction(raw: Record<string, Object>): MIoTSpecAction {
  return {
    iid: asNumber(raw['iid']),
    type: asString(raw['type']),
    name: lastTypeSegment(asString(raw['type'])),
    description: asString(raw['description']),
    inPiids: [],
    outPiids: [],
    proprietary: false,
    needFilter: false
  };
}

function parseMijiaValueList(value: Object | undefined): MIoTSpecValueItem[] {
  if (!(value instanceof Array)) {
    return [];
  }
  const result: MIoTSpecValueItem[] = [];
  for (let i = 0; i < value.length; i++) {
    const item = value[i] as Record<string, Object>;
    const itemValue = item['value'];
    if (itemValue === undefined) {
      continue;
    }
    result.push({
      name: asString(item['description']),
      value: itemValue,
      description: asString(item['description'])
    });
  }
  return result;
}

export function parseMIoTSpecService(raw: Record<string, Object>): MIoTSpecService {
  const serviceType = asString(raw['type']);
  const service: MIoTSpecService = {
    iid: asNumber(raw['iid']),
    type: serviceType,
    name: lastTypeSegment(serviceType),
    description: asString(raw['description']),
    properties: [],
    events: [],
    actions: [],
    proprietary: asBoolean(raw['proprietary']),
    needFilter: asBoolean(raw['need_filter'])
  };
  const properties = raw['properties'];
  if (properties instanceof Array) {
    for (let i = 0; i < properties.length; i++) {
      const prop = parseMIoTSpecProperty(properties[i] as Record<string, Object>);
      if (prop.iid > 0) {
        service.properties.push(prop);
      }
    }
  }
  const events = raw['events'];
  if (events instanceof Array) {
    for (let i = 0; i < events.length; i++) {
      const event = parseMIoTSpecEvent(events[i] as Record<string, Object>);
      if (event.iid > 0) {
        service.events.push(event);
      }
    }
  }
  const actions = raw['actions'];
  if (actions instanceof Array) {
    for (let i = 0; i < actions.length; i++) {
      const action = parseMIoTSpecAction(actions[i] as Record<string, Object>);
      if (action.iid > 0) {
        service.actions.push(action);
      }
    }
  }
  return service;
}

export function parseMIoTSpecProperty(raw: Record<string, Object>): MIoTSpecProperty {
  const propertyType = asString(raw['type']);
  const access = parseStringList(raw['access']);
  const valueList = parseValueList(raw['value-list']);
  const valueRange = parseValueRange(raw['value-range']);
  const format = normalizeFormat(asString(raw['format']));
  return {
    iid: asNumber(raw['iid']),
    type: propertyType,
    name: lastTypeSegment(propertyType),
    description: asString(raw['description']),
    format: format,
    access: access,
    readable: access.indexOf('read') >= 0,
    writable: access.indexOf('write') >= 0,
    notifiable: access.indexOf('notify') >= 0,
    unit: normalizeUnit(asString(raw['unit'])),
    valueRange: valueRange,
    valueList: valueList,
    precision: asNumber(raw['precision']),
    expr: asString(raw['expr']),
    proprietary: asBoolean(raw['proprietary']),
    needFilter: asBoolean(raw['need_filter'])
  };
}

export function parseMIoTSpecEvent(raw: Record<string, Object>): MIoTSpecEvent {
  const eventType = asString(raw['type']);
  return {
    iid: asNumber(raw['iid']),
    type: eventType,
    name: lastTypeSegment(eventType),
    description: asString(raw['description']),
    argumentPiids: parseNumberList(raw['arguments']),
    proprietary: asBoolean(raw['proprietary']),
    needFilter: asBoolean(raw['need_filter'])
  };
}

export function parseMIoTSpecAction(raw: Record<string, Object>): MIoTSpecAction {
  const actionType = asString(raw['type']);
  return {
    iid: asNumber(raw['iid']),
    type: actionType,
    name: lastTypeSegment(actionType),
    description: asString(raw['description']),
    inPiids: parseNumberList(raw['in']),
    outPiids: parseNumberList(raw['out']),
    proprietary: asBoolean(raw['proprietary']),
    needFilter: asBoolean(raw['need_filter'])
  };
}

export function normalizeFormat(format: string): string {
  const value = format.toLowerCase();
  if (value === 'str') {
    return 'string';
  }
  if (value === 'string' || value === 'bool' || value === 'float' || value === 'int') {
    return value;
  }
  return 'int';
}

export function normalizeUnit(unit: string): string {
  if (unit.length === 0 || unit === 'none') {
    return '';
  }
  return unit;
}

function parseStringList(value: Object | undefined): string[] {
  if (!(value instanceof Array)) {
    return [];
  }
  const result: string[] = [];
  for (let i = 0; i < value.length; i++) {
    result.push(String(value[i]));
  }
  return result;
}

function parseNumberList(value: Object | undefined): number[] {
  if (!(value instanceof Array)) {
    return [];
  }
  const result: number[] = [];
  for (let i = 0; i < value.length; i++) {
    const number = Number(value[i]);
    if (!Number.isNaN(number)) {
      result.push(number);
    }
  }
  return result;
}

function parseValueRange(value: Object | undefined): MIoTSpecValueRange | null {
  if (!(value instanceof Array) || value.length < 3) {
    return null;
  }
  return {
    min: Number(value[0]),
    max: Number(value[1]),
    step: Number(value[2])
  };
}

function parseValueList(value: Object | undefined): MIoTSpecValueItem[] {
  if (!(value instanceof Array)) {
    return [];
  }
  const result: MIoTSpecValueItem[] = [];
  for (let i = 0; i < value.length; i++) {
    const item = value[i] as Record<string, Object>;
    const itemValue = item['value'];
    if (itemValue === undefined) {
      continue;
    }
    result.push({
      name: asString(item['name']),
      value: itemValue,
      description: asString(item['description'])
    });
  }
  return result;
}

function lastTypeSegment(value: string): string {
  const parts = value.split(':');
  return parts.length > 0 ? parts[parts.length - 1] : value;
}
