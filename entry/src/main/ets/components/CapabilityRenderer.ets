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

import {
  MIoTSpecAction,
  MIoTSpecProperty,
  MIoTSpecService
} from '../models/MIotSpecModels';
import { FeedbackLogService } from '../services/FeedbackLogService';

const MIOT_TEXT_DICTIONARY: Record<string, string> = {
  'switch status': '开关',
  'switch': '开关',
  'on': '开',
  'off': '关',
  'power': '电源',
  'mode': '模式',
  'temperature': '温度',
  'humidity': '湿度',
  'relative humidity': '相对湿度',
  'target temperature': '目标温度',
  'current temperature': '当前温度',
  'current humidity': '当前湿度',
  'fan speed': '风速',
  'fan level': '风速档位',
  'fan': '送风',
  'swing': '扫风',
  'swing mode': '扫风模式',
  'horizontal swing': '水平扫风',
  'vertical swing': '垂直扫风',
  'filter life': '滤芯寿命',
  'filter life level': '滤芯寿命',
  'filter used time': '滤芯已用时间',
  'brightness': '亮度',
  'color temperature': '色温',
  'color': '颜色',
  'volume': '音量',
  'battery': '电量',
  'battery level': '电量',
  'charging state': '充电状态',
  'current power': '当前功率',
  'power consumption': '用电量',
  'electric current': '电流',
  'current': '电流',
  'electric power': '电功率',
  'voltage': '电压',
  'delay off': '延时关闭',
  'remaining time': '剩余时间',
  'timer': '定时',
  'child lock': '童锁',
  'indicator light': '指示灯',
  'buzzer': '提示音',
  'status': '状态',
  'device status': '设备状态',
  'standby': '待机',
  'device fault': '设备故障',
  'fault': '故障',
  'fault code': '故障码',
  'error code': '错误码',
  'working state': '工作状态',
  'work state': '工作状态',
  'lock state': '锁定状态',
  'lock': '锁定',
  'unlock': '解锁',
  'open': '打开',
  'close': '关闭',
  'curtain': '窗帘',
  'curtain level': '开合度',
  'open level': '开合度',
  'target humidity': '目标湿度',
  'water level': '水位',
  'particle': '颗粒物',
  'particulate matter': '颗粒物',
  'tvoc': 'TVOC',
  'tvoc density': 'TVOC 浓度',
  'aqi': '空气质量指数',
  'iaq': '室内空气质量',
  'air quality index': '空气质量指数',
  'co2': 'CO2',
  'target power': '目标功率',
  'work mode': '工作模式',
  'air quality': '空气质量',
  'pm2.5 density': 'PM2.5 浓度',
  'pm2.5': 'PM2.5',
  'co2 density': 'CO2 浓度',
  'formaldehyde density': '甲醛浓度',
  'illumination': '光照度',
  'light': '灯光',
  'level': '档位',
  'speed': '速度',
  'speed level': '速度档位',
  'mute': '静音',
  'toggle': '切换',
  'turn on': '开启',
  'turn off': '关闭',
  'start': '启动',
  'stop': '停止',
  'pause': '暂停',
  'set mode': '设置模式',
  'set temperature': '设置温度',
  'set fan speed': '设置风速',
  'set swing': '设置扫风',
  'set brightness': '设置亮度',
  'set color temperature': '设置色温',
  'auto': '自动',
  'low': '低',
  'medium': '中',
  'high': '高',
  'weak': '弱',
  'strong': '强力',
  'max': '最大',
  'min': '最小',
  'fast': '快',
  'slow': '慢',
  'quiet': '安静',
  'turbo': '强力',
  'comfort': '舒适',
  'energy saving': '节能',
  'standard': '标准',
  'night': '夜间',
  'day': '白天',
  'cool': '制冷',
  'heat': '制热',
  'dry': '除湿',
  'wind': '风速',
  'horizontal': '水平',
  'vertical': '垂直',
  'sleep': '睡眠',
  'normal': '标准',
  'favorite': '最爱',
  'favorite fan level': '最爱模式风扇等级',
  'physical control locked': '物理按钮锁',
  'working mode': '工作模式',
  'power switch': '电源开关',
  'power on': '开机',
  'power off': '关机',
  'sleep mode': '睡眠模式',
  'night light': '夜灯',
  'night mode': '夜间模式',
  'timer on': '定时开',
  'timer off': '定时关',
  'countdown': '倒计时',
  'count down': '倒计时',
  'schedule': '日程',
  'alarm': '闹钟',
  'duration': '时长',
  'interval': '间隔',
  'frequency': '频率',
  'smart': '智能',
  'custom': '自定义',
  'eco': '节能',
  'manual': '手动',
  'natural': '自然',
  'soft': '柔和',
  'bright': '明亮',
  'dim': '昏暗',
  'warm white': '暖白',
  'cool white': '冷白',
  'daylight': '日光',
  'scene': '场景',
  'scene mode': '场景模式',
  'color mode': '颜色模式',
  'light mode': '灯光模式',
  'brightness level': '亮度档位',
  'saturation': '饱和度',
  'hue': '色相',
  'reset': '复位',
  'filter reset': '滤芯复位',
  'calibrate': '校准',
  'pair': '配对',
  'connect': '连接',
  'disconnect': '断开',
  'up': '上升',
  'down': '下降',
  'direction': '方向',
  'position': '位置',
  'angle': '角度',
  'target position': '目标位置',
  'current angle': '当前角度',
  'play': '播放',
  'next': '下一首',
  'previous': '上一首',
  'forward': '快进',
  'backward': '快退',
  'shuffle': '随机播放',
  'repeat': '循环',
  'wake': '唤醒',
  'voice': '语音',
  'media': '媒体',
  'humidify': '加湿',
  'dehumidify': '除湿',
  'purify': '净化',
  'sterilize': '杀菌',
  'anion': '负离子',
  'plasma': '等离子',
  'uv': '紫外线',
    'filter': '滤芯',
    // 设备通用状态枚举补录
    'idle': '空闲',
  'busy': '繁忙',
  'running': '运行中',
  'stopped': '已停止',
  'opened': '已打开',
  'opening': '打开中',
  'closed': '已关闭',
  'closing': '关闭中',
  'on-going': '进行中',
  'unknown': '未知',
  'none': '无',
  'default': '默认',
  'silent': '静音模式',
  'dnd': '勿扰',
  'away': '离家',
  'home': '在家',
  'vacation': '度假',
  'access mode': '接入方式',
  'wifi service set identifier': 'WiFi 配置',
  'dhcp server mac adress': 'DHCP 服务器 MAC 地址',
  'wireless 5 g': '无线 5G',
  'wireless 5g': '无线 5G',
  'wireless 2 g': '无线 2G',
  'wireless 2g': '无线 2G',
  'virtual param': '虚拟参数',
  'emit virtual event': '触发虚拟事件',
  'mode for ir': '模式',
  'temperature for ir': '温度'
};

/** 全局通用 MIoT 词条翻译：词典精确匹配 + 组合词/分词多级回退，未命中原样返回 */
export function translateMiotText(input: string): string {
  const key = input.trim().toLowerCase().replace(/[-_]/g, ' ');
  const exact = MIOT_TEXT_DICTIONARY[key];
  if (exact !== undefined) {
    return exact;
  }

  if (key.endsWith(' mode')) {
    const base = key.slice(0, key.length - ' mode'.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}模式`;
    }
  }
  if (key.endsWith(' level')) {
    const base = key.slice(0, key.length - ' level'.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}档位`;
    }
  }
  if (key.endsWith(' speed')) {
    const base = key.slice(0, key.length - ' speed'.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}速度`;
    }
  }
  if (key.endsWith(' state')) {
    const base = key.slice(0, key.length - ' state'.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}状态`;
    }
  }
  if (key.endsWith(' status')) {
    const base = key.slice(0, key.length - ' status'.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}状态`;
    }
  }
  if (key.startsWith('set ')) {
    const rest = key.slice('set '.length).trim();
    const restText = MIOT_TEXT_DICTIONARY[rest];
    if (restText !== undefined) {
      return `设置${restText}`;
    }
  }
  if (key.endsWith(' protection')) {
    const base = key.slice(0, key.length - ' protection'.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}保护`;
    }
  }
  if (key.endsWith(' warning')) {
    const base = key.slice(0, key.length - ' warning'.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}告警`;
    }
  }
  if (key.endsWith(' alarm')) {
    const base = key.slice(0, key.length - ' alarm'.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}告警`;
    }
  }
  if (key.endsWith(' enabled')) {
    const base = key.slice(0, key.length - ' enabled'.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}启用`;
    }
  }
  if (key.endsWith(' disabled')) {
    const base = key.slice(0, key.length - ' disabled'.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}禁用`;
    }
  }
  if (key.endsWith(' locked')) {
    const base = key.slice(0, key.length - ' locked'.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}已锁定`;
    }
  }
  if (key.endsWith(' unlocked')) {
    const base = key.slice(0, key.length - ' unlocked'.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}已解锁`;
    }
  }
  if (key.endsWith(' reminder')) {
    const base = key.slice(0, key.length - ' reminder'.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}提醒`;
    }
  }
  if (key.endsWith(' temperature')) {
    const base = key.slice(0, key.length - ' temperature'.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}温度`;
    }
  }
  if (key.endsWith(' sensor')) {
    const base = key.slice(0, key.length - ' sensor'.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}传感器`;
    }
  }
  if (key.endsWith(' detector')) {
    const base = key.slice(0, key.length - ' detector'.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}探测器`;
    }
  }
  if (key.endsWith(' detection')) {
    const base = key.slice(0, key.length - ' detection'.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}检测`;
    }
  }
  if (key.endsWith(' switch')) {
    const base = key.slice(0, key.length - ' switch'.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}开关`;
    }
  }
  if (key.endsWith(' control')) {
    const base = key.slice(0, key.length - ' control'.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}控制`;
    }
  }
  if (key.endsWith(' button')) {
    const base = key.slice(0, key.length - ' button'.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}按钮`;
    }
  }
  if (key.endsWith(' count') || key.endsWith(' times')) {
    const suffix = key.endsWith(' count') ? ' count' : ' times';
    const base = key.slice(0, key.length - suffix.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}次数`;
    }
  }
  if (key.endsWith(' percent') || key.endsWith(' percentage')) {
    const suffix = key.endsWith(' percent') ? ' percent' : ' percentage';
    const base = key.slice(0, key.length - suffix.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}百分比`;
    }
  }
  if (key.endsWith(' ratio')) {
    const base = key.slice(0, key.length - ' ratio'.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}比例`;
    }
  }
  if (key.endsWith(' value')) {
    const base = key.slice(0, key.length - ' value'.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}值`;
    }
  }
  if (key.endsWith(' capacity')) {
    const base = key.slice(0, key.length - ' capacity'.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}容量`;
    }
  }
  if (key.endsWith(' strength') || key.endsWith(' intensity')) {
    const suffix = key.endsWith(' strength') ? ' strength' : ' intensity';
    const base = key.slice(0, key.length - suffix.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}强度`;
    }
  }
  if (key.endsWith(' pressure')) {
    const base = key.slice(0, key.length - ' pressure'.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}压力`;
    }
  }
  if (key.endsWith(' power')) {
    const base = key.slice(0, key.length - ' power'.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}功率`;
    }
  }
  if (key.endsWith(' energy')) {
    const base = key.slice(0, key.length - ' energy'.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}能耗`;
    }
  }
  if (key.endsWith(' consumption')) {
    const base = key.slice(0, key.length - ' consumption'.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}消耗`;
    }
  }
  if (key.endsWith(' density') || key.endsWith(' concentration')) {
    const suffix = key.endsWith(' density') ? ' density' : ' concentration';
    const base = key.slice(0, key.length - suffix.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}浓度`;
    }
  }
  if (key.endsWith(' time') || key.endsWith(' duration')) {
    const suffix = key.endsWith(' time') ? ' time' : ' duration';
    const base = key.slice(0, key.length - suffix.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}时长`;
    }
  }
  if (key.endsWith(' frequency')) {
    const base = key.slice(0, key.length - ' frequency'.length).trim();
    const baseText = MIOT_TEXT_DICTIONARY[base];
    if (baseText !== undefined) {
      return `${baseText}频率`;
    }
  }
  if (key.startsWith('get ')) {
    const rest = key.slice('get '.length).trim();
    const restText = MIOT_TEXT_DICTIONARY[rest];
    if (restText !== undefined) {
      return `获取${restText}`;
    }
  }
  if (key.startsWith('stop ')) {
    const rest = key.slice('stop '.length).trim();
    const restText = MIOT_TEXT_DICTIONARY[rest];
    if (restText !== undefined) {
      return `停止${restText}`;
    }
  }
  if (key.startsWith('start ')) {
    const rest = key.slice('start '.length).trim();
    const restText = MIOT_TEXT_DICTIONARY[rest];
    if (restText !== undefined) {
      return `开始${restText}`;
    }
  }

  // 分词兜底：整词未命中时，若每个词都能单独翻译则组合（去掉空格）
  const words = key.split(' ');
  if (words.length >= 2 && words.length <= 5) {
    const stopWords: string[] = ['the', 'a', 'an', 'of', 'for', 'with', 'to', 'in', 'on'];
    let composed = '';
    let allHit = true;
    for (let i = 0; i < words.length; i++) {
      if (stopWords.indexOf(words[i]) >= 0) {
        continue;
      }
      const wordText = MIOT_TEXT_DICTIONARY[words[i]];
      if (wordText === undefined) {
        allHit = false;
        break;
      }
      composed += wordText;
    }
    if (allHit && composed.length > 0) {
      return composed;
    }
  }

  FeedbackLogService.recordOperation('TRANSLATE', `未翻译: ${input}`);
  return input;
}

MIOT_TEXT_DICTIONARY['electric energy'] = '用电量';
MIOT_TEXT_DICTIONARY['energy'] = '能耗';
MIOT_TEXT_DICTIONARY['cumulative energy'] = '累计用电量';
MIOT_TEXT_DICTIONARY['total energy'] = '总用电量';
MIOT_TEXT_DICTIONARY['daily energy'] = '今日用电量';
MIOT_TEXT_DICTIONARY['monthly energy'] = '本月用电量';
MIOT_TEXT_DICTIONARY['actual power'] = '实际功率';
MIOT_TEXT_DICTIONARY['rated power'] = '额定功率';
MIOT_TEXT_DICTIONARY['power factor'] = '功率因数';
MIOT_TEXT_DICTIONARY['overload'] = '过载';
MIOT_TEXT_DICTIONARY['over current'] = '过流';
MIOT_TEXT_DICTIONARY['over voltage'] = '过压';
MIOT_TEXT_DICTIONARY['under voltage'] = '欠压';
MIOT_TEXT_DICTIONARY['surge'] = '浪涌';
MIOT_TEXT_DICTIONARY['led'] = '指示灯';
MIOT_TEXT_DICTIONARY['auto off'] = '自动关闭';
MIOT_TEXT_DICTIONARY['auto on'] = '自动开启';
MIOT_TEXT_DICTIONARY['speed mode'] = '风速模式';
MIOT_TEXT_DICTIONARY['fan mode'] = '送风模式';
MIOT_TEXT_DICTIONARY['air volume'] = '风量';
MIOT_TEXT_DICTIONARY['power save'] = '省电';
MIOT_TEXT_DICTIONARY['power saving'] = '省电';
MIOT_TEXT_DICTIONARY['pm 2.5'] = 'PM2.5';
MIOT_TEXT_DICTIONARY['particulate matter'] = '颗粒物';
MIOT_TEXT_DICTIONARY['particles'] = '颗粒物';

