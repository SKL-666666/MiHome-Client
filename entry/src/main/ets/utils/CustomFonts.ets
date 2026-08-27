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

import { fileIo as fs } from '@kit.CoreFileKit';
import { text } from '@kit.ArkGraphics2D';

export function loadCustomFonts(filesDir: string, customFonts: string[]): void {
  try {
    const dir = `${filesDir}/custom_fonts`;
    if (!fs.accessSync(dir)) {
      fs.mkdirSync(dir);
      return;
    }
    for (let i = 0; i < customFonts.length; i++) {
      const fileName = customFonts[i];
      const targetPath = `${dir}/${fileName}`;
      if (!fs.accessSync(targetPath)) {
        continue;
      }
      const alias = fileName.substring(0, fileName.length - 4);
      try {
        text.FontCollection.getGlobalInstance().loadFontSyncWithCheck(alias, `file://${targetPath}`);
      } catch (err) {
        // Skip fonts that can no longer be loaded.
      }
    }
  } catch (err) {
  }
}
