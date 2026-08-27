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

import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';

const OT_HEADER = 0x2131;
const OT_HEADER_LEN = 32;
const AES_BLOCK_SIZE = 16;

export function md5(data: Uint8Array): Uint8Array {
  const md = cryptoFramework.createMd('MD5');
  md.updateSync({ data: data });
  return md.digestSync().data;
}

export function lanKeyAndIv(token: Uint8Array): LanKeyIv {
  const key = md5(token);
  const combined = new Uint8Array(key.length + token.length);
  combined.set(key, 0);
  combined.set(token, key.length);
  const result: LanKeyIv = {
    key: key,
    iv: md5(combined)
  };
  return result;
}

export async function aesCbcEncrypt(
  key: Uint8Array,
  iv: Uint8Array,
  plainText: Uint8Array
): Promise<Uint8Array> {
  const padded = pkcs7Pad(plainText);
  const symKeyGenerator = cryptoFramework.createSymKeyGenerator('AES128');
  const symKey = symKeyGenerator.convertKeySync({ data: key });
  const cipher = cryptoFramework.createCipher('AES128|CBC|NoPadding');
  const params: cryptoFramework.IvParamsSpec = {
    algName: 'IvParamsSpec',
    iv: { data: iv }
  };
  await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, params);
  const first = await cipher.update({ data: padded });
  const final = await cipher.doFinal(null);
  return concatBytes(first.data, final.data);
}

export async function aesCbcDecrypt(
  key: Uint8Array,
  iv: Uint8Array,
  cipherText: Uint8Array
): Promise<Uint8Array> {
  const symKeyGenerator = cryptoFramework.createSymKeyGenerator('AES128');
  const symKey = symKeyGenerator.convertKeySync({ data: key });
  const cipher = cryptoFramework.createCipher('AES128|CBC|NoPadding');
  const params: cryptoFramework.IvParamsSpec = {
    algName: 'IvParamsSpec',
    iv: { data: iv }
  };
  await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, symKey, params);
  const first = await cipher.update({ data: cipherText });
  const final = await cipher.doFinal(null);
  return pkcs7Unpad(concatBytes(first.data, final.data));
}

interface LanKeyIv {
  key: Uint8Array;
  iv: Uint8Array;
}

export async function buildLanPacket(
  token: Uint8Array,
  did: string,
  msg: Object,
  offset: number
): Promise<Uint8Array> {
  const keyAndIv = lanKeyAndIv(token);
  const clearBytes = new Uint8Array(new util.TextEncoder().encode(JSON.stringify(msg)));
  const encrypted = await aesCbcEncrypt(keyAndIv.key, keyAndIv.iv, clearBytes);
  const dataLength = OT_HEADER_LEN + encrypted.length;
  const packet = new Uint8Array(dataLength);
  const view = new DataView(packet.buffer);
  view.setUint16(0, OT_HEADER, false);
  view.setUint16(2, dataLength, false);
  writeUint64(view, 4, Number(did));
  view.setUint32(12, offset, false);
  packet.set(token, 16);
  packet.set(encrypted, OT_HEADER_LEN);
  const checksum = md5(packet);
  packet.set(checksum, 16);
  return packet;
}

export async function decryptLanPacket(
  token: Uint8Array,
  packet: Uint8Array
): Promise<Record<string, Object>> {
  if (packet.length < OT_HEADER_LEN) {
    throw new Error('invalid lan packet length');
  }
  const view = new DataView(packet.buffer);
  const dataLength = view.getUint16(2, false);
  if (dataLength < OT_HEADER_LEN || dataLength > packet.length) {
    throw new Error('invalid lan packet data length');
  }
  const originalMd5 = packet.slice(16, 32);
  const check = new Uint8Array(packet);
  check.set(token, 16);
  const calculatedMd5 = md5(check.slice(0, dataLength));
  if (!bytesEqual(originalMd5, calculatedMd5)) {
    throw new Error('lan packet md5 mismatch');
  }
  const keyAndIv = lanKeyAndIv(token);
  const cipherText = packet.slice(OT_HEADER_LEN, dataLength);
  const clear = await aesCbcDecrypt(keyAndIv.key, keyAndIv.iv, cipherText);
  return JSON.parse(new util.TextDecoder('utf-8').decode(clear)) as Record<string, Object>;
}

function pkcs7Pad(data: Uint8Array): Uint8Array {
  const padLength = AES_BLOCK_SIZE - (data.length % AES_BLOCK_SIZE);
  const result = new Uint8Array(data.length + padLength);
  result.set(data, 0);
  for (let i = 0; i < padLength; i++) {
    result[data.length + i] = padLength;
  }
  return result;
}

function pkcs7Unpad(data: Uint8Array): Uint8Array {
  if (data.length === 0) {
    return data;
  }
  const padLength = data[data.length - 1];
  if (padLength <= 0 || padLength > AES_BLOCK_SIZE || padLength > data.length) {
    return data;
  }
  return data.slice(0, data.length - padLength);
}

function concatBytes(a: Uint8Array, b: Uint8Array): Uint8Array {
  const result = new Uint8Array(a.length + b.length);
  result.set(a, 0);
  result.set(b, a.length);
  return result;
}

function bytesEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) {
    return false;
  }
  for (let i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) {
      return false;
    }
  }
  return true;
}

function writeUint64(view: DataView, offset: number, value: number): void {
  const high = Math.floor(value / 0x100000000);
  const low = value >>> 0;
  view.setUint32(offset, high, false);
  view.setUint32(offset + 4, low, false);
}