// —— 小众品类/厂商自定义词条补充（真机验证中发现的英文残留） ——
MIOT_TEXT_DICTIONARY['gear'] = '档位';
MIOT_TEXT_DICTIONARY['gear fan level'] = '风速档位';
MIOT_TEXT_DICTIONARY['stepless'] = '无级';
MIOT_TEXT_DICTIONARY['stepless fan level'] = '无级风速';
MIOT_TEXT_DICTIONARY['one key'] = '一键';
MIOT_TEXT_DICTIONARY['one key cycle'] = '一键循环';
MIOT_TEXT_DICTIONARY['one key back'] = '一键回位';
MIOT_TEXT_DICTIONARY['cycle'] = '循环';
MIOT_TEXT_DICTIONARY['ultra violet light'] = '紫外灯';
MIOT_TEXT_DICTIONARY['ultraviolet light'] = '紫外灯';
MIOT_TEXT_DICTIONARY['uv light'] = '紫外灯';
MIOT_TEXT_DICTIONARY['mosquito'] = '灭蚊';
MIOT_TEXT_DICTIONARY['mosquito repellent'] = '驱蚊';
MIOT_TEXT_DICTIONARY['repellent'] = '驱蚊';
MIOT_TEXT_DICTIONARY['negative ion'] = '负离子';
MIOT_TEXT_DICTIONARY['anion'] = '负离子';
MIOT_TEXT_DICTIONARY['dry'] = '除湿';
MIOT_TEXT_DICTIONARY['aux heating'] = '电辅热';
MIOT_TEXT_DICTIONARY['auxiliary heating'] = '电辅热';
MIOT_TEXT_DICTIONARY['screen'] = '屏显';
MIOT_TEXT_DICTIONARY['screen display'] = '屏显';
MIOT_TEXT_DICTIONARY['display'] = '显示';
MIOT_TEXT_DICTIONARY['sound'] = '声音';
MIOT_TEXT_DICTIONARY['beep'] = '提示音';
MIOT_TEXT_DICTIONARY['buzzer'] = '提示音';
MIOT_TEXT_DICTIONARY['physical control locked'] = '童锁';
MIOT_TEXT_DICTIONARY['physical controls locked'] = '童锁';
MIOT_TEXT_DICTIONARY['horizontal angle'] = '水平角度';
MIOT_TEXT_DICTIONARY['vertical angle'] = '垂直角度';

// —— 红外遥控虚拟设备（miir.*） ——
MIOT_TEXT_DICTIONARY['mode for ir'] = '模式';
MIOT_TEXT_DICTIONARY['temperature for ir'] = '设定温度';
MIOT_TEXT_DICTIONARY['ir fan control'] = '红外风扇控制';
MIOT_TEXT_DICTIONARY['ir aircondition control'] = '红外空调控制';
MIOT_TEXT_DICTIONARY['fan speed up'] = '风速+';
MIOT_TEXT_DICTIONARY['fan speed down'] = '风速-';
MIOT_TEXT_DICTIONARY['temperature up'] = '温度+';
MIOT_TEXT_DICTIONARY['temperature down'] = '温度-';
MIOT_TEXT_DICTIONARY['horizontal swing on'] = '开启摆风';
MIOT_TEXT_DICTIONARY['horizontal swing off'] = '关闭摆风';

// —— 领普/储运插座（cuco.plug）等私有服务 ——
MIOT_TEXT_DICTIONARY['quick countdown'] = '快速倒计时';
MIOT_TEXT_DICTIONARY['charging protection'] = '充电保护';
MIOT_TEXT_DICTIONARY['max power limit'] = '功率上限';
MIOT_TEXT_DICTIONARY['power limit'] = '功率上限';
MIOT_TEXT_DICTIONARY['power ext'] = '功率扩展';
MIOT_TEXT_DICTIONARY['over use ele alert'] = '超额用电提醒';
MIOT_TEXT_DICTIONARY['over ele day'] = '日超额电量';
MIOT_TEXT_DICTIONARY['over ele month'] = '月超额电量';
MIOT_TEXT_DICTIONARY['on off count'] = '开关次数';
MIOT_TEXT_DICTIONARY['default power on state'] = '上电默认状态';
MIOT_TEXT_DICTIONARY['left time'] = '剩余时长';
MIOT_TEXT_DICTIONARY['protect time'] = '保护时长';
MIOT_TEXT_DICTIONARY['data value'] = '数值';
MIOT_TEXT_DICTIONARY['charge prt ext'] = '充电保护扩展';
MIOT_TEXT_DICTIONARY['power limit ext'] = '功率上限扩展';
MIOT_TEXT_DICTIONARY['tvoc'] = 'TVOC';
MIOT_TEXT_DICTIONARY['formaldehyde'] = '甲醛';
MIOT_TEXT_DICTIONARY['co2'] = 'CO2';
MIOT_TEXT_DICTIONARY['negative ion'] = '负离子';
MIOT_TEXT_DICTIONARY['germicidal'] = '杀菌';
MIOT_TEXT_DICTIONARY['deodorization'] = '除味';
MIOT_TEXT_DICTIONARY['dust'] = '灰尘';
MIOT_TEXT_DICTIONARY['odor'] = '异味';
MIOT_TEXT_DICTIONARY['allergen'] = '过敏原';
MIOT_TEXT_DICTIONARY['pollution'] = '污染';
MIOT_TEXT_DICTIONARY['clean'] = '清洁';
MIOT_TEXT_DICTIONARY['filter replacement'] = '更换滤芯';
MIOT_TEXT_DICTIONARY['motor speed'] = '电机转速';
MIOT_TEXT_DICTIONARY['filter reminder'] = '滤芯提醒';
MIOT_TEXT_DICTIONARY['indoor temperature'] = '室内温度';
MIOT_TEXT_DICTIONARY['outdoor temperature'] = '室外温度';
MIOT_TEXT_DICTIONARY['charging'] = '充电中';
MIOT_TEXT_DICTIONARY['discharging'] = '放电中';
MIOT_TEXT_DICTIONARY['full'] = '已满';
MIOT_TEXT_DICTIONARY['empty'] = '空';
MIOT_TEXT_DICTIONARY['idle'] = '空闲';
MIOT_TEXT_DICTIONARY['running'] = '运行中';
MIOT_TEXT_DICTIONARY['paused'] = '已暂停';
MIOT_TEXT_DICTIONARY['stopped'] = '已停止';
MIOT_TEXT_DICTIONARY['working'] = '工作中';
MIOT_TEXT_DICTIONARY['online'] = '在线';
MIOT_TEXT_DICTIONARY['offline'] = '离线';
MIOT_TEXT_DICTIONARY['signal'] = '信号';
MIOT_TEXT_DICTIONARY['rssi'] = '信号强度';
MIOT_TEXT_DICTIONARY['network'] = '网络';
MIOT_TEXT_DICTIONARY['service'] = '服务';
MIOT_TEXT_DICTIONARY['maintenance'] = '维护';
MIOT_TEXT_DICTIONARY['fault'] = '故障';
MIOT_TEXT_DICTIONARY['error'] = '错误';
MIOT_TEXT_DICTIONARY['warning'] = '警告';
MIOT_TEXT_DICTIONARY['notification'] = '通知';
MIOT_TEXT_DICTIONARY['display'] = '显示';
MIOT_TEXT_DICTIONARY['screen'] = '屏幕';
MIOT_TEXT_DICTIONARY['backlight'] = '背光';
MIOT_TEXT_DICTIONARY['sound'] = '声音';
MIOT_TEXT_DICTIONARY['silent'] = '静音';
MIOT_TEXT_DICTIONARY['boost'] = '增强';
MIOT_TEXT_DICTIONARY['continuous'] = '连续';
MIOT_TEXT_DICTIONARY['intermittent'] = '间歇';
MIOT_TEXT_DICTIONARY['cycle mode'] = '循环模式';
MIOT_TEXT_DICTIONARY['constant temperature'] = '调节温度';
MIOT_TEXT_DICTIONARY['natural wind'] = '自然风';
MIOT_TEXT_DICTIONARY['warm'] = '暖风';
// 音箱播放控制
MIOT_TEXT_DICTIONARY['playing state'] = '播放状态';
MIOT_TEXT_DICTIONARY['play state'] = '播放状态';
MIOT_TEXT_DICTIONARY['playing'] = '播放中';
MIOT_TEXT_DICTIONARY['text content'] = '文本内容';
MIOT_TEXT_DICTIONARY['silent execution'] = '静默执行';
MIOT_TEXT_DICTIONARY['seek time'] = '跳转时间';
MIOT_TEXT_DICTIONARY['seek'] = '跳转';
MIOT_TEXT_DICTIONARY['play loop mode'] = '播放循环模式';
MIOT_TEXT_DICTIONARY['loop mode'] = '循环模式';
MIOT_TEXT_DICTIONARY['single cycle'] = '单曲循环';
MIOT_TEXT_DICTIONARY['wake up'] = '唤醒';
MIOT_TEXT_DICTIONARY['play radio'] = '播放电台';
MIOT_TEXT_DICTIONARY['play fm'] = '播放 FM';
MIOT_TEXT_DICTIONARY['play text'] = '播放文本';
MIOT_TEXT_DICTIONARY['play music'] = '播放音乐';
MIOT_TEXT_DICTIONARY['execute text directive'] = '执行文本指令';
MIOT_TEXT_DICTIONARY['stop alarm'] = '停止闹钟';
MIOT_TEXT_DICTIONARY['text'] = '文本';
MIOT_TEXT_DICTIONARY['radio'] = '电台';
MIOT_TEXT_DICTIONARY['fm'] = 'FM';
MIOT_TEXT_DICTIONARY['music'] = '音乐';
// 麦克风（与扬声器静音区分）
MIOT_TEXT_DICTIONARY['microphone'] = '麦克风';
MIOT_TEXT_DICTIONARY['mic'] = '麦克风';
MIOT_TEXT_DICTIONARY['microphone mute'] = '禁用麦克风';
MIOT_TEXT_DICTIONARY['mute microphone'] = '禁用麦克风';
MIOT_TEXT_DICTIONARY['mic mute'] = '禁用麦克风';
MIOT_TEXT_DICTIONARY['mute mic'] = '禁用麦克风';
// 音箱其他属性/按钮
MIOT_TEXT_DICTIONARY['device fault'] = '设备故障';
MIOT_TEXT_DICTIONARY['no faults'] = '无故障';
MIOT_TEXT_DICTIONARY['ringtone'] = '铃声';
MIOT_TEXT_DICTIONARY['busy'] = '忙碌';
MIOT_TEXT_DICTIONARY['tv-switchon'] = '打开电视';
MIOT_TEXT_DICTIONARY['tv switch'] = '电视开关';
// 热水器/燃气热水器相关
MIOT_TEXT_DICTIONARY['water temperature'] = '水温';
MIOT_TEXT_DICTIONARY['target water temperature'] = '目标水温';
MIOT_TEXT_DICTIONARY['inlet water temperature'] = '进水温度';
MIOT_TEXT_DICTIONARY['outlet water temperature'] = '出水温度';
MIOT_TEXT_DICTIONARY['water'] = '水';
MIOT_TEXT_DICTIONARY['inlet'] = '进水';
MIOT_TEXT_DICTIONARY['outlet'] = '出水';
MIOT_TEXT_DICTIONARY['heating state'] = '加热状态';
MIOT_TEXT_DICTIONARY['heating'] = '加热';
MIOT_TEXT_DICTIONARY['gas leakage'] = '燃气泄漏';
MIOT_TEXT_DICTIONARY['gas valve'] = '燃气阀';
MIOT_TEXT_DICTIONARY['anti-freeze'] = '防冻';
MIOT_TEXT_DICTIONARY['anti-freezing'] = '防冻';
MIOT_TEXT_DICTIONARY['smart anti-freeze'] = '智能防冻';
MIOT_TEXT_DICTIONARY['zero cold water'] = '零冷水';
MIOT_TEXT_DICTIONARY['circulation'] = '循环';
MIOT_TEXT_DICTIONARY['circulation pump'] = '循环泵';
MIOT_TEXT_DICTIONARY['bath mode'] = '沐浴模式';
MIOT_TEXT_DICTIONARY['shower'] = '淋浴';
MIOT_TEXT_DICTIONARY['winter mode'] = '冬季模式';
MIOT_TEXT_DICTIONARY['summer mode'] = '夏季模式';
MIOT_TEXT_DICTIONARY['hot water'] = '热水';
MIOT_TEXT_DICTIONARY['cold water'] = '冷水';
MIOT_TEXT_DICTIONARY['warm water'] = '温水';
MIOT_TEXT_DICTIONARY['water flow'] = '水流';
MIOT_TEXT_DICTIONARY['water yield'] = '出水量';
MIOT_TEXT_DICTIONARY['combustion'] = '燃烧';
MIOT_TEXT_DICTIONARY['preheating'] = '预热';
MIOT_TEXT_DICTIONARY['temperature setting'] = '温度设置';
MIOT_TEXT_DICTIONARY['flame failure'] = '熄火';
MIOT_TEXT_DICTIONARY['exhaust failure'] = '排烟故障';
MIOT_TEXT_DICTIONARY['overheat protection'] = '过热保护';
MIOT_TEXT_DICTIONARY['dry burning protection'] = '防干烧';
MIOT_TEXT_DICTIONARY['anti-dry'] = '防干烧';
MIOT_TEXT_DICTIONARY['water pressure'] = '水压';
MIOT_TEXT_DICTIONARY['low water pressure'] = '低水压';
MIOT_TEXT_DICTIONARY['ignition'] = '点火';
MIOT_TEXT_DICTIONARY['thermal efficiency'] = '热效率';
MIOT_TEXT_DICTIONARY['efficiency'] = '效率';
MIOT_TEXT_DICTIONARY['heat exchange'] = '换热';
MIOT_TEXT_DICTIONARY['residual water'] = '余水';
MIOT_TEXT_DICTIONARY['drainage'] = '排水';
MIOT_TEXT_DICTIONARY['fault code'] = '故障代码';
MIOT_TEXT_DICTIONARY['alarm state'] = '告警状态';
MIOT_TEXT_DICTIONARY['protection state'] = '保护状态';
// 通用补充
MIOT_TEXT_DICTIONARY['air'] = '空气';
MIOT_TEXT_DICTIONARY['indoor'] = '室内';
MIOT_TEXT_DICTIONARY['outdoor'] = '室外';
MIOT_TEXT_DICTIONARY['target'] = '目标';
MIOT_TEXT_DICTIONARY['display brightness'] = '显示亮度';
MIOT_TEXT_DICTIONARY['screen brightness'] = '屏幕亮度';
MIOT_TEXT_DICTIONARY['backlight brightness'] = '背光亮度';
MIOT_TEXT_DICTIONARY['led brightness'] = '指示灯亮度';
MIOT_TEXT_DICTIONARY['indicator brightness'] = '指示灯亮度';
MIOT_TEXT_DICTIONARY['fan speed level'] = '风速档位';
MIOT_TEXT_DICTIONARY['air volume level'] = '风量档位';
MIOT_TEXT_DICTIONARY['temperature unit'] = '温度单位';
MIOT_TEXT_DICTIONARY['eco mode'] = '节能模式';
MIOT_TEXT_DICTIONARY['comfort mode'] = '舒适模式';
MIOT_TEXT_DICTIONARY['smart mode'] = '智能模式';
MIOT_TEXT_DICTIONARY['manual mode'] = '手动模式';
MIOT_TEXT_DICTIONARY['language'] = '语言';
MIOT_TEXT_DICTIONARY['on delay'] = '开启延时';
MIOT_TEXT_DICTIONARY['off delay'] = '关闭延时';
MIOT_TEXT_DICTIONARY['remain time'] = '剩余时间';
MIOT_TEXT_DICTIONARY['remaining'] = '剩余';
MIOT_TEXT_DICTIONARY['minute'] = '分钟';
MIOT_TEXT_DICTIONARY['hour'] = '小时';
MIOT_TEXT_DICTIONARY['second'] = '秒';
MIOT_TEXT_DICTIONARY['realtime'] = '实时';
MIOT_TEXT_DICTIONARY['real-time'] = '实时';
// 补充常用词条
MIOT_TEXT_DICTIONARY['celsius'] = '摄氏度';
MIOT_TEXT_DICTIONARY['fahrenheit'] = '华氏度';
MIOT_TEXT_DICTIONARY['motion'] = '移动';
MIOT_TEXT_DICTIONARY['motion detected'] = '检测到移动';
MIOT_TEXT_DICTIONARY['presence'] = '人体存在';
MIOT_TEXT_DICTIONARY['occupied'] = '有人';
MIOT_TEXT_DICTIONARY['unoccupied'] = '无人';
MIOT_TEXT_DICTIONARY['illuminance'] = '光照度';
MIOT_TEXT_DICTIONARY['lux'] = '光照度';
MIOT_TEXT_DICTIONARY['light intensity'] = '光照强度';
MIOT_TEXT_DICTIONARY['door'] = '门';
MIOT_TEXT_DICTIONARY['door state'] = '门窗状态';
MIOT_TEXT_DICTIONARY['open state'] = '开启状态';
MIOT_TEXT_DICTIONARY['water shortage'] = '缺水';
MIOT_TEXT_DICTIONARY['water level'] = '水位';
MIOT_TEXT_DICTIONARY['water tank'] = '水箱';
MIOT_TEXT_DICTIONARY['tank full'] = '水箱已满';
MIOT_TEXT_DICTIONARY['dust box'] = '尘盒';
MIOT_TEXT_DICTIONARY['dust bag'] = '尘袋';
MIOT_TEXT_DICTIONARY['side brush'] = '边刷';
MIOT_TEXT_DICTIONARY['main brush'] = '主刷';
MIOT_TEXT_DICTIONARY['roller brush'] = '滚刷';
MIOT_TEXT_DICTIONARY['suction power'] = '吸力';
MIOT_TEXT_DICTIONARY['cleaning area'] = '清扫面积';
MIOT_TEXT_DICTIONARY['cleaning count'] = '清扫次数';
MIOT_TEXT_DICTIONARY['cleaning time'] = '清扫时长';
MIOT_TEXT_DICTIONARY['total cleaning time'] = '总清扫时长';
MIOT_TEXT_DICTIONARY['scheduled clean'] = '定时清扫';
MIOT_TEXT_DICTIONARY['continue cleaning'] = '继续清扫';
MIOT_TEXT_DICTIONARY['clean now'] = '立即清扫';
MIOT_TEXT_DICTIONARY['sweep and mop'] = '扫拖一体';
MIOT_TEXT_DICTIONARY['mop only'] = '仅拖地';
MIOT_TEXT_DICTIONARY['sweep only'] = '仅扫地';
MIOT_TEXT_DICTIONARY['dock'] = '回充';
MIOT_TEXT_DICTIONARY['return to charge'] = '返回充电';
MIOT_TEXT_DICTIONARY['find robot'] = '查找机器人';
MIOT_TEXT_DICTIONARY['abnormal'] = '异常';
MIOT_TEXT_DICTIONARY['firmware version'] = '固件版本';
MIOT_TEXT_DICTIONARY['serial number'] = '序列号';
MIOT_TEXT_DICTIONARY['connection'] = '连接';
MIOT_TEXT_DICTIONARY['connection status'] = '连接状态';
MIOT_TEXT_DICTIONARY['signal strength'] = '信号强度';
MIOT_TEXT_DICTIONARY['ip address'] = 'IP 地址';
MIOT_TEXT_DICTIONARY['mac address'] = 'MAC 地址';
MIOT_TEXT_DICTIONARY['cloud'] = '云端';
MIOT_TEXT_DICTIONARY['local'] = '本地';
MIOT_TEXT_DICTIONARY['away'] = '离家';
MIOT_TEXT_DICTIONARY['home'] = '在家';
MIOT_TEXT_DICTIONARY['trigger'] = '触发';
MIOT_TEXT_DICTIONARY['condition'] = '条件';
MIOT_TEXT_DICTIONARY['action'] = '动作';
MIOT_TEXT_DICTIONARY['delay'] = '延时';
MIOT_TEXT_DICTIONARY['on time'] = '开机时长';
MIOT_TEXT_DICTIONARY['off time'] = '关机时长';
MIOT_TEXT_DICTIONARY['electric kettle'] = '电水壶';
MIOT_TEXT_DICTIONARY['rice cooker'] = '电饭煲';
MIOT_TEXT_DICTIONARY['air fryer'] = '空气炸锅';
MIOT_TEXT_DICTIONARY['refrigerator'] = '冰箱';
MIOT_TEXT_DICTIONARY['washing machine'] = '洗衣机';
MIOT_TEXT_DICTIONARY['dishwasher'] = '洗碗机';
MIOT_TEXT_DICTIONARY['camera'] = '摄像头';
MIOT_TEXT_DICTIONARY['door lock'] = '门锁';
MIOT_TEXT_DICTIONARY['last seen'] = '最后在线时间';

