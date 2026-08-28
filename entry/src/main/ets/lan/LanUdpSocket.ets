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

import { socket } from '@kit.NetworkKit';
import { LanConnectionError } from '../models/XiaomiErrors';

export class LanUdpSocket {
  private udp: socket.UDPSocket | null = null;

  async start(): Promise<void> {
    if (this.udp !== null) {
      return;
    }
    const udp = socket.constructUDPSocketInstance();
    await udp.bind({ address: '0.0.0.0', port: 0, family: 1 });
    this.udp = udp;
  }

  async send(address: string, port: number, data: Uint8Array): Promise<void> {
    if (this.udp === null) {
      throw new LanConnectionError('udp socket not started');
    }
    const netAddress: socket.NetAddress = {
      address: address,
      family: 1,
      port: port
    };
    const payload = data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength) as ArrayBuffer;
    await this.udp.send({
      data: payload,
      address: netAddress
    });
  }

  async request(
    address: string,
    port: number,
    data: Uint8Array,
    timeoutMs: number
  ): Promise<Uint8Array> {
    await this.start();
    if (this.udp === null) {
      throw new LanConnectionError('udp socket not started');
    }
    const udp = this.udp;
    return new Promise<Uint8Array>((resolve, reject) => {
      let settled = false;
      const listener = (info: socket.SocketMessageInfo): void => {
        if (info.remoteInfo.address !== address || info.remoteInfo.port !== port) {
          return;
        }
        settled = true;
        udp.off('message', listener);
        resolve(new Uint8Array(info.message));
      };
      udp.on('message', listener);
      setTimeout(() => {
        if (!settled) {
          udp.off('message', listener);
          reject(new LanConnectionError('lan request timeout'));
        }
      }, timeoutMs);
      this.send(address, port, data).catch((err: Error) => {
        if (!settled) {
          settled = true;
          udp.off('message', listener);
          reject(err);
        }
      });
    });
  }

  async close(): Promise<void> {
    if (this.udp === null) {
      return;
    }
    await this.udp.close();
    this.udp = null;
  }
}
