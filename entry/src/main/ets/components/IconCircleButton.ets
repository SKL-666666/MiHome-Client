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

@Component
export struct IconCircleButton {
  @Prop buttonSize: number = 40;
  @Prop iconSize: number = 20;
  @Prop buttonEnabled: boolean = true;
  @Prop spinning: boolean = false;
  @Prop tint: string = '#182431';
  symbol: Resource = $r('sys.symbol.house');
  onAction: () => void = (): void => {
  };

  build() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(this.symbol)
        .fontSize(this.iconSize)
        .fontColor([this.tint])
        .rotate({
          z: 1,
          angle: this.spinning ? 360 : 0
        })
        .animation({
          duration: 900,
          curve: Curve.Linear,
          iterations: this.spinning ? -1 : 1,
          playMode: PlayMode.Normal
        })
    }
    .width(this.buttonSize)
    .height(this.buttonSize)
    .backgroundColor('#14000000')
    .enabled(this.buttonEnabled)
    .onClick(() => {
      this.onAction();
    })
  }
}