/**
 * 服务类型（service.type 最后一段）→ 中文功能/设备名。
 * 用于给“on/off/switch”这类通用布尔属性提供明确的上下文标签，
 * 避免多个不同功能都显示为“开”。
 */
const SERVICE_LABEL_DICTIONARY: Record<string, string> = {
  // 基础/通用
  'power': '电源',
  'switch': '开关',
  'light': '灯光',
  'lamp': '灯',
  'main-light': '主灯',
  'ambient-light': '氛围灯',
  'warm-light': '暖光灯',
  'cool-light': '冷光灯',
  'color-light': '彩灯',
  'night-light': '夜灯',
  'indicator-light': '指示灯',
  'led': '指示灯',
  'backlight': '背光',
  'display': '显示屏',
  'screen': '屏幕',
  'mute': '静音',
  'microphone': '麦克风',
  'mic': '麦克风',
  'buzzer': '提示音',
  'alarm': '告警',
  'siren': '警报器',
  'lock': '锁定',
  'child-lock': '童锁',
  'physical-control-locked': '物理按钮锁',
  'standby': '待机',
  'sleep': '睡眠',
  'eco': '节能',
  'energy-saving': '节能',
  'boost': '增强',
  'turbo': '强力',
  'timer': '定时',
  'delay-off': '延时关闭',
  'auto-off': '自动关机',
  'auto-on': '自动开机',
  'reminder': '提醒',
  'privacy': '隐私保护',
  // 温湿度/环境传感
  'temperature': '温度',
  'humidity': '湿度',
  'temperature-humidity-sensor': '温湿度计',
  'temperature-sensor': '温度计',
  'humidity-sensor': '湿度计',
  'environment-sensor': '环境传感器',
  'air-quality-sensor': '空气质量传感器',
  'motion-sensor': '人体传感器',
  'presence-sensor': '人体传感器',
  'door-sensor': '门窗传感器',
  'water-leak-sensor': '水浸传感器',
  'smoke-sensor': '烟雾传感器',
  'gas-sensor': '燃气传感器',
  'sensor': '传感器',
  // 家电/厨卫
  'air-conditioner': '空调',
  'air-purifier': '空气净化器',
  'purifier': '净化器',
  'humidifier': '加湿器',
  'dehumidifier': '除湿机',
  'heater': '取暖器',
  'water-heater': '热水器',
  'electric-kettle': '电水壶',
  'kettle': '电水壶',
  'coffee-maker': '咖啡机',
  'rice-cooker': '电饭煲',
  'cooker': '电饭煲',
  'induction-cooker': '电磁炉',
  'microwave': '微波炉',
  'oven': '烤箱',
  'air-fryer': '空气炸锅',
  'fridge': '冰箱',
  'refrigerator': '冰箱',
  'washer': '洗衣机',
  'dryer': '烘干机',
  'dishwasher': '洗碗机',
  'fan': '风扇',
  'curtain': '窗帘',
  'window-opener': '开窗器',
  'garage-door': '车库门',
  'door-lock': '门锁',
  'camera': '摄像头',
  'speaker': '音箱',
  'sound-box': '音箱',
  'tv': '电视',
  'projector': '投影仪',
  'monitor': '显示器',
  'set-top-box': '机顶盒',
  'router': '路由器',
  'socket': '插座',
  'power-strip': '插线板',
  'battery': '电池',
  'charger': '充电器',
  'vacuum': '吸尘器',
  'robot-vacuum': '扫地机器人',
  'mop': '拖地机器人',
  'pet-feeder': '宠物喂食器',
  'fish-tank': '鱼缸',
  'aquarium': '鱼缸',
  'massager': '按摩器',
  'water-pump': '水泵',
  'sprinkler': '洒水器',
  // 热水器功能
  'anti-freeze': '防冻',
  'anti-freezing': '防冻',
  'circulation': '循环',
  'circulation-pump': '循环泵',
  'zero-cold-water': '零冷水',
  'heating': '加热',
  'preheating': '预热',
  'heat-exchange': '换热',
  'combustion': '燃烧',
  'ignition': '点火',
  'drainage': '排水',
  // 净化/消毒
  'purify': '净化',
  'sterilize': '杀菌',
  'sterilization': '杀菌',
  'ion': '负离子',
  'negative-ion': '负离子',
  'anion': '负离子',
  'plasma': '等离子',
  'uv': '紫外线',
  'deodorization': '除味',
  // 洗涤/烘干
  'drying': '烘干',
  'washing': '洗涤',
  'quick-wash': '快洗',
  // 影音
  'volume': '音量',
  'channel': '频道',
  'input-source': '信号源',
  'picture-mode': '图像模式',
  'sound-mode': '音效模式',
  'screen-mirroring': '投屏'
};

/**
 * 服务类型 → 布尔“开关类”属性的展示标签。
 * 命中的服务在渲染 on/off/switch 属性时直接使用该标签，
 * 不再退化为通用的“开/关”。
 */
const SERVICE_BOOL_LABELS: Record<string, string> = {
  'power': '电源开关',
  'switch': '开关',
  'light': '灯光开关',
  'lamp': '灯',
  'main-light': '主灯开关',
  'ambient-light': '氛围灯开关',
  'warm-light': '暖光',
  'cool-light': '冷光',
  'color-light': '彩灯开关',
  'night-light': '夜灯',
  'indicator-light': '指示灯',
  'led': '指示灯',
  'backlight': '背光',
  'display': '显示屏',
  'screen': '屏幕',
  'mute': '静音',
  'microphone': '禁用麦克风',
  'mic': '禁用麦克风',
  'buzzer': '提示音',
  'alarm': '告警',
  'siren': '警报',
  'lock': '锁定',
  'child-lock': '童锁',
  'physical-control-locked': '物理按钮锁',
  'standby': '待机',
  'sleep': '睡眠模式',
  'eco': '节能',
  'energy-saving': '节能',
  'boost': '增强',
  'turbo': '强力',
  'timer': '定时',
  'delay-off': '延时关闭',
  'auto-off': '自动关机',
  'auto-on': '自动开机',
  'reminder': '提醒',
  'privacy': '隐私保护',
  'anti-freeze': '防冻',
  'anti-freezing': '防冻',
  'circulation': '循环',
  'circulation-pump': '循环泵',
  'zero-cold-water': '零冷水',
  'heating': '加热',
  'preheating': '预热',
  'drainage': '排水',
  'ignition': '点火',
  'combustion': '燃烧',
  'purify': '净化',
  'sterilize': '杀菌',
  'sterilization': '杀菌',
  'ion': '负离子',
  'negative-ion': '负离子',
  'anion': '负离子',
  'plasma': '等离子',
  'uv': '紫外线',
  'deodorization': '除味',
  'drying': '烘干',
  'washing': '洗涤',
  'quick-wash': '快洗',
  'screen-mirroring': '投屏',
  'water-pump': '水泵',
  'sprinkler': '洒水',
  'recording': '录像',
  'patrol': '巡航',
  'follow': '跟随',
  'tracking': '跟踪',
  'motion': '移动侦测',
  'pir': '人体感应',
  'presence': '人体感应'
};

// 设备通用词条补充（按设备/功能分类）
MIOT_TEXT_DICTIONARY['water level'] = '水位';
MIOT_TEXT_DICTIONARY['target humidity'] = '目标湿度';
MIOT_TEXT_DICTIONARY['target brightness'] = '目标亮度';
MIOT_TEXT_DICTIONARY['target color temperature'] = '目标色温';
MIOT_TEXT_DICTIONARY['wind speed'] = '风速';
MIOT_TEXT_DICTIONARY['wind level'] = '风速档位';
MIOT_TEXT_DICTIONARY['away mode'] = '离家模式';
MIOT_TEXT_DICTIONARY['home mode'] = '在家模式';
MIOT_TEXT_DICTIONARY['holiday mode'] = '假日模式';
MIOT_TEXT_DICTIONARY['vacation mode'] = '度假模式';
MIOT_TEXT_DICTIONARY['smart scene'] = '智能场景';
MIOT_TEXT_DICTIONARY['temperature alarm'] = '温度告警';
MIOT_TEXT_DICTIONARY['high temperature'] = '高温';
MIOT_TEXT_DICTIONARY['low temperature'] = '低温';
MIOT_TEXT_DICTIONARY['defrost'] = '除霜';
MIOT_TEXT_DICTIONARY['defrosting'] = '除霜';
MIOT_TEXT_DICTIONARY['refrigeration'] = '制冷';
MIOT_TEXT_DICTIONARY['freezer'] = '冷冻';
MIOT_TEXT_DICTIONARY['ice making'] = '制冰';
MIOT_TEXT_DICTIONARY['water tank'] = '水箱';
MIOT_TEXT_DICTIONARY['clean water tank'] = '清水箱';
MIOT_TEXT_DICTIONARY['waste water tank'] = '污水箱';
MIOT_TEXT_DICTIONARY['dust collection'] = '集尘';
MIOT_TEXT_DICTIONARY['auto mop'] = '自动拖地';
MIOT_TEXT_DICTIONARY['carpet boost'] = '地毯增压';
MIOT_TEXT_DICTIONARY['edge cleaning'] = '边角清洁';
MIOT_TEXT_DICTIONARY['carpet detection'] = '地毯检测';
MIOT_TEXT_DICTIONARY['cliff sensor'] = '悬崖传感器';
MIOT_TEXT_DICTIONARY['drop sensor'] = '防跌落';
MIOT_TEXT_DICTIONARY['obstacle avoidance'] = '避障';
MIOT_TEXT_DICTIONARY['cleaning mode'] = '清洁模式';
MIOT_TEXT_DICTIONARY['sweep mode'] = '扫地模式';
MIOT_TEXT_DICTIONARY['mop mode'] = '拖地模式';
MIOT_TEXT_DICTIONARY['suction'] = '吸力';
MIOT_TEXT_DICTIONARY['suction level'] = '吸力档位';
MIOT_TEXT_DICTIONARY['suction power'] = '吸力';
MIOT_TEXT_DICTIONARY['water volume'] = '水量';
MIOT_TEXT_DICTIONARY['steam'] = '蒸汽';
MIOT_TEXT_DICTIONARY['steam level'] = '蒸汽档位';
MIOT_TEXT_DICTIONARY['spin'] = '脱水';
MIOT_TEXT_DICTIONARY['spin speed'] = '脱水转速';
MIOT_TEXT_DICTIONARY['spin level'] = '脱水档位';
MIOT_TEXT_DICTIONARY['rinse'] = '漂洗';
MIOT_TEXT_DICTIONARY['rinse level'] = '漂洗次数';
MIOT_TEXT_DICTIONARY['wash mode'] = '洗涤模式';
MIOT_TEXT_DICTIONARY['wash program'] = '洗涤程序';
MIOT_TEXT_DICTIONARY['soak'] = '浸泡';
MIOT_TEXT_DICTIONARY['pre-wash'] = '预洗';
MIOT_TEXT_DICTIONARY['temperature protection'] = '温度保护';
MIOT_TEXT_DICTIONARY['overheating'] = '过热';
MIOT_TEXT_DICTIONARY['overheat'] = '过热';
MIOT_TEXT_DICTIONARY['anti-dry-burning'] = '防干烧';
MIOT_TEXT_DICTIONARY['leakage protection'] = '漏电保护';
MIOT_TEXT_DICTIONARY['overload protection'] = '过载保护';
MIOT_TEXT_DICTIONARY['short circuit'] = '短路';
MIOT_TEXT_DICTIONARY['power failure'] = '断电';
MIOT_TEXT_DICTIONARY['power recovery'] = '来电恢复';
MIOT_TEXT_DICTIONARY['memory state'] = '记忆状态';
MIOT_TEXT_DICTIONARY['last state'] = '上次状态';
MIOT_TEXT_DICTIONARY['filter life percent'] = '滤芯寿命';
MIOT_TEXT_DICTIONARY['filter used days'] = '滤芯已用天数';
MIOT_TEXT_DICTIONARY['filter remaining'] = '滤芯剩余';
MIOT_TEXT_DICTIONARY['connection state'] = '连接状态';
MIOT_TEXT_DICTIONARY['connection status'] = '连接状态';
MIOT_TEXT_DICTIONARY['gateway'] = '网关';
MIOT_TEXT_DICTIONARY['hub'] = '网关';
MIOT_TEXT_DICTIONARY['distance'] = '距离';
MIOT_TEXT_DICTIONARY['temperature difference'] = '温差';
MIOT_TEXT_DICTIONARY['temperature offset'] = '温度补偿';
MIOT_TEXT_DICTIONARY['calibration'] = '校准';
MIOT_TEXT_DICTIONARY['accuracy'] = '精度';
MIOT_TEXT_DICTIONARY['sleep time'] = '睡眠时间';
MIOT_TEXT_DICTIONARY['awake time'] = '唤醒时间';
MIOT_TEXT_DICTIONARY['do not disturb'] = '勿扰模式';
MIOT_TEXT_DICTIONARY['dnd'] = '勿扰模式';
MIOT_TEXT_DICTIONARY['volume level'] = '音量档位';
MIOT_TEXT_DICTIONARY['media volume'] = '媒体音量';
MIOT_TEXT_DICTIONARY['ring volume'] = '铃声音量';
MIOT_TEXT_DICTIONARY['alarm volume'] = '闹钟音量';
MIOT_TEXT_DICTIONARY['wifi'] = 'WiFi';
MIOT_TEXT_DICTIONARY['bluetooth'] = '蓝牙';
MIOT_TEXT_DICTIONARY['zigbee'] = 'Zigbee';
MIOT_TEXT_DICTIONARY['time'] = '时间';
MIOT_TEXT_DICTIONARY['date'] = '日期';

