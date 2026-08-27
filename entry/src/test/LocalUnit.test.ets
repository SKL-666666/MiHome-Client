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

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { parseMIoTSpecInstance, MIoTSpecInstance } from '../main/ets/models/MIotSpecModels';
import { parseXiaomiDevice, parseXiaomiHome, XiaomiDevice, XiaomiHome } from '../main/ets/models/XiaomiHomeModels';
import { calcGroupId } from '../main/ets/utils/CryptoUtils';
import { buildServiceControls, CapabilityControlType } from '../main/ets/components/CapabilityRenderer';
import { DeviceEventBus, DeviceEvent } from '../main/ets/events/DeviceEventBus';
import { DeviceController } from '../main/ets/controllers/DeviceController';
import {
  DevicePropertyParam,
  DevicePropertyResult,
  SelectableDeviceTransport
} from '../main/ets/controllers/DeviceTransport';
import { XiaomiMqttClient, MqttConnectionState } from '../main/ets/mqtt/MqttClient';
import { LanDeviceTransport } from '../main/ets/lan/LanDeviceTransport';
import { LanDeviceSession } from '../main/ets/models/LanDeviceSession';
import { LanConnectionError } from '../main/ets/models/XiaomiErrors';
import { mijiaParamsToForm, rc4 } from '../main/ets/utils/MijiaCrypto';
import { bytesToHex, stringToBytes } from '../main/ets/utils/CryptoUtils';

interface RawHome {
  id: string;
  name: string;
  uid: string;
  roomlist: RawRoom[];
}

interface RawRoom {
  id: string;
  name: string;
  dids: string[];
}

interface RawDevice {
  did: string;
  name: string;
  spec_type: string;
  model: string;
  isOnline: boolean;
  pid: number;
}

interface RawSpec {
  type: string;
  description: string;
  services: RawService[];
}

interface RawService {
  iid: number;
  type: string;
  description: string;
  properties: RawProperty[];
}

interface RawProperty {
  iid: number;
  type: string;
  description: string;
  format: string;
  access: string[];
  unit: string;
}

interface TestPayload {
  value: boolean;
}

class WorkingTransport implements SelectableDeviceTransport {
  readonly kind: string = 'working';
  async isAvailable(): Promise<boolean> {
    return true;
  }
  async getProperty(did: string, siid: number, piid: number): Promise<Object | undefined> {
    return 'ok';
  }
  async getProperties(did: string, params: DevicePropertyParam[]): Promise<DevicePropertyResult[]> {
    const result: DevicePropertyResult[] = [];
    for (let i = 0; i < params.length; i++) {
      result.push({
        did: params[i].did,
        siid: params[i].siid,
        piid: params[i].piid,
        value: 'ok'
      });
    }
    return result;
  }
  async setProperty(did: string, siid: number, piid: number, value: Object): Promise<Object | undefined> {
    return value;
  }
  async callAction(did: string, siid: number, aiid: number, inList: Object[]): Promise<Record<string, Object> | undefined> {
    return undefined;
  }
}

class FailingTransport implements SelectableDeviceTransport {
  readonly kind: string = 'failing';
  async isAvailable(): Promise<boolean> {
    return true;
  }
  async getProperty(did: string, siid: number, piid: number): Promise<Object | undefined> {
    throw new Error('mock failure');
  }
  async getProperties(did: string, params: DevicePropertyParam[]): Promise<DevicePropertyResult[]> {
    throw new Error('mock failure');
  }
  async setProperty(did: string, siid: number, piid: number, value: Object): Promise<Object | undefined> {
    throw new Error('mock failure');
  }
  async callAction(did: string, siid: number, aiid: number, inList: Object[]): Promise<Record<string, Object> | undefined> {
    throw new Error('mock failure');
  }
}

