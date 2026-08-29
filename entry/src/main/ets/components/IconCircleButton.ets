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
  @Prop @Watch('handleSpinningChange') spinning: boolean = false;
  @Prop tint: string = '#182431';
  @State spinAngle: number = 0;
  symbol: Resource = $r('sys.symbol.house');
  onAction: () => void = (): void => {
  };

  private handleSpinningChange(): void {
    if (!this.spinning) {
      this.spinAngle = 0;
    }
  }

  build() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      if (this.spinning) {
        SymbolGlyph(this.symbol)
          .fontSize(this.iconSize)
          .fontColor([this.tint])
          .rotate({ z: 1, angle: this.spinAngle })
          .animation({
            duration: 900,
            curve: Curve.Linear,
            iterations: -1,
            playMode: PlayMode.Normal
          })
          .onAppear(() => {
            this.spinAngle = 360;
          })
      } else {
        SymbolGlyph(this.symbol)
          .fontSize(this.iconSize)
          .fontColor([this.tint])
      }
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