const GENERIC_ON_OFF_DESCRIPTIONS: string[] = [
  'on', 'off', 'switch', 'power', 'enabled', 'disabled', 'standby',
  'mute', 'lock', 'unlock', 'alarm', 'status', 'state'
];

function serviceKeyOf(service: MIoTSpecService): string {
  const raw = service.type.trim().toLowerCase();
  const parts = raw.split(':');
  // 标准格式: urn:<spec>:service:<name>:<siid>:<vendor>:<version>[:proprietary]
  // 服务名固定是第 4 段，最后一段是编号/厂商信息，不能当作服务名。
  if (parts.length >= 4 && parts[2] === 'service') {
    return parts[3].replace(/\s+/g, '-');
  }
  const last = parts.length > 0 ? parts[parts.length - 1] : raw;
  return last.replace(/\s+/g, '-');
}

function isGenericOnOff(description: string): boolean {
  const key = description.trim().toLowerCase();
  return GENERIC_ON_OFF_DESCRIPTIONS.indexOf(key) >= 0;
}

/**
 * 设备 spec 中混入的无意义 proprietary 服务：
 * 时间戳/历史记录、重复的温湿度历史数据等，用户界面无需展示。
 */
const HIDDEN_SERVICE_KEYS: string[] = [
  'history-time',
  'history-time-ble',
  'custom-environment'
];

function isHiddenService(service: MIoTSpecService): boolean {
  const key = serviceKeyOf(service);
  return HIDDEN_SERVICE_KEYS.indexOf(key) >= 0;
}

/**
 * 上下文感知标签：
 * 1. 布尔开关类属性 → 优先使用服务功能名（童锁/加热/防冻…），避免多个“开”；
 * 2. 已知服务 + 通用开关属性 → “功能名+开关”；
 * 3. 其余走通用字典翻译。
 */
function resolveLabel(service: MIoTSpecService, description: string, isBool: boolean, serviceDisplayName?: string): string {
  const serviceKey = serviceKeyOf(service);
  if (isBool && isGenericOnOff(description)) {
    if (serviceDisplayName !== undefined && serviceDisplayName.length > 0) {
      return serviceDisplayName;
    }
    const boolLabel = SERVICE_BOOL_LABELS[serviceKey];
    if (boolLabel !== undefined) {
      return boolLabel;
    }
    const serviceName = SERVICE_LABEL_DICTIONARY[serviceKey];
    if (serviceName !== undefined) {
      return `${serviceName}开关`;
    }
    // 服务词典查不到（小众/私有服务）时，用服务描述/服务名区分，
    // 避免同一设备多个服务的开关全部显示为重复的「开关/开」。
    // 依次尝试候选文本，翻译结果仍是通用词（开关/开/switch…）时继续找下一个。
    const nameText = service.name.replace(/-/g, ' ').trim();
    const candidates: string[] = [];
    if (service.description.trim().length > 0) {
      candidates.push(service.description.trim());
    }
    if (nameText.length > 0 && candidates.indexOf(nameText) < 0) {
      candidates.push(nameText);
    }
    for (let i = 0; i < candidates.length; i++) {
      const translated = translateMiotText(candidates[i]);
      if (translated.length > 0 && !isGenericOnOff(translated) && translated !== '开关') {
        return `${translated}开关`;
      }
    }
  }
  return translateMiotText(description);
}

/**
 * 通用动作名：spec 中不同服务都有 “toggle” 等动作，翻译后全是“切换”，
 * 用户无法分辨是哪个功能，需要像 resolveLabel 一样补上服务上下文，
 * 例如 “灯光·切换”“童锁·切换”。
 */
const GENERIC_ACTION_LABELS: string[] = [
  'toggle', 'switch', '切换', '开关', '开', '关'
];

function resolveActionLabel(service: MIoTSpecService, action: MIoTSpecAction, serviceDisplayName?: string): string {
  const raw = action.description.trim().length > 0 ? action.description : action.name;
  const label = translateMiotText(raw);
  if (GENERIC_ACTION_LABELS.indexOf(label.trim()) < 0) {
    return label;
  }
  const serviceName = serviceDisplayName !== undefined && serviceDisplayName.length > 0
    ? serviceDisplayName
    : SERVICE_LABEL_DICTIONARY[serviceKeyOf(service)];
  return serviceName === undefined ? label : `${serviceName}·${label}`;
}

/**
 * 多实例服务消歧：排插多路插孔、多键墙开等设备的 spec 会有多个同名服务
 * （URN 服务名相同、仅 siid 不同），直接翻译会出现一排完全一样的
 * “开关 / 开关·切换”。统计同名服务数量，为多实例服务生成带编号的显示名
 * （开关1、开关2…），单实例服务保持原样。
 */
export function resolveServiceDisplayNames(services: MIoTSpecService[]): Map<number, string> {
  const keyCounts = new Map<string, number>();
  for (let i = 0; i < services.length; i++) {
    if (isHiddenService(services[i])) {
      continue;
    }
    const key = serviceKeyOf(services[i]);
    keyCounts.set(key, (keyCounts.get(key) ?? 0) + 1);
  }
  const running = new Map<string, number>();
  const names = new Map<number, string>();
  for (let i = 0; i < services.length; i++) {
    const service = services[i];
    if (isHiddenService(service)) {
      continue;
    }
    const key = serviceKeyOf(service);
    if ((keyCounts.get(key) ?? 1) <= 1) {
      continue;
    }
    const index = (running.get(key) ?? 0) + 1;
    running.set(key, index);
    let baseName = SERVICE_LABEL_DICTIONARY[key];
    if (baseName === undefined) {
      const raw = service.description.trim().length > 0 ? service.description : service.name;
      baseName = translateMiotText(raw);
    }
    if (baseName.trim().length === 0) {
      continue;
    }
    names.set(service.iid, `${baseName}${index}`);
  }
  return names;
}

const MIOT_UNIT_DICTIONARY: Record<string, string> = {
  'celsius': '°C',
  'fahrenheit': '°F',
  'percent': '%',
  'percentage': '%',
  'watt': 'W',
  'kw': 'kW',
  'kwh': 'kWh',
  'volt': 'V',
  'ampere': 'A',
  'lux': 'lux',
  'ppm': 'ppm',
  'seconds': '秒',
  'minutes': '分钟',
  'hours': '小时',
  'mg/m3': 'mg/m³',
  'ug/m3': 'μg/m³',
  'db': 'dB',
  'hz': 'Hz',
  'ppb': 'ppb',
  'rpm': 'rpm',
  'mg': 'mg',
  'ug': 'μg'
};

/** 全局通用 MIoT 单位翻译 */
export function translateMiotUnit(input: string): string {
  if (input.length === 0) {
    return input;
  }
  const key = input.trim().toLowerCase();
  const translated = MIOT_UNIT_DICTIONARY[key];
  if (translated === undefined) {
    FeedbackLogService.recordOperation('TRANSLATE', `未翻译单位: ${input}`);
  }
  return translated === undefined ? input : translated;
}

function isDeviceInfoProperty(property: MIoTSpecProperty): boolean {
  const description = property.description.trim().toLowerCase();
  const hiddenDescriptions = [
    'device manufacturer',
    'device model',
    'device serial number',
    'device name',
    'current firmware version'
  ];
  for (let i = 0; i < hiddenDescriptions.length; i++) {
    if (description === hiddenDescriptions[i]) {
      return true;
    }
  }
  const type = property.type.toLowerCase();
  return type.includes('manufacturer') || type.includes('firmware') || type.includes('serial');
}

/**
 * 米家部分 proprietary 属性的 description 为空、name 只是服务编号占位符
 * （如 "1"/"2"），没有真实名称，这类属性没有可用的展示标签，直接跳过。
 */
function isNamelessProperty(property: MIoTSpecProperty): boolean {
  if (property.description.trim().length > 0) {
    return false;
  }
  const name = property.name.trim();
  if (name.length === 0) {
    return true;
  }
  return /^\d+$/.test(name);
}

// ==================== 常用 / 扩展属性分级 ====================
// 目标：详情页默认只展示原版米家明面功能（电源/模式/风速/扫风/定时/亮度等），
// 其余属性（角度、童锁、回正、厂商私有调试属性等）由页面收纳进「更多功能」折叠区。
// 分级依据是 miot-spec 标准 URN 的属性名（两种 spec 数据源均携带 URN），
// 不按设备品类配置，未知品类设备也能正确分级。

/** 可写属性白名单：米家明面上的常用控制 */
/** 可写属性白名单：米家明面上的常用控制（对齐原版：电源/模式/风速/扫风/定时/亮度/温度） */
const COMMON_CONTROL_KEYS: string[] = [
  'on',
  'mode',
  'fan-level',
  'horizontal-swing',
  'vertical-swing',
  'swing-mode',
  'off-delay-time',
  'brightness',
  'color-temperature',
  'target-temperature',
  'ir-mode',
  'ir-temperature',
  'volume',
  'mute'
];

/** 只读属性白名单：米家明面上的常用读数 */
const COMMON_READOUT_KEYS: string[] = [
  'temperature',
  'relative-humidity',
  'pm2-5-density',
  'battery-level',
  'power',
  'electric-power',
  'filter-life-level',
  'voltage',
  'current'
];

/** 属性 URN 末段名，如 urn:miot-spec-v2:property:fan-level:00000008:* → fan-level */
function propertyKeyOf(property: MIoTSpecProperty): string {
  const raw = property.type.trim().toLowerCase();
  const parts = raw.split(':');
  // 标准格式: urn:<spec>:property:<name>:<piid>:<vendor>:<version>
  if (parts.length >= 4 && parts[2] === 'property') {
    return parts[3].replace(/\s+/g, '-');
  }
  const last = parts.length > 0 ? parts[parts.length - 1] : raw;
  return last.replace(/\s+/g, '-');
}

/**
 * 判断属性是否属于米家明面的常用功能：
 * 1. 厂商私有属性一律视为扩展功能；
 * 2. 亮度/色温仅灯光类服务视为常用（风扇 LED 屏亮度等收进「更多功能」）；
 * 3. 其余可写属性按控制白名单，只读属性按读数白名单（含净水器 TDS 读数）；
 * 4. 不在白名单内的属性（角度/童锁/故障/文本输入等）进「更多功能」折叠区。
 */
export function isCommonProperty(service: MIoTSpecService, property: MIoTSpecProperty): boolean {
  const key = propertyKeyOf(property);
  // 主开关始终明面展示：部分设备（空调等）的电源属性挂在厂商私有服务里，
  // 不能因 proprietary 被折叠，否则明面只剩温度等数值、看不到开关状态。
  if (property.writable && key === 'on') {
    return true;
  }
  if (property.proprietary) {
    return false;
  }
  if (key === 'brightness' || key === 'color-temperature') {
    return serviceKeyOf(service).includes('light');
  }
  if (property.writable) {
    return COMMON_CONTROL_KEYS.indexOf(key) >= 0;
  }
  return COMMON_READOUT_KEYS.indexOf(key) >= 0 || key.includes('tds');
}

/**
 * 多主电源收敛：部分设备（排插多路、空调伴侣等）多个服务的开关都会命中
 * 电源样式（isPower），全部渲染成电源圆钮会让用户误以为有多个主开关。
 * 只保留 spec 声明顺序中的第一个为主电源并置顶，其余降级为普通开关卡片。
 */
export function markPrimaryPower(controls: PropertyControlDescriptor[]): void {
  let primaryIndex = -1;
  for (let i = 0; i < controls.length; i++) {
    if (controls[i].isPower) {
      if (primaryIndex < 0) {
        primaryIndex = i;
      } else {
        controls[i].isPower = false;
      }
    }
  }
  if (primaryIndex > 0) {
    const primary = controls[primaryIndex];
    controls.splice(primaryIndex, 1);
    controls.unshift(primary);
  }
}

/**
 * 设备级重名标签消歧：极端情况下多个不同服务的开关标签仍可能完全相同
 * （如厂商把所有私有服务的描述都写成 switch），为重复标签追加序号（·2/·3），
 * 保证用户能看出这是不同的控制。
 */
export function dedupeControlLabels(controls: PropertyControlDescriptor[]): void {
  const counts = new Map<string, number>();
  for (let i = 0; i < controls.length; i++) {
    const label = controls[i].label;
    counts.set(label, (counts.get(label) ?? 0) + 1);
  }
  const seen = new Map<string, number>();
  for (let i = 0; i < controls.length; i++) {
    const label = controls[i].label;
    if ((counts.get(label) ?? 0) <= 1) {
      continue;
    }
    const index = (seen.get(label) ?? 0) + 1;
    seen.set(label, index);
    if (index > 1) {
      controls[i].label = `${label}·${index}`;
    }
  }
}

export enum CapabilityControlType {
  TOGGLE = 'toggle',
  SLIDER = 'slider',
  SELECT = 'select',
  BUTTON = 'button',
  TEMPERATURE = 'temperature',
  VOLUME = 'volume',
  TEXT = 'text',
  READOUT = 'readout'
}

export interface PropertyControlDescriptor {
  siid: number;
  piid: number;
  type: CapabilityControlType;
  label: string;
  format: string;
  unit: string;
  min: number;
  max: number;
  step: number;
  options: string[];
  optionValues: Object[];
  readable: boolean;
  writable: boolean;
  /** 是否为设备主电源开关（用于决定是否渲染为圆形大按钮） */
  isPower: boolean;
  /** 是否为常用属性（米家明面功能）；false 时收纳进「更多功能」折叠区 */
  isCommon: boolean;
}

export interface ActionControlDescriptor {
  siid: number;
  aiid: number;
  type: CapabilityControlType;
  label: string;
  argumentPiids: number[];
  arguments: ActionArgumentDescriptor[];
}

export interface ActionArgumentDescriptor {
  piid: number;
  label: string;
  format: string;
  unit: string;
  min: number;
  max: number;
  step: number;
  options: string[];
  optionValues: Object[];
}

export function resolvePropertyControl(
  service: MIoTSpecService,
  property: MIoTSpecProperty,
  serviceDisplayName?: string
): PropertyControlDescriptor {
  const type = resolveControlType(property);
  const valueRange = property.valueRange;
  const options: string[] = [];
  const optionValues: Object[] = [];
  const propText = property.description.trim().length > 0 ? property.description : property.name;
  const isOnOff = isGenericOnOff(propText);
  const label = resolveLabel(service, propText, isOnOff, serviceDisplayName);
  const isPower = isPowerProperty(service, property, label);
  for (let i = 0; i < property.valueList.length; i++) {
    const itemText = property.valueList[i].description.trim().length > 0 ?
      property.valueList[i].description : property.valueList[i].name;
    options.push(translateMiotText(itemText));
    optionValues.push(property.valueList[i].value);
  }
  return {
    siid: service.iid,
    piid: property.iid,
    type: type,
    label: label,
    format: property.format,
    unit: translateMiotUnit(property.unit),
    min: valueRange === null ? 0 : valueRange.min,
    max: valueRange === null ? 100 : valueRange.max,
    step: valueRange === null ? 1 : valueRange.step,
    options: options,
    optionValues: optionValues,
    readable: property.readable,
    writable: property.writable,
    isPower: isPower,
    isCommon: isCommonProperty(service, property) || isPower
  };
}

