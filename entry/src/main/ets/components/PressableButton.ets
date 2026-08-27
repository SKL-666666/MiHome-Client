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

import { hdsEffect } from '@kit.UIDesignKit';

@Component
export struct PressableButton {
  @Prop label: string = '';
  @Prop emphasized: boolean = true;
  @Prop loading: boolean = false;
  @Prop fullWidth: boolean = true;
  @Prop buttonHeight: number = 48;
  @Prop role: ButtonRole = ButtonRole.NORMAL;
  onAction: () => void = (): void => {
  };
  @State private pressShadow: hdsEffect.PressShadowType = hdsEffect.PressShadowType.NONE;

  build() {
    Button(this.label, {
      type: ButtonType.Capsule,
      buttonStyle: this.emphasized ? ButtonStyleMode.EMPHASIZED : ButtonStyleMode.NORMAL,
      controlSize: ControlSize.NORMAL,
      stateEffect: true,
      role: this.role
    })
      .width(this.fullWidth ? '100%' : 'auto')
      .height(this.buttonHeight)
      .enabled(!this.loading)
      .visualEffect(new hdsEffect.HdsEffectBuilder().pressShadow(this.pressShadow).buildEffect())
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.pressShadow = hdsEffect.PressShadowType.BLEND_GRADIENT;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.pressShadow = hdsEffect.PressShadowType.NONE;
        }
      })
      .onClick(() => {
        this.onAction();
      })
  }
}