export default function localUnitTest() {
  describe('XiaomiHomeHarmonyLocalUnit', () => {
    beforeAll(() => {
    });
    beforeEach(() => {
    });
    afterEach(() => {
    });
    afterAll(() => {
    });

    it('parseHome', 0, () => {
      const rawHome: RawHome = {
        id: 'home_1',
        name: '客厅家庭',
        uid: 'user_1',
        roomlist: [{
          id: 'room_1',
          name: '客厅',
          dids: ['did_1']
        }]
      };
      const home = parseXiaomiHome(rawHome as Object as Record<string, Object>, 'homelist', 'group_1');
      expect(home.homeId).assertEqual('home_1');
      expect(home.name).assertEqual('客厅家庭');
      expect(home.roomList.length).assertEqual(1);
      expect(home.roomList[0].dids[0]).assertEqual('did_1');
    });

    it('parseDevice', 0, () => {
      const rawDevice: RawDevice = {
        did: 'did_1',
        name: '智能灯',
        spec_type: 'urn:miot-spec-v2:device:light:0000A001:yeelink:1',
        model: 'yeelink.light.lamp1',
        isOnline: true,
        pid: 6
      };
      const device = parseXiaomiDevice(rawDevice as Object as Record<string, Object>);
      expect(device.did).assertEqual('did_1');
      expect(device.model).assertEqual('yeelink.light.lamp1');
      expect(device.online).assertEqual(true);
      expect(device.manufacturer).assertEqual('yeelink');
    });

    it('parseMiotSpec', 0, () => {
      const rawSpec: RawSpec = {
        type: 'urn:miot-spec-v2:device:light:0000A001:yeelink:1',
        description: 'Light',
        services: [{
          iid: 2,
          type: 'urn:miot-spec-v2:service:light:00007802:yeelink:1',
          description: 'Light service',
          properties: [{
            iid: 1,
            type: 'urn:miot-spec-v2:property:on:00000001:yeelink:1',
            description: 'On',
            format: 'bool',
            access: ['read', 'write', 'notify'],
            unit: 'none'
          }]
        }]
      };
      const spec = parseMIoTSpecInstance(rawSpec as Object as Record<string, Object>);
      expect(spec.urn).assertEqual(rawSpec.type);
      expect(spec.services.length).assertEqual(1);
      expect(spec.services[0].properties.length).assertEqual(1);
      expect(spec.services[0].properties[0].writable).assertEqual(true);
    });

    it('calcGroupId', 0, () => {
      expect(calcGroupId('user_1', 'home_1').length).assertEqual(16);
    });

    it('capabilityRenderer', 0, () => {
      const rawSpec: RawSpec = {
        type: 'urn:miot-spec-v2:device:light:0000A001:yeelink:1',
        description: 'Light',
        services: [{
          iid: 2,
          type: 'urn:miot-spec-v2:service:light:00007802:yeelink:1',
          description: 'Light service',
          properties: [{
            iid: 1,
            type: 'urn:miot-spec-v2:property:on:00000001:yeelink:1',
            description: 'On',
            format: 'bool',
            access: ['read', 'write', 'notify'],
            unit: 'none'
          }]
        }]
      };
      const spec = parseMIoTSpecInstance(rawSpec as Object as Record<string, Object>);
      const controls = buildServiceControls(spec.services[0]);
      expect(controls.length).assertEqual(1);
      expect(controls[0].siid).assertEqual(2);
      expect(controls[0].piid).assertEqual(1);
      expect(controls[0].type).assertEqual(CapabilityControlType.TOGGLE);
    });

    it('deviceEventBus', 0, () => {
      const bus = new DeviceEventBus();
      let count = 0;
      const unsubscribe = bus.subscribe('property_changed', (event: DeviceEvent) => {
        count += 1;
        expect(event.did).assertEqual('did_1');
      });
      const firstPayload: TestPayload = { value: true };
      const secondPayload: TestPayload = { value: false };
      bus.publish('property_changed', 'did_1', firstPayload);
      unsubscribe();
      bus.publish('property_changed', 'did_1', secondPayload);
      expect(count).assertEqual(1);
    });

    it('deviceControllerFallback', 0, async () => {
      const controller = new DeviceController(new FailingTransport(), new DeviceEventBus(), new WorkingTransport());
      const value = await controller.getProperty('did_1', 2, 1);
      expect(value).assertEqual('ok');
    });

    it('deviceControllerGetPropertiesFallback', 0, async () => {
      const controller = new DeviceController(new FailingTransport(), new DeviceEventBus(), new WorkingTransport());
      const values = await controller.getProperties('did_1', [{
        did: 'did_1',
        siid: 2,
        piid: 1
      }]);
      expect(values.length).assertEqual(1);
      expect(values[0].value).assertEqual('ok');
    });

    it('mqttMockState', 0, () => {
      const client = new XiaomiMqttClient();
      let delivered = 0;
      client.subscribe('topic/1', (topic: string, payload: Uint8Array) => {
        delivered += 1;
        expect(topic).assertEqual('topic/1');
      });
      client.markConnectedForMock();
      expect(client.getState()).assertEqual(MqttConnectionState.CONNECTED);
      client.deliverMockMessage('topic/1', new Uint8Array([1, 2, 3]));
      expect(delivered).assertEqual(1);
    });

    it('lanTransportUnverified', 0, async () => {
      const transport = new LanDeviceTransport();
      const session: LanDeviceSession = {
        did: 'did_1',
        address: '127.0.0.1',
        port: 54321,
        tokenHex: '00'.repeat(16),
        keyHex: '00'.repeat(16),
        ivHex: '00'.repeat(16)
      };
      transport.connect(session);
      expect(await transport.isAvailable()).assertEqual(true);
      let failed = false;
      try {
        await transport.getProperty('did_1', 2, 1);
      } catch (err) {
        failed = err instanceof LanConnectionError;
      }
      expect(failed).assertEqual(true);
    });

    it('rc4KnownVector', 0, () => {
      const key = new Uint8Array([0x4b, 0x65, 0x79]);
      const plaintext = new Uint8Array([0x50, 0x6c, 0x61, 0x69, 0x6e, 0x74, 0x65, 0x78, 0x74]);
      const output = rc4(key, plaintext, 0);
      expect(bytesToHex(output)).assertEqual('bbf316e8d940af0ad3');
    });

    it('mijiaFormEncoding', 0, () => {
      const form = mijiaParamsToForm([
        { key: 'a', value: '1 2' },
        { key: 'b', value: 'x/y' }
      ]);
      expect(form).assertEqual('a=1%202&b=x%2Fy');
    });
  });
}
