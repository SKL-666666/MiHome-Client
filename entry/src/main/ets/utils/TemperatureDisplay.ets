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

export function isCelsiusUnit(unit: string): boolean {
  const key = unit.trim().toLowerCase();
  return key === 'celsius' || key === '°c' || key === 'c' ||
    key === 'degree celsius' || key === 'degrees celsius';
}

export function celsiusToFahrenheit(value: number): number {
  return value * 9 / 5 + 32;
}

export function fahrenheitToCelsius(value: number): number {
  return (value - 32) * 5 / 9;
}