/**
 * 判断属性是否为设备主电源开关。
 * 主电源开关属性在 MIoT 中通常命名为 power（或 on/off/switch 且服务为 power），
 * 标签兜底匹配“电源开关/开关”，指示灯、模式等其它开关不视为电源开关。
 */
function isPowerProperty(service: MIoTSpecService, property: MIoTSpecProperty, label: string): boolean {
  const rawName = property.name.trim().toLowerCase();
  if (rawName === 'power' || rawName === 'on' || rawName === 'off' || rawName === 'switch') {
    const serviceKey = serviceKeyOf(service);
    if (serviceKey === 'power' || serviceKey === 'switch' ||
      serviceKey.includes('power') || serviceKey.includes('switch')) {
      return true;
    }
  }
  return label === '电源开关' || label === '开关';
}

export function resolveActionControl(
  service: MIoTSpecService,
  action: MIoTSpecAction,
  serviceDisplayName?: string
): ActionControlDescriptor {
  const args: ActionArgumentDescriptor[] = [];
  for (let i = 0; i < action.inPiids.length; i++) {
    const piid = action.inPiids[i];
    const prop = findProperty(service, piid);
    if (prop === null) {
      continue;
    }
    const range = prop.valueRange;
    const options: string[] = [];
    const optionValues: Object[] = [];
    for (let j = 0; j < prop.valueList.length; j++) {
      const itemText = prop.valueList[j].description.trim().length > 0 ?
        prop.valueList[j].description : prop.valueList[j].name;
      options.push(translateMiotText(itemText));
      optionValues.push(prop.valueList[j].value);
    }
    const argText = prop.description.trim().length > 0 ? prop.description : prop.name;
    const isArgOnOff = isGenericOnOff(argText);
    args.push({
      piid: piid,
      label: resolveLabel(service, argText, isArgOnOff, serviceDisplayName),
      format: prop.format,
      unit: translateMiotUnit(prop.unit),
      min: range === null ? 0 : range.min,
      max: range === null ? 100 : range.max,
      step: range === null ? 1 : range.step,
      options: options,
      optionValues: optionValues
    });
  }
  return {
    siid: service.iid,
    aiid: action.iid,
    type: CapabilityControlType.BUTTON,
    label: resolveActionLabel(service, action, serviceDisplayName),
    argumentPiids: action.inPiids,
    arguments: args
  };
}

export function buildServiceControls(service: MIoTSpecService, displayNames?: Map<number, string>): PropertyControlDescriptor[] {
  const controls: PropertyControlDescriptor[] = [];
  if (isHiddenService(service)) {
    return controls;
  }
  const displayName = displayNames?.get(service.iid);
  for (let i = 0; i < service.properties.length; i++) {
    if (isDeviceInfoProperty(service.properties[i]) || isNamelessProperty(service.properties[i])) {
      continue;
    }
    controls.push(resolvePropertyControl(service, service.properties[i], displayName));
  }
  return controls;
}

export function buildServiceActions(service: MIoTSpecService, displayNames?: Map<number, string>): ActionControlDescriptor[] {
  const actions: ActionControlDescriptor[] = [];
  if (isHiddenService(service)) {
    return actions;
  }
  const displayName = displayNames?.get(service.iid);
  for (let i = 0; i < service.actions.length; i++) {
    actions.push(resolveActionControl(service, service.actions[i], displayName));
  }
  return actions;
}

function resolveControlType(property: MIoTSpecProperty): CapabilityControlType {
  if (!property.writable && property.readable) {
    return CapabilityControlType.READOUT;
  }
  const typeLower = property.type.toLowerCase();
  if (property.valueList.length > 0) {
    return CapabilityControlType.SELECT;
  }
  if (property.format === 'bool') {
    return CapabilityControlType.TOGGLE;
  }
  if (isGenericOnOff(property.description)) {
    return CapabilityControlType.TOGGLE;
  }
  if (typeLower.includes('temperature') || property.unit.toLowerCase().includes('celsius') ||
    property.unit.toLowerCase().includes('fahrenheit')) {
    return CapabilityControlType.TEMPERATURE;
  }
  if (typeLower.includes('volume')) {
    return CapabilityControlType.VOLUME;
  }
  if (property.valueRange !== null) {
    return CapabilityControlType.SLIDER;
  }
  return CapabilityControlType.TEXT;
}

function findProperty(service: MIoTSpecService, piid: number): MIoTSpecProperty | null {
  for (let i = 0; i < service.properties.length; i++) {
    if (service.properties[i].iid === piid) {
      return service.properties[i];
    }
  }
  return null;
}

// ==================== 完整翻译词条补充（按设备/功能分类） ====================

// —— 传感器 / 环境监测 ——
MIOT_TEXT_DICTIONARY['illuminance'] = '光照度';
MIOT_TEXT_DICTIONARY['illumination intensity'] = '光照强度';
MIOT_TEXT_DICTIONARY['light intensity'] = '光照强度';
MIOT_TEXT_DICTIONARY['atmospheric pressure'] = '大气压';
MIOT_TEXT_DICTIONARY['air pressure'] = '气压';
MIOT_TEXT_DICTIONARY['pressure'] = '气压';
MIOT_TEXT_DICTIONARY['soil moisture'] = '土壤湿度';
MIOT_TEXT_DICTIONARY['soil temperature'] = '土壤温度';
MIOT_TEXT_DICTIONARY['pm1.0'] = 'PM1.0';
MIOT_TEXT_DICTIONARY['pm10'] = 'PM10';
MIOT_TEXT_DICTIONARY['aqi'] = 'AQI';
MIOT_TEXT_DICTIONARY['air quality index'] = '空气质量指数';
MIOT_TEXT_DICTIONARY['voc'] = 'VOC';
MIOT_TEXT_DICTIONARY['tvoc concentration'] = 'TVOC 浓度';
MIOT_TEXT_DICTIONARY['co concentration'] = '一氧化碳浓度';
MIOT_TEXT_DICTIONARY['noise'] = '噪音';
MIOT_TEXT_DICTIONARY['noise level'] = '噪音水平';
MIOT_TEXT_DICTIONARY['loudness'] = '响度';
MIOT_TEXT_DICTIONARY['wind direction'] = '风向';
MIOT_TEXT_DICTIONARY['rain'] = '雨量';
MIOT_TEXT_DICTIONARY['rainfall'] = '雨量';
MIOT_TEXT_DICTIONARY['uv intensity'] = '紫外线强度';
MIOT_TEXT_DICTIONARY['uv index'] = '紫外线指数';
MIOT_TEXT_DICTIONARY['dust density'] = '灰尘浓度';
MIOT_TEXT_DICTIONARY['motion state'] = '移动状态';
MIOT_TEXT_DICTIONARY['motion detection'] = '移动侦测';
MIOT_TEXT_DICTIONARY['presence state'] = '人体存在状态';
MIOT_TEXT_DICTIONARY['presence detection'] = '人体感应';
MIOT_TEXT_DICTIONARY['occupancy'] = '占用状态';
MIOT_TEXT_DICTIONARY['occupancy state'] = '占用状态';
MIOT_TEXT_DICTIONARY['door state'] = '门状态';
MIOT_TEXT_DICTIONARY['window state'] = '窗状态';
MIOT_TEXT_DICTIONARY['contact state'] = '接触状态';
MIOT_TEXT_DICTIONARY['open state'] = '打开状态';
MIOT_TEXT_DICTIONARY['close state'] = '关闭状态';
MIOT_TEXT_DICTIONARY['tilt angle'] = '倾斜角度';
MIOT_TEXT_DICTIONARY['vibration'] = '振动';
MIOT_TEXT_DICTIONARY['vibration intensity'] = '振动强度';
MIOT_TEXT_DICTIONARY['smoke density'] = '烟雾浓度';
MIOT_TEXT_DICTIONARY['gas density'] = '燃气浓度';
MIOT_TEXT_DICTIONARY['gas consumption'] = '燃气消耗';
MIOT_TEXT_DICTIONARY['used time'] = '已用时间';
MIOT_TEXT_DICTIONARY['used'] = '已用';
MIOT_TEXT_DICTIONARY['leakage'] = '泄漏';
MIOT_TEXT_DICTIONARY['water leak'] = '水浸';
MIOT_TEXT_DICTIONARY['flood'] = '水浸';
MIOT_TEXT_DICTIONARY['battery voltage'] = '电池电压';
MIOT_TEXT_DICTIONARY['battery capacity'] = '电池容量';
MIOT_TEXT_DICTIONARY['battery temperature'] = '电池温度';
MIOT_TEXT_DICTIONARY['charge status'] = '充电状态';
MIOT_TEXT_DICTIONARY['remaining battery'] = '剩余电量';
MIOT_TEXT_DICTIONARY['battery status'] = '电池状态';
MIOT_TEXT_DICTIONARY['power level'] = '电量';
MIOT_TEXT_DICTIONARY['electricity'] = '电量';

// —— 门锁 / 安防 ——
MIOT_TEXT_DICTIONARY['lock state'] = '锁定状态';
MIOT_TEXT_DICTIONARY['unlock state'] = '解锁状态';
MIOT_TEXT_DICTIONARY['lock status'] = '锁定状态';
MIOT_TEXT_DICTIONARY['lock method'] = '开锁方式';
MIOT_TEXT_DICTIONARY['unlock method'] = '解锁方式';
MIOT_TEXT_DICTIONARY['lock action'] = '锁具操作';
MIOT_TEXT_DICTIONARY['unlock action'] = '解锁操作';
MIOT_TEXT_DICTIONARY['doorbell'] = '门铃';
MIOT_TEXT_DICTIONARY['keypad'] = '键盘';
MIOT_TEXT_DICTIONARY['fingerprint'] = '指纹';
MIOT_TEXT_DICTIONARY['face recognition'] = '人脸识别';
MIOT_TEXT_DICTIONARY['password'] = '密码';
MIOT_TEXT_DICTIONARY['temporary password'] = '临时密码';
MIOT_TEXT_DICTIONARY['one-time password'] = '一次性密码';
MIOT_TEXT_DICTIONARY['lock record'] = '开锁记录';
MIOT_TEXT_DICTIONARY['door status'] = '门状态';
MIOT_TEXT_DICTIONARY['open record'] = '开门记录';
MIOT_TEXT_DICTIONARY['anti-lock'] = '反锁';
MIOT_TEXT_DICTIONARY['deadlock'] = '反锁';
MIOT_TEXT_DICTIONARY['door lock'] = '门锁';

// —— 窗帘 / 电机 ——
MIOT_TEXT_DICTIONARY['motor'] = '电机';
MIOT_TEXT_DICTIONARY['motor control'] = '电机控制';
MIOT_TEXT_DICTIONARY['motor reversal'] = '电机反转';
MIOT_TEXT_DICTIONARY['motor direction'] = '电机方向';
MIOT_TEXT_DICTIONARY['curtain level'] = '窗帘开合度';
MIOT_TEXT_DICTIONARY['curtain position'] = '窗帘位置';
MIOT_TEXT_DICTIONARY['target level'] = '目标开合度';
MIOT_TEXT_DICTIONARY['current level'] = '当前开合度';
MIOT_TEXT_DICTIONARY['open percent'] = '开启百分比';
MIOT_TEXT_DICTIONARY['roller shade'] = '卷帘';
MIOT_TEXT_DICTIONARY['shade'] = '遮阳帘';
MIOT_TEXT_DICTIONARY['blinds'] = '百叶窗';
MIOT_TEXT_DICTIONARY['garage door state'] = '车库门状态';
MIOT_TEXT_DICTIONARY['louver'] = '百叶';
MIOT_TEXT_DICTIONARY['louver angle'] = '百叶角度';
MIOT_TEXT_DICTIONARY['louver switch'] = '百叶开关';

// —— 空调 / 暖通 ——
MIOT_TEXT_DICTIONARY['air conditioner mode'] = '空调模式';
MIOT_TEXT_DICTIONARY['ac mode'] = '空调模式';
MIOT_TEXT_DICTIONARY['cooling'] = '制冷';
MIOT_TEXT_DICTIONARY['ventilation'] = '通风';
MIOT_TEXT_DICTIONARY['air supply'] = '送风';
MIOT_TEXT_DICTIONARY['upper wind'] = '上吹风';
MIOT_TEXT_DICTIONARY['lower wind'] = '下吹风';
MIOT_TEXT_DICTIONARY['up-down swing'] = '上下扫风';
MIOT_TEXT_DICTIONARY['left-right swing'] = '左右扫风';
MIOT_TEXT_DICTIONARY['swing horizontal'] = '水平扫风';
MIOT_TEXT_DICTIONARY['swing vertical'] = '垂直扫风';
MIOT_TEXT_DICTIONARY['comfort temperature'] = '舒适温度';
MIOT_TEXT_DICTIONARY['eco temperature'] = '节能温度';
MIOT_TEXT_DICTIONARY['sleep temperature'] = '睡眠温度';
MIOT_TEXT_DICTIONARY['powerful mode'] = '强力模式';
MIOT_TEXT_DICTIONARY['gentle mode'] = '柔和模式';
MIOT_TEXT_DICTIONARY['display light'] = '显示屏灯光';
MIOT_TEXT_DICTIONARY['screen display'] = '屏幕显示';
MIOT_TEXT_DICTIONARY['timer remaining time'] = '定时剩余时间';
MIOT_TEXT_DICTIONARY['power on time'] = '开机时间';
MIOT_TEXT_DICTIONARY['power off time'] = '关机时间';
MIOT_TEXT_DICTIONARY['fresh air'] = '新风';
MIOT_TEXT_DICTIONARY['air exchange'] = '换气';
MIOT_TEXT_DICTIONARY['heating power'] = '制热功率';
MIOT_TEXT_DICTIONARY['cooling power'] = '制冷功率';
MIOT_TEXT_DICTIONARY['compressor'] = '压缩机';
MIOT_TEXT_DICTIONARY['compressor state'] = '压缩机状态';
MIOT_TEXT_DICTIONARY['refrigerant'] = '制冷剂';
MIOT_TEXT_DICTIONARY['thermostat'] = '恒温器';
MIOT_TEXT_DICTIONARY['temperature control'] = '温度控制';
MIOT_TEXT_DICTIONARY['floor heating'] = '地暖';
MIOT_TEXT_DICTIONARY['radiator'] = '暖气';
MIOT_TEXT_DICTIONARY['electric blanket'] = '电热毯';

// —— 净化 / 加湿 ——
MIOT_TEXT_DICTIONARY['purifier status'] = '净化状态';
MIOT_TEXT_DICTIONARY['purification level'] = '净化档位';
MIOT_TEXT_DICTIONARY['humidifier status'] = '加湿状态';
MIOT_TEXT_DICTIONARY['humidification level'] = '加湿档位';
MIOT_TEXT_DICTIONARY['humidity level'] = '湿度档位';
MIOT_TEXT_DICTIONARY['water shortage'] = '缺水';
MIOT_TEXT_DICTIONARY['tank full'] = '水箱已满';
MIOT_TEXT_DICTIONARY['filter status'] = '滤芯状态';
MIOT_TEXT_DICTIONARY['filter change reminder'] = '更换滤芯提醒';
MIOT_TEXT_DICTIONARY['filter percent'] = '滤芯剩余';
MIOT_TEXT_DICTIONARY['sterilization status'] = '杀菌状态';
MIOT_TEXT_DICTIONARY['anion status'] = '负离子状态';
MIOT_TEXT_DICTIONARY['ionizer'] = '负离子';
MIOT_TEXT_DICTIONARY['ion generation'] = '负离子发生';
MIOT_TEXT_DICTIONARY['uv lamp'] = '紫外线灯';
MIOT_TEXT_DICTIONARY['uv sterilization'] = '紫外线杀菌';
MIOT_TEXT_DICTIONARY['plasma sterilization'] = '等离子杀菌';
MIOT_TEXT_DICTIONARY['deodorization status'] = '除味状态';
MIOT_TEXT_DICTIONARY['formaldehyde removal'] = '除甲醛';
MIOT_TEXT_DICTIONARY['air quality level'] = '空气质量等级';
MIOT_TEXT_DICTIONARY['air quality indicator'] = '空气质量指示';
MIOT_TEXT_DICTIONARY['aqi level'] = 'AQI 等级';
MIOT_TEXT_DICTIONARY['sterilization'] = '杀菌';
MIOT_TEXT_DICTIONARY['purification'] = '净化';
MIOT_TEXT_DICTIONARY['humidification'] = '加湿';
MIOT_TEXT_DICTIONARY['dehumidification'] = '除湿';
MIOT_TEXT_DICTIONARY['air clean'] = '空气清洁';

