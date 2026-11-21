export interface DeviceInfo {
  id: string; // UUID
  deviceId: string; // User-facing ID, e.g. ATT-FREAD-01
  name: string;
  type: string;
  status: 'ONLINE' | 'OFFLINE';
  ipAddress: string;
  lastActiveAt: string | null;
  pingMs: number;
  version: string;
  platform?: string;
  connectionType?: string;
}

export type ConnectionCategory = 'HARDWARE' | 'MOBILE_APP';
export type ConnectionFilter = 'ALL' | ConnectionCategory;
export type DeviceStatusFilter = 'ALL' | 'ONLINE' | 'OFFLINE';
export type DevicePlatform = 'ANDROID' | 'IOS' | 'WEB' | 'MOBILE';

const IPV4_WITH_OPTIONAL_PORT_REGEX =
  /^(25[0-5]|2[0-4]\d|1?\d?\d)(\.(25[0-5]|2[0-4]\d|1?\d?\d)){3}(:\d{1,5})?$/;

/**
 * Checks whether an address string represents a real static IPv4/IPv6 address
 * rather than a label like "Mobile / App", "Android", "N/A", or empty string.
 */
export function isStaticIpAddress(ipAddress?: string | null): boolean {
  const value = (ipAddress ?? '').trim();
  if (!value) return false;
  if (IPV4_WITH_OPTIONAL_PORT_REGEX.test(value)) return true;

  // Accept IPv6 addresses (e.g. ::1, fe80::1, 2001:db8::1) while excluding "http://" or labels
  if (value.includes(':') && !value.includes(' ') && /^[0-9a-fA-F:]+$/.test(value)) {
    return value.split(':').length >= 3;
  }

  return false;
}

/**
 * Classifies a device into physical hardware (static IP) vs personal Mobile/App session.
 */
export function getDeviceConnectionCategory(
  device: Pick<DeviceInfo, 'ipAddress' | 'type' | 'platform' | 'connectionType'>
): ConnectionCategory {
  const explicit = (device.connectionType ?? '').trim().toUpperCase();
  if (explicit === 'HARDWARE' || explicit === 'STATIC_IP') return 'HARDWARE';
  if (explicit === 'MOBILE' || explicit === 'MOBILE_APP' || explicit === 'APP') return 'MOBILE_APP';

  if (isStaticIpAddress(device.ipAddress)) {
    return 'HARDWARE';
  }

  return 'MOBILE_APP';
}

/**
 * Detects client platform (Android / iOS / Web / Mobile fallback) for Mobile/App sessions.
 */
export function detectDevicePlatform(
  device: Pick<DeviceInfo, 'ipAddress' | 'deviceId' | 'name' | 'version' | 'platform'>
): DevicePlatform {
  const explicitPlatform = (device.platform ?? '').trim().toUpperCase();
  if (explicitPlatform === 'ANDROID') return 'ANDROID';
  if (explicitPlatform === 'IOS') return 'IOS';
  if (explicitPlatform === 'WEB') return 'WEB';

  const haystack = [
    device.ipAddress,
    device.deviceId,
    device.name,
    device.version,
  ]
    .filter(Boolean)
    .join(' ')
    .toLowerCase();

  if (/\b(ios|iphone|ipad|ipod|darwin|apple|safari)\b/i.test(haystack) || /iphone|ipad|ios/i.test(haystack)) {
    return 'IOS';
  }

  if (
    /\b(android|apk|samsung|xiaomi|oppo|vivo|realme|pixel|redmi|huawei)\b/i.test(haystack) ||
    /android|flutter-mobile/i.test(haystack)
  ) {
    return 'ANDROID';
  }

  if (/\b(web|browser|chrome|firefox|edge|webapp|desktop|macbook|windows)\b/i.test(haystack) || /web-browser/i.test(haystack)) {
    return 'WEB';
  }

  return 'MOBILE';
}

export interface DeviceStats {
  total: number;
  online: number;
  offline: number;
  avgLatency: number;
  hardwareCount: number;
  mobileAppCount: number;
}

export function computeDeviceStats(devices: DeviceInfo[]): DeviceStats {
  const total = devices.length;
  const online = devices.filter((d) => d.status === 'ONLINE').length;
  const offline = total - online;

  const onlineDevices = devices.filter((d) => d.status === 'ONLINE' && d.pingMs > 0);
  const avgLatency =
    onlineDevices.length > 0
      ? Math.round(onlineDevices.reduce((sum, d) => sum + d.pingMs, 0) / onlineDevices.length)
      : 0;

  let hardwareCount = 0;
  let mobileAppCount = 0;
  for (const device of devices) {
    if (getDeviceConnectionCategory(device) === 'HARDWARE') {
      hardwareCount += 1;
    } else {
      mobileAppCount += 1;
    }
  }

  return { total, online, offline, avgLatency, hardwareCount, mobileAppCount };
}

export interface DeviceFilterOptions {
  searchTerm: string;
  selectedType: string;
  connectionFilter: ConnectionFilter;
  statusFilter: DeviceStatusFilter;
  sortByLatency?: boolean;
}

export function filterDevices(devices: DeviceInfo[], options: DeviceFilterOptions): DeviceInfo[] {
  const term = options.searchTerm.toLowerCase().trim();

  const matched = devices.filter((device) => {
    const platformLabel =
      getDeviceConnectionCategory(device) === 'MOBILE_APP' ? detectDevicePlatform(device).toLowerCase() : '';

    const matchesSearch =
      !term ||
      device.name.toLowerCase().includes(term) ||
      device.deviceId.toLowerCase().includes(term) ||
      (device.ipAddress ?? '').toLowerCase().includes(term) ||
      platformLabel.includes(term);

    const matchesType = options.selectedType === 'ALL' || device.type === options.selectedType;

    const matchesConnection =
      options.connectionFilter === 'ALL' ||
      getDeviceConnectionCategory(device) === options.connectionFilter;

    const matchesStatus = options.statusFilter === 'ALL' || device.status === options.statusFilter;

    return matchesSearch && matchesType && matchesConnection && matchesStatus;
  });

  if (options.sortByLatency) {
    return [...matched].sort((a, b) => (b.pingMs || 0) - (a.pingMs || 0));
  }

  return matched;
}

