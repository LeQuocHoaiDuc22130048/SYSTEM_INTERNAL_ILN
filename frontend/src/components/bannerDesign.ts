export type CanvasElement = 'badge' | 'title' | 'subtitle' | 'mascot' | `button${number}`;
export interface CanvasNode {
  x: number; y: number; width: number; height: number;
  fontFamily?: string; fontSize?: number; fontWeight?: number;
  verticalAlign?: 'top' | 'center' | 'bottom';
  color?: string; align?: 'left' | 'center' | 'right'; lineColors?: string[];
  background?: string; gradient?: string; radius?: number;
  icon?: 'none' | 'phone' | 'arrow' | 'cart' | 'external'; flip?: boolean;
}
export interface BannerDesign { version: 1; nodes: Record<string, CanvasNode> }

export function defaultDesign(): BannerDesign {
  return { version: 1, nodes: {
    badge: { x: 5, y: 8, width: 58, height: 16, fontSize: 10, fontWeight: 700, color: '#ffffff', background: '#ffffff33', radius: 16 },
    title: { x: 5, y: 28, width: 62, height: 23, fontSize: 18, fontWeight: 800, color: '#ffffff' },
    subtitle: { x: 5, y: 53, width: 62, height: 26, fontSize: 11, fontWeight: 400, color: '#ffffff' },
    mascot: { x: 68, y: 12, width: 30, height: 86, flip: false },
    button0: { x: 5, y: 80, width: 31, height: 16, fontSize: 11, fontWeight: 700, color: '#2563eb', background: '#ffffff', radius: 20, icon: 'arrow' },
    button1: { x: 38, y: 80, width: 28, height: 16, fontSize: 11, fontWeight: 700, color: '#ffffff', background: '#2563eb', radius: 8, icon: 'phone' },
    button2: { x: 68, y: 80, width: 28, height: 16, fontSize: 11, fontWeight: 700, color: '#ffffff', background: '#2563eb', radius: 8, icon: 'arrow' },
  } };
}

export function parseDesign(raw?: string | null): BannerDesign | null {
  if (!raw) return null;
  try {
    const value = JSON.parse(raw);
    if (value.version !== 1 || !value.nodes || Array.isArray(value.nodes)) return null;
    const fallback = defaultDesign().nodes;
    const nodes: Record<string, CanvasNode> = {};
    for (const [id, node] of Object.entries(value.nodes)) {
      if (!(id in fallback) || !node || typeof node !== 'object') continue;
      const n = node as CanvasNode;
      if (![n.x, n.y, n.width, n.height].every(Number.isFinite)) continue;
      const width = Math.max(5, Math.min(100, n.width));
      const height = Math.max(5, Math.min(100, n.height));
      nodes[id] = { ...fallback[id], ...n, width, height,
        x: Math.max(0, Math.min(100 - width, n.x)), y: Math.max(0, Math.min(100 - height, n.y)) };
    }
    return Object.keys(nodes).length ? { version: 1, nodes: { ...fallback, ...nodes } } : null;
  } catch { return null; }
}

export function snapPosition(node: CanvasNode, x: number, y: number, snap = true): CanvasNode {
  if (snap) {
    x = Math.abs(x + node.width / 2 - 50) < 2 ? 50 - node.width / 2 : Math.round(x / 2) * 2;
    y = Math.abs(y + node.height / 2 - 50) < 2 ? 50 - node.height / 2 : Math.round(y / 2) * 2;
  }
  return { ...node, x: Math.max(0, Math.min(100 - node.width, x)), y: Math.max(0, Math.min(100 - node.height, y)) };
}

export function templateDesign(template: 'promotion' | 'information' | 'image'): BannerDesign {
  const design = defaultDesign();
  if (template === 'promotion') {
    design.nodes.title = { ...design.nodes.title, x: 5, y: 24, width: 90, height: 26, align: 'center', fontSize: 24, color: '#fde047' };
    design.nodes.badge = { ...design.nodes.badge, x: 25, width: 50, align: 'center' };
    design.nodes.subtitle = { ...design.nodes.subtitle, x: 10, y: 53, width: 80, height: 20, align: 'center' };
    design.nodes.button0 = { ...design.nodes.button0, x: 32, y: 78, width: 36, height: 18, background: '#fde047', color: '#172554' };
  } else if (template === 'image') {
    design.nodes.button0 = { ...design.nodes.button0, x: 32, y: 78, width: 36, height: 18, background: '#2563eb', color: '#ffffff' };
  }
  return design;
}

export function removeButtonDesign(design: BannerDesign, index: number): BannerDesign {
  const nodes = { ...design.nodes };
  for (let i = index; i < 2; i++) nodes[`button${i}`] = { ...nodes[`button${i + 1}`] };
  nodes.button2 = { ...defaultDesign().nodes.button2 };
  return { ...design, nodes };
}

export function legacyDesign(banner: { imagePosition?: string; buttonPosition?: string; buttonTop?: number | null; buttonLeft?: number | null; buttonRight?: number | null; buttonBottom?: number | null }): BannerDesign {
  const design = defaultDesign();
  const position = banner.imagePosition || 'RIGHT';
  if (position === 'LEFT') {
    design.nodes.mascot.x = 2;
    for (const id of ['badge', 'title', 'subtitle']) { design.nodes[id].x = 36; design.nodes[id].width = 60; }
  } else if (position === 'NONE') {
    for (const id of ['badge', 'title', 'subtitle']) design.nodes[id].width = 90;
  } else if (position === 'RIGHT_TOP') {
    design.nodes.mascot = { x: 74, y: 4, width: 22, height: 44 };
  }
  for (let i = 0; i < 3; i++) {
    const node = design.nodes[`button${i}`];
    const pos = banner.buttonPosition || 'BOTTOM_LEFT';
    const x = pos === 'CUSTOM' ? banner.buttonLeft != null ? banner.buttonLeft / 360 * 100 : banner.buttonRight != null ? 100 - node.width - banner.buttonRight / 360 * 100 : node.x
      : pos.endsWith('CENTER') ? 50 - node.width / 2 : pos.endsWith('RIGHT') ? 96 - node.width : node.x;
    const y = pos === 'CUSTOM' ? banner.buttonTop != null ? banner.buttonTop / 180 * 100 : banner.buttonBottom != null ? 100 - node.height - banner.buttonBottom / 180 * 100 : node.y
      : pos.startsWith('TOP') ? 4 + i * (node.height + 2) : node.y;
    design.nodes[`button${i}`] = snapPosition(node, x, y, false);
  }
  return design;
}

/** Only report success when the server returns the exact custom settings sent. */
export function savedDesignMatches(raw: unknown, expected: BannerDesign): boolean {
  if (typeof raw !== 'string') return false;
  try {
    const saved = JSON.parse(raw);
    return saved.version === expected.version && Object.entries(expected.nodes).every(([id, node]) =>
      Object.entries(node).every(([field, value]) =>
        JSON.stringify(saved.nodes?.[id]?.[field]) === JSON.stringify(value)));
  } catch { return false; }
}