// —— 扫地机器人 / 吸尘器 ——
MIOT_TEXT_DICTIONARY['clean status'] = '清洁状态';
MIOT_TEXT_DICTIONARY['cleaning'] = '清洁中';
MIOT_TEXT_DICTIONARY['cleaning time'] = '清洁时长';
MIOT_TEXT_DICTIONARY['cleaning area'] = '清洁面积';
MIOT_TEXT_DICTIONARY['cleaning count'] = '清洁次数';
MIOT_TEXT_DICTIONARY['sweeping'] = '扫地中';
MIOT_TEXT_DICTIONARY['mopping'] = '拖地中';
MIOT_TEXT_DICTIONARY['sweeping and mopping'] = '扫拖一体';
MIOT_TEXT_DICTIONARY['suction state'] = '吸力状态';
MIOT_TEXT_DICTIONARY['water tank installed'] = '水箱已安装';
MIOT_TEXT_DICTIONARY['mop installed'] = '拖布已安装';
MIOT_TEXT_DICTIONARY['mop pad'] = '拖布';
MIOT_TEXT_DICTIONARY['brush'] = '滚刷';
MIOT_TEXT_DICTIONARY['side brush'] = '边刷';
MIOT_TEXT_DICTIONARY['brush life'] = '滚刷寿命';
MIOT_TEXT_DICTIONARY['side brush life'] = '边刷寿命';
MIOT_TEXT_DICTIONARY['dust box'] = '尘盒';
MIOT_TEXT_DICTIONARY['dust bag'] = '尘袋';
MIOT_TEXT_DICTIONARY['docking station'] = '基站';
MIOT_TEXT_DICTIONARY['auto empty'] = '自动集尘';
MIOT_TEXT_DICTIONARY['auto wash'] = '自动清洗';
MIOT_TEXT_DICTIONARY['auto dry'] = '自动烘干';
MIOT_TEXT_DICTIONARY['map'] = '地图';
MIOT_TEXT_DICTIONARY['multi floor map'] = '多楼层地图';
MIOT_TEXT_DICTIONARY['auto empty station'] = '自动集尘站';
MIOT_TEXT_DICTIONARY['wash station'] = '清洗基站';
MIOT_TEXT_DICTIONARY['mop drying'] = '拖布烘干';
MIOT_TEXT_DICTIONARY['mop washing'] = '拖布清洗';
MIOT_TEXT_DICTIONARY['water changing'] = '换水';
MIOT_TEXT_DICTIONARY['clean water'] = '清水';
MIOT_TEXT_DICTIONARY['waste water'] = '污水';

// —— 洗衣机 / 烘干机 / 洗碗机 ——
MIOT_TEXT_DICTIONARY['wash status'] = '洗涤状态';
MIOT_TEXT_DICTIONARY['wash process'] = '洗涤进程';
MIOT_TEXT_DICTIONARY['drying status'] = '烘干状态';
MIOT_TEXT_DICTIONARY['program'] = '程序';
MIOT_TEXT_DICTIONARY['program progress'] = '程序进度';
MIOT_TEXT_DICTIONARY['spin state'] = '脱水状态';
MIOT_TEXT_DICTIONARY['rinse times'] = '漂洗次数';
MIOT_TEXT_DICTIONARY['soak time'] = '浸泡时间';
MIOT_TEXT_DICTIONARY['delay start'] = '延时启动';
MIOT_TEXT_DICTIONARY['dry level'] = '烘干档位';
MIOT_TEXT_DICTIONARY['dry degree'] = '烘干程度';
MIOT_TEXT_DICTIONARY['dish washing'] = '洗碗';
MIOT_TEXT_DICTIONARY['dishwasher status'] = '洗碗机状态';
MIOT_TEXT_DICTIONARY['high temperature wash'] = '高温洗涤';
MIOT_TEXT_DICTIONARY['steam wash'] = '蒸汽洗';
MIOT_TEXT_DICTIONARY['drying degree'] = '烘干程度';
MIOT_TEXT_DICTIONARY['wash temperature'] = '洗涤温度';
MIOT_TEXT_DICTIONARY['wash time'] = '洗涤时间';
MIOT_TEXT_DICTIONARY['washing machine'] = '洗衣机';
MIOT_TEXT_DICTIONARY['dryer'] = '烘干机';
MIOT_TEXT_DICTIONARY['drum'] = '滚筒';

// —— 厨房电器 ——
MIOT_TEXT_DICTIONARY['cook status'] = '烹饪状态';
MIOT_TEXT_DICTIONARY['cooking'] = '烹饪中';
MIOT_TEXT_DICTIONARY['cook mode'] = '烹饪模式';
MIOT_TEXT_DICTIONARY['cook time'] = '烹饪时间';
MIOT_TEXT_DICTIONARY['rice cooking'] = '煮饭';
MIOT_TEXT_DICTIONARY['keep warm'] = '保温';
MIOT_TEXT_DICTIONARY['keep warm time'] = '保温时间';
MIOT_TEXT_DICTIONARY['boil'] = '烧水';
MIOT_TEXT_DICTIONARY['boiling'] = '烧水中';
MIOT_TEXT_DICTIONARY['keep warm temperature'] = '保温温度';
MIOT_TEXT_DICTIONARY['water boiling'] = '水沸腾';
MIOT_TEXT_DICTIONARY['coffee strength'] = '咖啡浓度';
MIOT_TEXT_DICTIONARY['grind'] = '研磨';
MIOT_TEXT_DICTIONARY['grind level'] = '研磨度';
MIOT_TEXT_DICTIONARY['cup count'] = '杯数';
MIOT_TEXT_DICTIONARY['milk foam'] = '奶泡';
MIOT_TEXT_DICTIONARY['hot water dispenser'] = '即热饮水机';
MIOT_TEXT_DICTIONARY['dispensing'] = '出水中';
MIOT_TEXT_DICTIONARY['water dispense'] = '出水';
MIOT_TEXT_DICTIONARY['cooking stage'] = '烹饪阶段';
MIOT_TEXT_DICTIONARY['food temperature'] = '食物温度';
MIOT_TEXT_DICTIONARY['inner temperature'] = '内胆温度';
MIOT_TEXT_DICTIONARY['cooking progress'] = '烹饪进度';
MIOT_TEXT_DICTIONARY['brewing'] = '冲泡中';
MIOT_TEXT_DICTIONARY['infusion'] = '浸泡';
MIOT_TEXT_DICTIONARY['recipe'] = '食谱';
MIOT_TEXT_DICTIONARY['menu'] = '菜单';
MIOT_TEXT_DICTIONARY['cookbook'] = '菜谱';

// —— 热水器 ——
MIOT_TEXT_DICTIONARY['bath time'] = '沐浴时长';
MIOT_TEXT_DICTIONARY['bath keep warm'] = '浴缸保温';
MIOT_TEXT_DICTIONARY['input water temperature'] = '进水温度';
MIOT_TEXT_DICTIONARY['input water'] = '进水';
MIOT_TEXT_DICTIONARY['hot water recirculation'] = '热水循环';
MIOT_TEXT_DICTIONARY['recirculation'] = '循环';
MIOT_TEXT_DICTIONARY['preheat time'] = '预热时间';
MIOT_TEXT_DICTIONARY['preheat'] = '预热';
MIOT_TEXT_DICTIONARY['rapid preheat'] = '快速预热';
MIOT_TEXT_DICTIONARY['rapid'] = '快速';
MIOT_TEXT_DICTIONARY['water control preheat'] = '水控预热';
MIOT_TEXT_DICTIONARY['water control'] = '水控';
MIOT_TEXT_DICTIONARY['high altitude mode'] = '高海拔模式';
MIOT_TEXT_DICTIONARY['altitude'] = '海拔';
MIOT_TEXT_DICTIONARY['intelligent preheat'] = '智能预热';
MIOT_TEXT_DICTIONARY['intelligent'] = '智能';
MIOT_TEXT_DICTIONARY['anti icing status'] = '防冻状态';
MIOT_TEXT_DICTIONARY['anti icing'] = '防冻';
MIOT_TEXT_DICTIONARY['icing'] = '结冰';
MIOT_TEXT_DICTIONARY['anti'] = '防';
MIOT_TEXT_DICTIONARY['eco study status'] = '节能学习状态';
MIOT_TEXT_DICTIONARY['eco study'] = '节能学习';
MIOT_TEXT_DICTIONARY['study'] = '学习';
MIOT_TEXT_DICTIONARY['water pump volt'] = '水泵电压';
MIOT_TEXT_DICTIONARY['volt'] = '电压';
MIOT_TEXT_DICTIONARY['cloud-preheater'] = '云预热';
MIOT_TEXT_DICTIONARY['cloud preheater'] = '云预热';
MIOT_TEXT_DICTIONARY['cloud- preheater'] = '云预热';
MIOT_TEXT_DICTIONARY['cloud'] = '云';
MIOT_TEXT_DICTIONARY['enhanced anti icing'] = '增强防冻';
MIOT_TEXT_DICTIONARY['enhanced'] = '增强';
MIOT_TEXT_DICTIONARY['comfortable'] = '舒适';
MIOT_TEXT_DICTIONARY['ai'] = 'AI';
MIOT_TEXT_DICTIONARY['baby care'] = '婴儿洗';
MIOT_TEXT_DICTIONARY['pet wash'] = '宠物洗';
MIOT_TEXT_DICTIONARY['kitchen'] = '厨房';
MIOT_TEXT_DICTIONARY['water temperature setting'] = '水温设置';
MIOT_TEXT_DICTIONARY['tank temperature'] = '水箱温度';
MIOT_TEXT_DICTIONARY['residual heat'] = '余热';
MIOT_TEXT_DICTIONARY['heat pump'] = '热泵';
MIOT_TEXT_DICTIONARY['instant heating'] = '即热';
MIOT_TEXT_DICTIONARY['smart preheating'] = '智能预热';
MIOT_TEXT_DICTIONARY['season'] = '季节';
MIOT_TEXT_DICTIONARY['summer'] = '夏季';
MIOT_TEXT_DICTIONARY['winter'] = '冬季';
MIOT_TEXT_DICTIONARY['gas water heater'] = '燃气热水器';
MIOT_TEXT_DICTIONARY['electric water heater'] = '电热水器';
MIOT_TEXT_DICTIONARY['water heater'] = '热水器';
MIOT_TEXT_DICTIONARY['tank'] = '水箱';
MIOT_TEXT_DICTIONARY['flame'] = '火焰';
MIOT_TEXT_DICTIONARY['flame state'] = '火焰状态';
MIOT_TEXT_DICTIONARY['smoke exhaust'] = '排烟';
MIOT_TEXT_DICTIONARY['exhaust'] = '排烟';

// —— 空调插座 / 空调伴侣 ——
MIOT_TEXT_DICTIONARY['match state'] = '匹配状态';
MIOT_TEXT_DICTIONARY['match'] = '匹配';

// —— 影音 / 音箱 / 电视 ——
MIOT_TEXT_DICTIONARY['channel up'] = '频道加';
MIOT_TEXT_DICTIONARY['channel down'] = '频道减';
MIOT_TEXT_DICTIONARY['input source'] = '信号源';
MIOT_TEXT_DICTIONARY['hdmi'] = 'HDMI';
MIOT_TEXT_DICTIONARY['av'] = 'AV';
MIOT_TEXT_DICTIONARY['usb'] = 'USB';
MIOT_TEXT_DICTIONARY['screen state'] = '屏幕状态';
MIOT_TEXT_DICTIONARY['screen off'] = '熄屏';
MIOT_TEXT_DICTIONARY['screen on'] = '亮屏';
MIOT_TEXT_DICTIONARY['picture mode'] = '图像模式';
MIOT_TEXT_DICTIONARY['sound mode'] = '音效模式';
MIOT_TEXT_DICTIONARY['volume up'] = '音量加';
MIOT_TEXT_DICTIONARY['volume down'] = '音量减';
MIOT_TEXT_DICTIONARY['media title'] = '媒体标题';
MIOT_TEXT_DICTIONARY['artist'] = '歌手';
MIOT_TEXT_DICTIONARY['album'] = '专辑';
MIOT_TEXT_DICTIONARY['play time'] = '播放时间';
MIOT_TEXT_DICTIONARY['total time'] = '总时长';
MIOT_TEXT_DICTIONARY['media type'] = '媒体类型';
MIOT_TEXT_DICTIONARY['playlist'] = '播放列表';
MIOT_TEXT_DICTIONARY['station'] = '电台';
MIOT_TEXT_DICTIONARY['song'] = '歌曲';
MIOT_TEXT_DICTIONARY['track'] = '曲目';
MIOT_TEXT_DICTIONARY['voice assistant'] = '语音助手';
MIOT_TEXT_DICTIONARY['wake word'] = '唤醒词';

// —— 路由器 / 网络 ——
MIOT_TEXT_DICTIONARY['wifi status'] = 'WiFi 状态';
MIOT_TEXT_DICTIONARY['internet'] = '互联网';
MIOT_TEXT_DICTIONARY['band'] = '频段';
MIOT_TEXT_DICTIONARY['guest wifi'] = '访客 WiFi';
MIOT_TEXT_DICTIONARY['ssid'] = 'SSID';
MIOT_TEXT_DICTIONARY['mac address'] = 'MAC 地址';
MIOT_TEXT_DICTIONARY['ip address'] = 'IP 地址';
MIOT_TEXT_DICTIONARY['data usage'] = '流量使用';
MIOT_TEXT_DICTIONARY['download speed'] = '下载速度';
MIOT_TEXT_DICTIONARY['upload speed'] = '上传速度';
MIOT_TEXT_DICTIONARY['wifi signal'] = 'WiFi 信号';
MIOT_TEXT_DICTIONARY['wifi band'] = 'WiFi 频段';
MIOT_TEXT_DICTIONARY['network status'] = '网络状态';
MIOT_TEXT_DICTIONARY['wan'] = '广域网';
MIOT_TEXT_DICTIONARY['lan'] = '局域网';

// —— 灯光 / 场景 ——
MIOT_TEXT_DICTIONARY['scene list'] = '场景列表';
MIOT_TEXT_DICTIONARY['scene switch'] = '场景开关';
MIOT_TEXT_DICTIONARY['gradual brightness'] = '渐变亮度';
MIOT_TEXT_DICTIONARY['gradual change'] = '渐变';
MIOT_TEXT_DICTIONARY['breathing light'] = '呼吸灯';
MIOT_TEXT_DICTIONARY['rgb'] = 'RGB';
MIOT_TEXT_DICTIONARY['rgbw'] = 'RGBW';
MIOT_TEXT_DICTIONARY['red'] = '红色';
MIOT_TEXT_DICTIONARY['green'] = '绿色';
MIOT_TEXT_DICTIONARY['blue'] = '蓝色';
MIOT_TEXT_DICTIONARY['yellow'] = '黄色';
MIOT_TEXT_DICTIONARY['white'] = '白色';
MIOT_TEXT_DICTIONARY['monochrome'] = '单色';
MIOT_TEXT_DICTIONARY['colorful'] = '彩色';
MIOT_TEXT_DICTIONARY['light effect'] = '灯光效果';
MIOT_TEXT_DICTIONARY['effect'] = '效果';
MIOT_TEXT_DICTIONARY['flashing'] = '闪烁';
MIOT_TEXT_DICTIONARY['strobe'] = '频闪';
MIOT_TEXT_DICTIONARY['candle light'] = '烛光';
MIOT_TEXT_DICTIONARY['sunrise'] = '日出';
MIOT_TEXT_DICTIONARY['sunset'] = '日落';
MIOT_TEXT_DICTIONARY['romantic'] = '浪漫';
MIOT_TEXT_DICTIONARY['party'] = '派对';
MIOT_TEXT_DICTIONARY['reading'] = '阅读';
MIOT_TEXT_DICTIONARY['movie'] = '观影';
MIOT_TEXT_DICTIONARY['relax'] = '放松';

