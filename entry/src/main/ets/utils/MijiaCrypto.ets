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

export interface MijiaParam {
  key: string;
  value: string;
}

function encodeBase64(data: Uint8Array): string {
  return new util.Base64Helper().encodeToStringSync(data);
}

function decodeBase64(value: string): Uint8Array {
  return new util.Base64Helper().decodeSync(value);
}

function utf8(value: string): Uint8Array {
  return new util.TextEncoder().encode(value);
}

function utf8String(value: Uint8Array): string {
  return new util.TextDecoder('utf-8').decode(value);
}

export function sha256Base64(data: Uint8Array): string {
  const md = cryptoFramework.createMd('SHA256');
  md.updateSync({ data: data });
  return encodeBase64(md.digestSync().data);
}

export function genMijiaNonce(): string {
  const randomBytes = cryptoFramework.createRandom().generateRandomSync(8).data;
  const millis = Date.now();
  const minutes = Math.floor(millis / 60000);
  const minuteBytes = encodeIntegerBigEndian(minutes);
  const combined = new Uint8Array(randomBytes.length + minuteBytes.length);
  combined.set(randomBytes, 0);
  combined.set(minuteBytes, randomBytes.length);
  return encodeBase64(combined);
}

export function getSignedMijiaNonce(ssecurity: string, nonce: string): string {
  const ssecurityBytes = decodeBase64(ssecurity);
  const nonceBytes = decodeBase64(nonce);
  const combined = new Uint8Array(ssecurityBytes.length + nonceBytes.length);
  combined.set(ssecurityBytes, 0);
  combined.set(nonceBytes, ssecurityBytes.length);
  return sha256Base64(combined);
}

export function encryptMijiaRc4(keyBase64: string, plainText: string): string {
  const key = decodeBase64(keyBase64);
  const cipher = rc4(key, utf8(plainText), 1024);
  return encodeBase64(cipher);
}

export function decryptMijiaRc4(keyBase64: string, cipherBase64: string): Uint8Array {
  const key = decodeBase64(keyBase64);
  return rc4(key, decodeBase64(cipherBase64), 1024);
}

export function genMijiaEncSignature(
  uri: string,
  method: string,
  signedNonce: string,
  params: MijiaParam[]
): string {
  const parts: string[] = [method.toUpperCase(), uri];
  for (let i = 0; i < params.length; i++) {
    parts.push(`${params[i].key}=${params[i].value}`);
  }
  parts.push(signedNonce);
  const signatureBytes = utf8(parts.join('&'));
  const md = cryptoFramework.createMd('SHA1');
  md.updateSync({ data: signatureBytes });
  return encodeBase64(md.digestSync().data);
}

export function generateMijiaEncParams(
  uri: string,
  method: string,
  signedNonce: string,
  nonce: string,
  params: MijiaParam[],
  ssecurity: string
): MijiaParam[] {
  const rc4HashPlain = genMijiaEncSignature(uri, method, signedNonce, params);
  const paramsWithHash: MijiaParam[] = [];
  for (let i = 0; i < params.length; i++) {
    paramsWithHash.push({
      key: params[i].key,
      value: params[i].value
    });
  }
  paramsWithHash.push({ key: 'rc4_hash__', value: rc4HashPlain });
  const encrypted: MijiaParam[] = [];
  for (let i = 0; i < paramsWithHash.length; i++) {
    encrypted.push({
      key: paramsWithHash[i].key,
      value: encryptMijiaRc4(signedNonce, paramsWithHash[i].value)
    });
  }
  const signature = genMijiaEncSignature(uri, method, signedNonce, encrypted);
  encrypted.push({ key: 'signature', value: signature });
  encrypted.push({ key: 'ssecurity', value: ssecurity });
  encrypted.push({ key: '_nonce', value: nonce });
  return encrypted;
}

export function mijiaParamsToForm(params: MijiaParam[]): string {
  const parts: string[] = [];
  for (let i = 0; i < params.length; i++) {
    parts.push(`${encodeURIComponent(params[i].key)}=${encodeURIComponent(params[i].value)}`);
  }
  return parts.join('&');
}

export function rc4(key: Uint8Array, data: Uint8Array, dropBytes: number): Uint8Array {
  const s: number[] = new Array<number>(256);
  for (let i = 0; i < 256; i++) {
    s[i] = i;
  }
  let j = 0;
  for (let i = 0; i < 256; i++) {
    j = (j + s[i] + key[i % key.length]) & 0xFF;
    const tmp = s[i];
    s[i] = s[j];
    s[j] = tmp;
  }
  let i = 0;
  j = 0;
  for (let n = 0; n < dropBytes; n++) {
    i = (i + 1) & 0xFF;
    j = (j + s[i]) & 0xFF;
    const tmp = s[i];
    s[i] = s[j];
    s[j] = tmp;
  }
  const output = new Uint8Array(data.length);
  for (let n = 0; n < data.length; n++) {
    i = (i + 1) & 0xFF;
    j = (j + s[i]) & 0xFF;
    const tmp = s[i];
    s[i] = s[j];
    s[j] = tmp;
    const k = s[(s[i] + s[j]) & 0xFF];
    output[n] = data[n] ^ k;
  }
  return output;
}

function encodeIntegerBigEndian(value: number): Uint8Array {
  if (value === 0) {
    return new Uint8Array([0]);
  }
  const bytes: number[] = [];
  let remaining = value;
  while (remaining > 0) {
    bytes.push(remaining & 0xFF);
    remaining = Math.floor(remaining / 256);
  }
  bytes.reverse();
  const result = new Uint8Array(bytes.length);
  for (let i = 0; i < bytes.length; i++) {
    result[i] = bytes[i];
  }
  return result;
}
