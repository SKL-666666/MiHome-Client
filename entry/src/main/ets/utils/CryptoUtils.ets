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

import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';

export function stringToBytes(value: string): Uint8Array {
  return new util.TextEncoder().encode(value);
}

export function bytesToString(value: Uint8Array): string {
  return new util.TextDecoder('utf-8').decode(value);
}

export function bytesToHex(value: Uint8Array): string {
  let out = '';
  for (let i = 0; i < value.length; i++) {
    const byte = value[i] & 0xFF;
    const hex = byte.toString(16).padStart(2, '0');
    out += hex;
  }
  return out;
}

export function sha1Hex(value: string): string {
  return bytesToHex(sha1Bytes(stringToBytes(value)));
}

export function buildOauthState(uuid: string): string {
  const deviceId = `ha.${uuid}`;
  return sha1Hex(`d=${deviceId}`);
}

export function calcGroupId(uid: string, homeId: string): string {
  return sha1Hex(`${uid}central_service${homeId}`).slice(0, 16);
}

function sha1Bytes(input: Uint8Array): Uint8Array {
  const length = input.length;
  const chunkCount = ((length + 8) >> 6) + 1;
  const words: number[] = new Array<number>(chunkCount * 16);
  for (let i = 0; i < words.length; i++) {
    words[i] = 0;
  }
  for (let i = 0; i < length; i++) {
    words[i >> 2] |= (input[i] & 0xFF) << (24 - (i % 4) * 8);
  }
  words[length >> 2] |= 0x80 << (24 - (length % 4) * 8);
  words[words.length - 1] = length * 8;

  let h0 = 0x67452301;
  let h1 = 0xEFCDAB89;
  let h2 = 0x98BADCFE;
  let h3 = 0x10325476;
  let h4 = 0xC3D2E1F0;

  const w: number[] = new Array<number>(80);
  for (let chunk = 0; chunk < chunkCount; chunk++) {
    for (let i = 0; i < 16; i++) {
      w[i] = words[chunk * 16 + i];
    }
    for (let i = 16; i < 80; i++) {
      const n = w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16];
      w[i] = rotl(n, 1);
    }
    let a = h0;
    let b = h1;
    let c = h2;
    let d = h3;
    let e = h4;
    for (let i = 0; i < 80; i++) {
      let f = 0;
      let k = 0;
      if (i < 20) {
        f = (b & c) | ((~b) & d);
        k = 0x5A827999;
      } else if (i < 40) {
        f = b ^ c ^ d;
        k = 0x6ED9EBA1;
      } else if (i < 60) {
        f = (b & c) | (b & d) | (c & d);
        k = 0x8F1BBCDC;
      } else {
        f = b ^ c ^ d;
        k = 0xCA62C1D6;
      }
      const temp = (rotl(a, 5) + f + e + k + w[i]) >>> 0;
      e = d;
      d = c;
      c = rotl(b, 30);
      b = a;
      a = temp;
    }
    h0 = (h0 + a) >>> 0;
    h1 = (h1 + b) >>> 0;
    h2 = (h2 + c) >>> 0;
    h3 = (h3 + d) >>> 0;
    h4 = (h4 + e) >>> 0;
  }

  const output = new Uint8Array(20);
  writeUint32(output, 0, h0);
  writeUint32(output, 4, h1);
  writeUint32(output, 8, h2);
  writeUint32(output, 12, h3);
  writeUint32(output, 16, h4);
  return output;
}

function rotl(value: number, bits: number): number {
  return ((value << bits) | (value >>> (32 - bits))) >>> 0;
}

function writeUint32(target: Uint8Array, offset: number, value: number): void {
  target[offset] = (value >>> 24) & 0xFF;
  target[offset + 1] = (value >>> 16) & 0xFF;
  target[offset + 2] = (value >>> 8) & 0xFF;
  target[offset + 3] = value & 0xFF;
}

export function randomUuid(prefix: string = 'app'): string {
  const random = cryptoFramework.createRandom().generateRandomSync(16).data;
  const digest = sha1Hex(`${prefix}.${bytesToHex(random)}`);
  return digest.slice(0, 32);
}