// —— 插座 / 电源 ——
MIOT_TEXT_DICTIONARY['outlet'] = '插座';
MIOT_TEXT_DICTIONARY['plug'] = '插头';
MIOT_TEXT_DICTIONARY['usb port'] = 'USB 口';
MIOT_TEXT_DICTIONARY['usb switch'] = 'USB 开关';
MIOT_TEXT_DICTIONARY['wireless charging'] = '无线充电';
MIOT_TEXT_DICTIONARY['charging output'] = '充电输出';
MIOT_TEXT_DICTIONARY['charging power'] = '充电功率';
MIOT_TEXT_DICTIONARY['output power'] = '输出功率';
MIOT_TEXT_DICTIONARY['output voltage'] = '输出电压';
MIOT_TEXT_DICTIONARY['output current'] = '输出电流';
MIOT_TEXT_DICTIONARY['input power'] = '输入功率';
MIOT_TEXT_DICTIONARY['input voltage'] = '输入电压';
MIOT_TEXT_DICTIONARY['input current'] = '输入电流';

// —— 宠物 / 鱼缸 ——
MIOT_TEXT_DICTIONARY['food level'] = '余粮';
MIOT_TEXT_DICTIONARY['food amount'] = '喂食量';
MIOT_TEXT_DICTIONARY['feeding'] = '喂食';
MIOT_TEXT_DICTIONARY['feeding time'] = '喂食时间';
MIOT_TEXT_DICTIONARY['oxygen'] = '氧气';
MIOT_TEXT_DICTIONARY['oxygen pump'] = '氧气泵';
MIOT_TEXT_DICTIONARY['filter pump'] = '过滤泵';
MIOT_TEXT_DICTIONARY['heating rod'] = '加热棒';
MIOT_TEXT_DICTIONARY['lighting'] = '照明';
MIOT_TEXT_DICTIONARY['water pump'] = '水泵';
MIOT_TEXT_DICTIONARY['fish tank'] = '鱼缸';
MIOT_TEXT_DICTIONARY['water flow rate'] = '水流量';
MIOT_TEXT_DICTIONARY['water quality'] = '水质';
MIOT_TEXT_DICTIONARY['ph'] = 'pH';
MIOT_TEXT_DICTIONARY['tds'] = 'TDS';

// —— 按摩 / 健康 ——
MIOT_TEXT_DICTIONARY['massage'] = '按摩';
MIOT_TEXT_DICTIONARY['massage mode'] = '按摩模式';
MIOT_TEXT_DICTIONARY['massage strength'] = '按摩力度';
MIOT_TEXT_DICTIONARY['heat level'] = '加热档位';
MIOT_TEXT_DICTIONARY['intensity'] = '强度';
MIOT_TEXT_DICTIONARY['heat'] = '加热';
MIOT_TEXT_DICTIONARY['massage chair'] = '按摩椅';
MIOT_TEXT_DICTIONARY['massage gun'] = '筋膜枪';
MIOT_TEXT_DICTIONARY['roller'] = '滚轮';
MIOT_TEXT_DICTIONARY['airbag'] = '气囊';
MIOT_TEXT_DICTIONARY['airbag level'] = '气囊档位';
MIOT_TEXT_DICTIONARY['foot massage'] = '足部按摩';
MIOT_TEXT_DICTIONARY['neck massage'] = '颈部按摩';
MIOT_TEXT_DICTIONARY['back massage'] = '背部按摩';
MIOT_TEXT_DICTIONARY['waist massage'] = '腰部按摩';
MIOT_TEXT_DICTIONARY['hair dryer'] = '吹风机';
MIOT_TEXT_DICTIONARY['wind temperature'] = '风温';
MIOT_TEXT_DICTIONARY['wind power'] = '风力';

// —— 通用状态 / 枚举 ——
MIOT_TEXT_DICTIONARY['enabled'] = '启用';
MIOT_TEXT_DICTIONARY['disabled'] = '禁用';
MIOT_TEXT_DICTIONARY['locked'] = '已锁定';
MIOT_TEXT_DICTIONARY['unlocked'] = '已解锁';
MIOT_TEXT_DICTIONARY['closed'] = '已关闭';
MIOT_TEXT_DICTIONARY['opened'] = '已打开';
MIOT_TEXT_DICTIONARY['occupied'] = '有人';
MIOT_TEXT_DICTIONARY['unoccupied'] = '无人';
MIOT_TEXT_DICTIONARY['present'] = '有人';
MIOT_TEXT_DICTIONARY['absent'] = '无人';
MIOT_TEXT_DICTIONARY['abnormal'] = '异常';
MIOT_TEXT_DICTIONARY['unknown'] = '未知';
MIOT_TEXT_DICTIONARY['active'] = '激活';
MIOT_TEXT_DICTIONARY['inactive'] = '未激活';
MIOT_TEXT_DICTIONARY['connected'] = '已连接';
MIOT_TEXT_DICTIONARY['disconnected'] = '已断开';
MIOT_TEXT_DICTIONARY['paired'] = '已配对';
MIOT_TEXT_DICTIONARY['unpaired'] = '未配对';
MIOT_TEXT_DICTIONARY['success'] = '成功';
MIOT_TEXT_DICTIONARY['failure'] = '失败';
MIOT_TEXT_DICTIONARY['completed'] = '已完成';
MIOT_TEXT_DICTIONARY['starting'] = '启动中';
MIOT_TEXT_DICTIONARY['stopping'] = '停止中';
MIOT_TEXT_DICTIONARY['preparing'] = '准备中';
MIOT_TEXT_DICTIONARY['ready'] = '就绪';
MIOT_TEXT_DICTIONARY['humidifying'] = '加湿中';
MIOT_TEXT_DICTIONARY['dehumidifying'] = '除湿中';
MIOT_TEXT_DICTIONARY['purifying'] = '净化中';
MIOT_TEXT_DICTIONARY['sterilizing'] = '杀菌中';
MIOT_TEXT_DICTIONARY['rinsing'] = '漂洗中';
MIOT_TEXT_DICTIONARY['spinning'] = '甩干中';
MIOT_TEXT_DICTIONARY['draining'] = '排水';
MIOT_TEXT_DICTIONARY['filling'] = '注水中';
MIOT_TEXT_DICTIONARY['cooling down'] = '降温中';
MIOT_TEXT_DICTIONARY['defrosting'] = '除霜中';
MIOT_TEXT_DICTIONARY['holiday'] = '假日';
MIOT_TEXT_DICTIONARY['away'] = '离家';
MIOT_TEXT_DICTIONARY['home'] = '在家';
MIOT_TEXT_DICTIONARY['gentle'] = '轻柔';
MIOT_TEXT_DICTIONARY['powerful'] = '强力';
MIOT_TEXT_DICTIONARY['default'] = '默认';
MIOT_TEXT_DICTIONARY['single'] = '单次';
MIOT_TEXT_DICTIONARY['multiple'] = '多次';
MIOT_TEXT_DICTIONARY['cycle'] = '循环';
MIOT_TEXT_DICTIONARY['once'] = '单次';
MIOT_TEXT_DICTIONARY['random'] = '随机';

// —— 通用动作 ——
MIOT_TEXT_DICTIONARY['resume'] = '继续';
MIOT_TEXT_DICTIONARY['restart'] = '重启';
MIOT_TEXT_DICTIONARY['reboot'] = '重启';
MIOT_TEXT_DICTIONARY['shutdown'] = '关机';
MIOT_TEXT_DICTIONARY['cancel'] = '取消';
MIOT_TEXT_DICTIONARY['confirm'] = '确认';
MIOT_TEXT_DICTIONARY['deep clean'] = '深度清洁';
MIOT_TEXT_DICTIONARY['stop cleaning'] = '停止清洁';
MIOT_TEXT_DICTIONARY['start cleaning'] = '开始清洁';
MIOT_TEXT_DICTIONARY['pause cleaning'] = '暂停清洁';
MIOT_TEXT_DICTIONARY['resume cleaning'] = '继续清洁';
MIOT_TEXT_DICTIONARY['return to dock'] = '回充';
MIOT_TEXT_DICTIONARY['go home'] = '回充';
MIOT_TEXT_DICTIONARY['charge'] = '充电';
MIOT_TEXT_DICTIONARY['start charging'] = '开始充电';
MIOT_TEXT_DICTIONARY['stop charging'] = '停止充电';
MIOT_TEXT_DICTIONARY['find me'] = '寻找设备';
MIOT_TEXT_DICTIONARY['fast forward'] = '快进';
MIOT_TEXT_DICTIONARY['rewind'] = '快退';
MIOT_TEXT_DICTIONARY['set volume'] = '设置音量';
MIOT_TEXT_DICTIONARY['set channel'] = '设置频道';
MIOT_TEXT_DICTIONARY['set input source'] = '设置信号源';
MIOT_TEXT_DICTIONARY['set scene'] = '设置场景';
MIOT_TEXT_DICTIONARY['activate'] = '激活';
MIOT_TEXT_DICTIONARY['deactivate'] = '停用';
MIOT_TEXT_DICTIONARY['update'] = '更新';
MIOT_TEXT_DICTIONARY['screenshot'] = '截图';
MIOT_TEXT_DICTIONARY['switch on'] = '打开';
MIOT_TEXT_DICTIONARY['switch off'] = '关闭';
MIOT_TEXT_DICTIONARY['start washing'] = '开始洗涤';
MIOT_TEXT_DICTIONARY['start drying'] = '开始烘干';
MIOT_TEXT_DICTIONARY['start cooking'] = '开始烹饪';
MIOT_TEXT_DICTIONARY['start boiling'] = '开始烧水';
MIOT_TEXT_DICTIONARY['left'] = '左';
MIOT_TEXT_DICTIONARY['right'] = '右';
MIOT_TEXT_DICTIONARY['left swing'] = '左摆';
MIOT_TEXT_DICTIONARY['right swing'] = '右摆';
MIOT_TEXT_DICTIONARY['start swing'] = '开始扫风';
MIOT_TEXT_DICTIONARY['stop swing'] = '停止扫风';
MIOT_TEXT_DICTIONARY['call'] = '呼叫';
MIOT_TEXT_DICTIONARY['hang up'] = '挂断';
MIOT_TEXT_DICTIONARY['answer'] = '接听';

// —— 服务类型 → 功能名（补充） ——
SERVICE_LABEL_DICTIONARY['illuminance-sensor'] = '光照传感器';
SERVICE_LABEL_DICTIONARY['light-sensor'] = '光照传感器';
SERVICE_LABEL_DICTIONARY['pressure-sensor'] = '气压传感器';
SERVICE_LABEL_DICTIONARY['barometer'] = '气压计';
SERVICE_LABEL_DICTIONARY['soil-sensor'] = '土壤传感器';
SERVICE_LABEL_DICTIONARY['soil-moisture-sensor'] = '土壤湿度传感器';
SERVICE_LABEL_DICTIONARY['rain-sensor'] = '雨量传感器';
SERVICE_LABEL_DICTIONARY['wind-sensor'] = '风速传感器';
SERVICE_LABEL_DICTIONARY['vibration-sensor'] = '振动传感器';
SERVICE_LABEL_DICTIONARY['tilt-sensor'] = '倾斜传感器';
SERVICE_LABEL_DICTIONARY['shock-sensor'] = '震动传感器';
SERVICE_LABEL_DICTIONARY['contact-sensor'] = '门磁传感器';
SERVICE_LABEL_DICTIONARY['window-sensor'] = '门窗传感器';
SERVICE_LABEL_DICTIONARY['water-leakage-sensor'] = '水浸传感器';
SERVICE_LABEL_DICTIONARY['co-sensor'] = '一氧化碳传感器';
SERVICE_LABEL_DICTIONARY['formaldehyde-sensor'] = '甲醛传感器';
SERVICE_LABEL_DICTIONARY['pm2.5-sensor'] = 'PM2.5 传感器';
SERVICE_LABEL_DICTIONARY['pm25-sensor'] = 'PM2.5 传感器';
SERVICE_LABEL_DICTIONARY['co2-sensor'] = 'CO2 传感器';
SERVICE_LABEL_DICTIONARY['tvoc-sensor'] = 'TVOC 传感器';
SERVICE_LABEL_DICTIONARY['voc-sensor'] = 'VOC 传感器';
SERVICE_LABEL_DICTIONARY['noise-sensor'] = '噪音传感器';
SERVICE_LABEL_DICTIONARY['sleep-sensor'] = '睡眠监测器';
SERVICE_LABEL_DICTIONARY['bed-presence-sensor'] = '离床传感器';
SERVICE_LABEL_DICTIONARY['body-fat-scale'] = '体脂秤';
SERVICE_LABEL_DICTIONARY['scale'] = '体脂秤';
SERVICE_LABEL_DICTIONARY['blood-pressure-monitor'] = '血压计';
SERVICE_LABEL_DICTIONARY['thermometer'] = '温度计';
SERVICE_LABEL_DICTIONARY['hygrometer'] = '湿度计';
SERVICE_LABEL_DICTIONARY['video-doorbell'] = '可视门铃';
SERVICE_LABEL_DICTIONARY['doorbell'] = '门铃';
SERVICE_LABEL_DICTIONARY['smart-alarm'] = '智能报警器';
SERVICE_LABEL_DICTIONARY['security'] = '安防';
SERVICE_LABEL_DICTIONARY['burglar-alarm'] = '防盗报警器';
SERVICE_LABEL_DICTIONARY['smart-lock'] = '智能门锁';
SERVICE_LABEL_DICTIONARY['deadbolt'] = '门锁';
SERVICE_LABEL_DICTIONARY['bed'] = '智能床';
SERVICE_LABEL_DICTIONARY['smart-bed'] = '智能床';
SERVICE_LABEL_DICTIONARY['desk'] = '升降桌';
SERVICE_LABEL_DICTIONARY['standing-desk'] = '升降桌';
SERVICE_LABEL_DICTIONARY['mirror'] = '智能镜';
SERVICE_LABEL_DICTIONARY['smart-mirror'] = '智能镜';
SERVICE_LABEL_DICTIONARY['airer'] = '智能晾衣架';
SERVICE_LABEL_DICTIONARY['clothes-airer'] = '智能晾衣架';
SERVICE_LABEL_DICTIONARY['clothes-rack'] = '晾衣架';
SERVICE_LABEL_DICTIONARY['electric-blanket'] = '电热毯';
SERVICE_LABEL_DICTIONARY['curtain-motor'] = '窗帘电机';
SERVICE_LABEL_DICTIONARY['roller-shade'] = '卷帘';
SERVICE_LABEL_DICTIONARY['garage-door-opener'] = '车库门';
SERVICE_LABEL_DICTIONARY['gate'] = '大门';
SERVICE_LABEL_DICTIONARY['smart-valve'] = '智能阀门';
SERVICE_LABEL_DICTIONARY['valve'] = '阀门';
SERVICE_LABEL_DICTIONARY['gas-valve'] = '燃气阀';
SERVICE_LABEL_DICTIONARY['water-valve'] = '水阀';
SERVICE_LABEL_DICTIONARY['smart-radiator'] = '智能暖气';
SERVICE_LABEL_DICTIONARY['floor-heating'] = '地暖';
SERVICE_LABEL_DICTIONARY['thermostat'] = '恒温器';
SERVICE_LABEL_DICTIONARY['water-dispenser'] = '饮水机';
SERVICE_LABEL_DICTIONARY['water-purifier'] = '净水器';
SERVICE_LABEL_DICTIONARY['pure-boil-dispenser'] = '即热净饮机';
SERVICE_LABEL_DICTIONARY['fruit-washer'] = '果蔬清洗机';
SERVICE_LABEL_DICTIONARY['food-disposer'] = '厨余处理器';
SERVICE_LABEL_DICTIONARY['bread-machine'] = '面包机';
SERVICE_LABEL_DICTIONARY['egg-cooker'] = '煮蛋器';
SERVICE_LABEL_DICTIONARY['sous-vide-cooker'] = '低温慢煮机';
SERVICE_LABEL_DICTIONARY['wine-cabinet'] = '酒柜';
SERVICE_LABEL_DICTIONARY['wine-cellar'] = '酒柜';
SERVICE_LABEL_DICTIONARY['steam-oven'] = '蒸烤箱';
SERVICE_LABEL_DICTIONARY['range-hood'] = '油烟机';
SERVICE_LABEL_DICTIONARY['exhaust-hood'] = '油烟机';
SERVICE_LABEL_DICTIONARY['gas-stove'] = '燃气灶';
SERVICE_LABEL_DICTIONARY['cooktop'] = '灶具';
SERVICE_LABEL_DICTIONARY['toaster'] = '烤面包机';
SERVICE_LABEL_DICTIONARY['juicer'] = '榨汁机';
SERVICE_LABEL_DICTIONARY['blender'] = '搅拌机';
SERVICE_LABEL_DICTIONARY['soymilk-maker'] = '豆浆机';
SERVICE_LABEL_DICTIONARY['yogurt-maker'] = '酸奶机';
SERVICE_LABEL_DICTIONARY['floor-washer'] = '洗地机';
SERVICE_LABEL_DICTIONARY['wet-dry-vacuum'] = '洗地机';
SERVICE_LABEL_DICTIONARY['iron'] = '挂烫机';
SERVICE_LABEL_DICTIONARY['handheld-vacuum'] = '手持吸尘器';
SERVICE_LABEL_DICTIONARY['sweeper'] = '扫地机';
SERVICE_LABEL_DICTIONARY['air-exchanger'] = '新风系统';
SERVICE_LABEL_DICTIONARY['fresh-air-system'] = '新风系统';
SERVICE_LABEL_DICTIONARY['ventilation-fan'] = '换气扇';
SERVICE_LABEL_DICTIONARY['ceiling-fan'] = '吊扇';
SERVICE_LABEL_DICTIONARY['electric-fireplace'] = '电壁炉';
SERVICE_LABEL_DICTIONARY['space-heater'] = '取暖器';
SERVICE_LABEL_DICTIONARY['fan-heater'] = '暖风机';
SERVICE_LABEL_DICTIONARY['smart-speaker'] = '智能音箱';
SERVICE_LABEL_DICTIONARY['soundbar'] = '回音壁';
SERVICE_LABEL_DICTIONARY['amplifier'] = '功放';
SERVICE_LABEL_DICTIONARY['audio-player'] = '播放器';
SERVICE_LABEL_DICTIONARY['player'] = '播放器';
SERVICE_LABEL_DICTIONARY['media-player'] = '媒体播放器';
SERVICE_LABEL_DICTIONARY['ipcamera'] = '摄像头';
SERVICE_LABEL_DICTIONARY['webcam'] = '摄像头';
SERVICE_LABEL_DICTIONARY['recorder'] = '录像机';
SERVICE_LABEL_DICTIONARY['video-recorder'] = '录像机';
SERVICE_LABEL_DICTIONARY['nvr'] = '录像机';
SERVICE_LABEL_DICTIONARY['wifi'] = 'WiFi';
SERVICE_LABEL_DICTIONARY['mesh-router'] = 'Mesh 路由器';
SERVICE_LABEL_DICTIONARY['power-outlet'] = '插座';
SERVICE_LABEL_DICTIONARY['usb-socket'] = 'USB 插座';
SERVICE_LABEL_DICTIONARY['wireless-charger'] = '无线充电器';
SERVICE_LABEL_DICTIONARY['power-bank'] = '充电宝';
SERVICE_LABEL_DICTIONARY['ups'] = 'UPS 电源';
SERVICE_LABEL_DICTIONARY['smart-battery'] = '智能电池';
SERVICE_LABEL_DICTIONARY['massage-chair'] = '按摩椅';
SERVICE_LABEL_DICTIONARY['massage-gun'] = '筋膜枪';
SERVICE_LABEL_DICTIONARY['eye-massager'] = '眼部按摩仪';
SERVICE_LABEL_DICTIONARY['foot-massager'] = '足浴盆';
SERVICE_LABEL_DICTIONARY['hair-dryer'] = '吹风机';
SERVICE_LABEL_DICTIONARY['electric-toothbrush'] = '电动牙刷';
SERVICE_LABEL_DICTIONARY['shaver'] = '剃须刀';
SERVICE_LABEL_DICTIONARY['beauty-device'] = '美容仪';
SERVICE_LABEL_DICTIONARY['pet-water-feeder'] = '宠物饮水机';
SERVICE_LABEL_DICTIONARY['pet-camera'] = '宠物摄像头';
SERVICE_LABEL_DICTIONARY['oxygen-pump'] = '氧气泵';
SERVICE_LABEL_DICTIONARY['heating-rod'] = '加热棒';
SERVICE_LABEL_DICTIONARY['water-heater'] = '热水器';
SERVICE_LABEL_DICTIONARY['gas-water-heater'] = '燃气热水器';
SERVICE_LABEL_DICTIONARY['electric-water-heater'] = '电热水器';
SERVICE_LABEL_DICTIONARY['air-conditioner-outlet'] = '空调插座';
SERVICE_LABEL_DICTIONARY['ac-outlet'] = '空调插座';
SERVICE_LABEL_DICTIONARY['air-conditioner-socket'] = '空调插座';

