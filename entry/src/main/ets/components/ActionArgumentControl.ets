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

import { ActionArgumentDescriptor } from './CapabilityRenderer';
import { HwRadius, HwSpace, MijiaOverviewCard, MijiaOverviewCardValue } from '../utils/DesignTokens';

@Component
export struct ActionArgumentControl {
  @StorageLink('fontMode') fontMode: string = 'system';
  @StorageLink('fontFamilyEn') fontFamilyEn: string = 'system';
  @StorageLink('fontFamilyZh') fontFamilyZh: string = 'system';

  private appFontFamily(content: string): string {
    if (this.fontMode !== 'custom') {
      return '';
    }
    const family = this.hasCjk(content) ? this.fontFamilyZh : this.fontFamilyEn;
    return family === 'system' || family.length === 0 ? '' : family;
  }

  private hasCjk(content: string): boolean {
    for (let i = 0; i < content.length; i++) {
      const code = content.charCodeAt(i);
      if (code >= 0x4E00 && code <= 0x9FFF) {
        return true;
      }
    }
    return false;
  }
  @StorageLink('fontWeightMode') fontWeightMode: string = 'system';
  @StorageLink('fontWeightValue') fontWeightValue: number = 400;

  private appFontWeight(): number {
    return this.fontWeightMode === 'custom' ? this.fontWeightValue : 400;
  }
  @Prop argument: ActionArgumentDescriptor;
  @Prop @Watch('onValuePropChanged') value: Object | undefined;
  onChanged: (value: Object) => void = (): void => {
  };
  @State private lastValue: Object | undefined = undefined;
  @State private userGesture: boolean = false;
  @State private draft: string = '';

  aboutToAppear(): void {
    this.lastValue = this.value;
    this.draft = this.stringOf(this.value);
  }

  onValuePropChanged(): void {
    this.lastValue = this.value;
    this.draft = this.stringOf(this.value);
  }

  private boolOf(input: Object | undefined): boolean {
    return input === true || input === 1 || input === 'true' || input === '1';
  }

  private stringOf(input: Object | undefined): string {
    return String(input ?? '');
  }

  private commitText(): void {
    if (this.draft === this.stringOf(this.lastValue)) {
      return;
    }
    if (this.argument.format === 'float') {
      this.onChanged(Number(this.draft));
    } else {
      this.onChanged(this.draft);
    }
  }

  build() {
    Column({ space: 6 }) {
      Text(this.argument.label)
        .fontFamily(this.appFontFamily(this.argument.label))
        .fontWeight(this.appFontWeight())
        .fontSize(14)
        .fontColor(Color.White)

      if (this.argument.format === 'bool') {
        Toggle({ type: ToggleType.Switch, isOn: this.boolOf(this.value) })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.userGesture = true;
            }
          })
          .onChange((isOn: boolean) => {
            if (!this.userGesture) {
              return;
            }
            this.userGesture = false;
            if (isOn === this.boolOf(this.lastValue)) {
              return;
            }
            this.onChanged(isOn);
          })
      }

      if (this.argument.format !== 'bool' && this.argument.options.length > 0) {
        Flex({
          wrap: FlexWrap.Wrap,
          justifyContent: FlexAlign.SpaceBetween,
          alignItems: ItemAlign.Start
        }) {
          ForEach(this.argument.options, (option: string, index?: number) => {
            Column() {
              Column({ space: 4 }) {
                Text(option)
                  .fontFamily(this.appFontFamily(option))
                  .fontWeight(this.appFontWeight())
                  .fontSize(14)
                  .fontColor(this.value === this.argument.optionValues[index ?? 0]
                    ? MijiaOverviewCardValue : Color.White)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%')
              .height(56)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .borderRadius(HwRadius.control)
              .backgroundColor(this.value === this.argument.optionValues[index ?? 0]
                ? '#263379B7' : '#1A000000')
              .border({
                width: 1,
                color: this.value === this.argument.optionValues[index ?? 0]
                  ? MijiaOverviewCardValue : '#24FFFFFF'
              })
              .clip(true)
              .onClick(() => {
                this.onChanged(this.argument.optionValues[index ?? 0]);
              })
            }
            .width('48.5%')
            .margin({ bottom: 10 })
          }, (option: string) => option)
        }
        .width('100%')
      }

      if (this.argument.format !== 'bool' && this.argument.options.length === 0) {
        TextInput({ text: this.draft })
          .onChange((text: string) => {
            this.draft = text;
          })
          .onSubmit(() => {
            this.commitText();
          })
          .onBlur(() => {
            this.commitText();
          })
      }
    }
    .width('100%')
    .padding(HwSpace.md)
    .borderRadius(HwRadius.control)
    .backgroundColor(MijiaOverviewCard)
    .border({ width: 1, color: '#24FFFFFF' })
    .clip(true)
  }
}
