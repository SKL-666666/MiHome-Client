/*
 * 鸿米家（miha）— HarmonyOS NEXT native Xiaomi Home / MIoT control client.
 *
 * Copyright (C) 2026 鸿米家（miha）项目开发者
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

/**
 * 米家官方浅蓝白主题色板
 * - 页面背景：浅蓝
 * - 卡片：白色 / 深灰概览卡
 * - 顶栏：深蓝渐变
 */

export interface HwColorPalette {
  primary: string;
  background: string;
  backgroundDark: string;
  surface: string;
  textPrimary: string;
  textSecondary: string;
  danger: string;
  online: string;
}

export const HwColor: HwColorPalette = {
  primary: '#3379B7',         // 米家蓝
  background: '#DCEAF8',      // 浅蓝主背景
  backgroundDark: '#1A2D44',  // 深色背景（暗色模式）
  surface: '#FFFFFF',         // 白卡
  textPrimary: '#1A1A1A',     // 主文深
  textSecondary: '#7A8089',   // 副文灰
  danger: '#D94838',          // 警示红
  online: '#1AAB6A'           // 绿开
};

/** 首页顶栏深蓝渐变（自上而下：深→亮） */
export const MijiaHeaderGradient: string[] = ['#2F658C', '#3B7094', '#46789C'];

/** 概览/设备卡（灰色卡，浅蓝背景） */
export const MijiaOverviewCard: string = '#4E5A68';
export const MijiaOverviewCardPressed: string = '#414D59';
export const MijiaOverviewCardText: string = '#FFFFFF';
export const MijiaOverviewCardValue: string = '#A9D4FF';

/** 深色背景上的浅灰辅助文字 */
export const MijiaDarkSubText: string = '#A9B4C4';

/** 弹窗背景：浅蓝灰 */
export let MijiaSheetBackground: string = '#E3EAF4';

/**
 * 应用主题：把暗/浅色值写入 DesignTokens 的可变 token。
 * 页面已普遍 @StorageProp('isDarkMode')，翻转该键会触发整页重建，
 * 重建时读取到的是这里写入的最新值。
 */
export function applyAppTheme(isDark: boolean): void {
  HwColor.background = isDark ? '#1A2D44' : '#DCEAF8';
  HwColor.surface = isDark ? '#22334F' : '#FFFFFF';
  HwColor.textPrimary = isDark ? '#EDF1F7' : '#1A1A1A';
  HwColor.textSecondary = isDark ? '#9BA8BC' : '#7A8089';
  MijiaSheetBackground = isDark ? '#2A3B58' : '#E3EAF4';
  HwGlassCardColor.surface = isDark ? '#26364F' : '#E8F0F8';
}

/** 兼容旧引用（深色主题已回退，保留符号避免遗留编译失败） */
export const MijiaSkyGradient: string[] = MijiaHeaderGradient;
export const MijiaDarkCard: string = MijiaOverviewCard;
export const MijiaDarkCardPressed: string = MijiaOverviewCardPressed;
export const MijiaDarkCardText: string = MijiaOverviewCardText;
export const MijiaDarkCardSub: string = '#A0AAB8';
export const MijiaDarkCardIcon: string = MijiaOverviewCardValue;
export const MijiaWhiteCard: string = '#FFFFFF';
export const MijiaWhiteCardText: string = '#1A1A1A';
export const MijiaWhiteCardSub: string = '#7A8089';
export const MijiaOnButton: string = HwColor.online;
export const MijiaOffButton: string = '#4A5666';
export const MijiaTabBar: string = '#1A2D44';
export const MijiaTabBarActive: string = '#FFFFFF';
export const MijiaTabBarInactive: string = '#7A8493';
export const MijiaRoomPill: string = '#FFFFFF';
export const MijiaRoomPillActive: string = '#FFFFFF';
export const MijiaRoomPillText: string = '#FFFFFF';
export const MijiaRoomPillTextActive: string = '#2A4A6E';

export interface HwRadiusScale {
  card: number;
  control: number;
  pill: number;
  small: number;
  large: number;
}

export const HwRadius: HwRadiusScale = {
  card: 14,
  control: 12,
  pill: 999,
  small: 8,
  large: 18
};

export interface HwSpaceScale {
  xs: number;
  sm: number;
  md: number;
  lg: number;
  xl: number;
}

export const HwSpace: HwSpaceScale = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24
};

export interface HwGlassCardPalette {
  surface: string;
  border: string;
}

export const HwGlassCardColor: HwGlassCardPalette = {
  surface: '#E8F0F8',
  border: '#1A3379B7'
};