// —— 服务类型 → 布尔开关标签（补充） ——
SERVICE_BOOL_LABELS['video-doorbell'] = '门铃';
SERVICE_BOOL_LABELS['doorbell'] = '门铃';
SERVICE_BOOL_LABELS['alarm'] = '报警';
SERVICE_BOOL_LABELS['siren'] = '警报';
SERVICE_BOOL_LABELS['smart-alarm'] = '报警';
SERVICE_BOOL_LABELS['burglar-alarm'] = '报警';
SERVICE_BOOL_LABELS['smart-lock'] = '门锁';
SERVICE_BOOL_LABELS['deadbolt'] = '门锁';
SERVICE_BOOL_LABELS['lock'] = '门锁';
SERVICE_BOOL_LABELS['airer'] = '晾衣架';
SERVICE_BOOL_LABELS['clothes-airer'] = '晾衣架';
SERVICE_BOOL_LABELS['electric-blanket'] = '电热毯';
SERVICE_BOOL_LABELS['curtain-motor'] = '窗帘电机';
SERVICE_BOOL_LABELS['roller-shade'] = '卷帘';
SERVICE_BOOL_LABELS['garage-door-opener'] = '车库门';
SERVICE_BOOL_LABELS['smart-valve'] = '阀门';
SERVICE_BOOL_LABELS['valve'] = '阀门';
SERVICE_BOOL_LABELS['gas-valve'] = '燃气阀';
SERVICE_BOOL_LABELS['water-valve'] = '水阀';
SERVICE_BOOL_LABELS['smart-radiator'] = '暖气';
SERVICE_BOOL_LABELS['floor-heating'] = '地暖';
SERVICE_BOOL_LABELS['thermostat'] = '恒温器';
SERVICE_BOOL_LABELS['water-purifier'] = '净水器';
SERVICE_BOOL_LABELS['water-dispenser'] = '饮水机';
SERVICE_BOOL_LABELS['pure-boil-dispenser'] = '净饮机';
SERVICE_BOOL_LABELS['fruit-washer'] = '果蔬清洗机';
SERVICE_BOOL_LABELS['bread-machine'] = '面包机';
SERVICE_BOOL_LABELS['egg-cooker'] = '煮蛋器';
SERVICE_BOOL_LABELS['steam-oven'] = '蒸烤箱';
SERVICE_BOOL_LABELS['range-hood'] = '油烟机';
SERVICE_BOOL_LABELS['exhaust-hood'] = '油烟机';
SERVICE_BOOL_LABELS['gas-stove'] = '燃气灶';
SERVICE_BOOL_LABELS['cooktop'] = '灶具';
SERVICE_BOOL_LABELS['toaster'] = '面包机';
SERVICE_BOOL_LABELS['juicer'] = '榨汁机';
SERVICE_BOOL_LABELS['blender'] = '搅拌机';
SERVICE_BOOL_LABELS['soymilk-maker'] = '豆浆机';
SERVICE_BOOL_LABELS['yogurt-maker'] = '酸奶机';
SERVICE_BOOL_LABELS['wine-cabinet'] = '酒柜';
SERVICE_BOOL_LABELS['floor-washer'] = '洗地机';
SERVICE_BOOL_LABELS['wet-dry-vacuum'] = '洗地机';
SERVICE_BOOL_LABELS['handheld-vacuum'] = '吸尘器';
SERVICE_BOOL_LABELS['sweeper'] = '扫地机';
SERVICE_BOOL_LABELS['air-exchanger'] = '新风';
SERVICE_BOOL_LABELS['fresh-air-system'] = '新风';
SERVICE_BOOL_LABELS['ventilation-fan'] = '换气扇';
SERVICE_BOOL_LABELS['ceiling-fan'] = '吊扇';
SERVICE_BOOL_LABELS['electric-fireplace'] = '壁炉';
SERVICE_BOOL_LABELS['space-heater'] = '取暖器';
SERVICE_BOOL_LABELS['fan-heater'] = '暖风机';
SERVICE_BOOL_LABELS['radiator'] = '暖气';
SERVICE_BOOL_LABELS['smart-speaker'] = '音箱';
SERVICE_BOOL_LABELS['soundbar'] = '回音壁';
SERVICE_BOOL_LABELS['amplifier'] = '功放';
SERVICE_BOOL_LABELS['audio-player'] = '播放器';
SERVICE_BOOL_LABELS['player'] = '播放器';
SERVICE_BOOL_LABELS['media-player'] = '播放器';
SERVICE_BOOL_LABELS['ipcamera'] = '摄像头';
SERVICE_BOOL_LABELS['webcam'] = '摄像头';
SERVICE_BOOL_LABELS['recorder'] = '录像机';
SERVICE_BOOL_LABELS['nvr'] = '录像机';
SERVICE_BOOL_LABELS['wifi'] = 'WiFi';
SERVICE_BOOL_LABELS['mesh-router'] = '路由器';
SERVICE_BOOL_LABELS['power-outlet'] = '插座';
SERVICE_BOOL_LABELS['usb-socket'] = 'USB 插座';
SERVICE_BOOL_LABELS['wireless-charger'] = '无线充电';
SERVICE_BOOL_LABELS['power-bank'] = '充电宝';
SERVICE_BOOL_LABELS['massage-chair'] = '按摩椅';
SERVICE_BOOL_LABELS['massage-gun'] = '筋膜枪';
SERVICE_BOOL_LABELS['hair-dryer'] = '吹风机';
SERVICE_BOOL_LABELS['electric-toothbrush'] = '电动牙刷';
SERVICE_BOOL_LABELS['shaver'] = '剃须刀';
SERVICE_BOOL_LABELS['pet-water-feeder'] = '宠物饮水机';
SERVICE_BOOL_LABELS['pet-camera'] = '宠物摄像头';
SERVICE_BOOL_LABELS['oxygen-pump'] = '氧气泵';
SERVICE_BOOL_LABELS['heating-rod'] = '加热棒';
SERVICE_BOOL_LABELS['gas-water-heater'] = '燃气热水器';
SERVICE_BOOL_LABELS['electric-water-heater'] = '电热水器';
SERVICE_BOOL_LABELS['water-heater'] = '热水器';
SERVICE_BOOL_LABELS['air-conditioner-outlet'] = '空调插座';
SERVICE_BOOL_LABELS['ac-outlet'] = '空调插座';
SERVICE_BOOL_LABELS['air-conditioner-socket'] = '空调插座';
SERVICE_BOOL_LABELS['fahrenheit'] = '华氏温度';
SERVICE_BOOL_LABELS['baby-mode'] = '婴儿模式';
SERVICE_BOOL_LABELS['switch-toggle'] = '开关切换';
SERVICE_BOOL_LABELS['power-waste'] = '功率消耗';
SERVICE_BOOL_LABELS['screen-mode'] = '屏幕模式';
SERVICE_BOOL_LABELS['location-setting'] = '位置设置';
SERVICE_BOOL_LABELS['environment'] = '环境传感';

MIOT_TEXT_DICTIONARY['location'] = '位置';
MIOT_TEXT_DICTIONARY['location setting'] = '位置设置';
MIOT_TEXT_DICTIONARY['utc'] = 'UTC';
MIOT_TEXT_DICTIONARY['origin utc'] = '原始 UTC';
MIOT_TEXT_DICTIONARY['origin'] = '原始';

// —— 单位补充 ——
MIOT_UNIT_DICTIONARY['degree'] = '°';
MIOT_UNIT_DICTIONARY['degrees'] = '°';
MIOT_UNIT_DICTIONARY['kelvin'] = 'K';
MIOT_UNIT_DICTIONARY['days'] = '天';
MIOT_UNIT_DICTIONARY['weeks'] = '周';
MIOT_UNIT_DICTIONARY['months'] = '月';
MIOT_UNIT_DICTIONARY['years'] = '年';
MIOT_UNIT_DICTIONARY['milliseconds'] = '毫秒';
MIOT_UNIT_DICTIONARY['l/min'] = 'L/min';
MIOT_UNIT_DICTIONARY['ml'] = 'mL';
MIOT_UNIT_DICTIONARY['l'] = 'L';
MIOT_UNIT_DICTIONARY['kg'] = 'kg';
MIOT_UNIT_DICTIONARY['g'] = 'g';
MIOT_UNIT_DICTIONARY['kpa'] = 'kPa';
MIOT_UNIT_DICTIONARY['pa'] = 'Pa';
MIOT_UNIT_DICTIONARY['bar'] = 'bar';
MIOT_UNIT_DICTIONARY['mmhg'] = 'mmHg';
MIOT_UNIT_DICTIONARY['v'] = 'V';
MIOT_UNIT_DICTIONARY['a'] = 'A';
MIOT_UNIT_DICTIONARY['w'] = 'W';
MIOT_UNIT_DICTIONARY['wh'] = 'Wh';
MIOT_UNIT_DICTIONARY['mah'] = 'mAh';
MIOT_UNIT_DICTIONARY['m'] = 'm';
MIOT_UNIT_DICTIONARY['cm'] = 'cm';
MIOT_UNIT_DICTIONARY['mm'] = 'mm';
MIOT_UNIT_DICTIONARY['km'] = 'km';
MIOT_UNIT_DICTIONARY['km/h'] = 'km/h';
MIOT_UNIT_DICTIONARY['m/s'] = 'm/s';

// —— 暖风机（xiaomi.heater.ma8 实测补充）——
MIOT_TEXT_DICTIONARY['ntc error'] = '温度传感器故障';
MIOT_TEXT_DICTIONARY['delay'] = '延时';
MIOT_TEXT_DICTIONARY['delay time'] = '延时时间';
MIOT_TEXT_DICTIONARY['delay remain time'] = '剩余延时时间';

// —— 空调插座/空调伴侣（lumi.acpartner.mcn02 实测补充）——
MIOT_TEXT_DICTIONARY['out of matching'] = '未匹配';
MIOT_TEXT_DICTIONARY['matching'] = '匹配中';
MIOT_TEXT_DICTIONARY['ac work mode'] = '空调工作模式';
MIOT_TEXT_DICTIONARY['ac mode with outlet'] = '带插座空调模式';
MIOT_TEXT_DICTIONARY['ac mode without outlet'] = '无插座空调模式';
MIOT_TEXT_DICTIONARY['ac state'] = '空调状态';
MIOT_TEXT_DICTIONARY['brand id'] = '品牌 ID';
MIOT_TEXT_DICTIONARY['remote id'] = '遥控器 ID';
MIOT_TEXT_DICTIONARY['ac type'] = '空调类型';
MIOT_TEXT_DICTIONARY['stateless'] = '无状态';
MIOT_TEXT_DICTIONARY['stateful'] = '有状态';
MIOT_TEXT_DICTIONARY['ac ctrl library'] = '空调控制库';
MIOT_TEXT_DICTIONARY['ac ctrl library crc32'] = '空调控制库校验值';
MIOT_TEXT_DICTIONARY['set ac model'] = '设置空调型号';
MIOT_TEXT_DICTIONARY['set ac ctrl info'] = '设置空调控制信息';
