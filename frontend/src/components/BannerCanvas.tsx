import { useRef, type CSSProperties } from 'react';
import { Phone, ArrowRight, ShoppingCart, ExternalLink } from 'lucide-react';
import { snapPosition, type BannerDesign, type CanvasNode } from './bannerDesign';
import type { BannerButton } from './BannerTab';
import './BannerCanvas.css';

interface Props {
  design: BannerDesign; title: string; badge: string; subtitle: string;
  buttons: BannerButton[]; mascot?: string; background: string;
  fontFamily: string; editable?: boolean; selected?: string; snap?: boolean;
  onInteractionStart?: () => void; onInteractionEnd?: () => void;
  onSelect?: (id: string) => void; onChange?: (design: BannerDesign) => void;
}

export function BannerCanvas(props: Props) {
  const canvas = useRef<HTMLDivElement>(null);
  const drag = useRef<{ id: string; x: number; y: number; node: CanvasNode; width: number; height: number } | null>(null);
  const resize = useRef<{ corner: string; x: number; y: number; node: CanvasNode } | null>(null);
  const active = props.selected ? props.design.nodes[props.selected] : undefined;
  const activeVisible = props.selected === "mascot" ? !!props.mascot : props.selected?.startsWith("button") ? !!props.buttons[Number(props.selected.slice(6))] : !!({ title: props.title, badge: props.badge, subtitle: props.subtitle } as Record<string, string>)[props.selected || ""];
  const texts: Record<string, string> = { title: props.title, badge: props.badge, subtitle: props.subtitle };
  const icons = { phone: Phone, arrow: ArrowRight, cart: ShoppingCart, external: ExternalLink };
  return <div ref={canvas} className={`banner-canvas ${props.editable && props.snap ? 'show-grid' : ''}`}
    style={{ background: props.background }} aria-label="Canvas banner">
    {Object.entries(props.design.nodes).map(([id, node]) => {
      const button = id.startsWith('button') ? props.buttons[Number(id.slice(6))] : undefined;
      const text = button?.text ?? texts[id];
      if (id === 'mascot' ? !props.mascot : !text) return null;
      const Icon = node.icon && node.icon !== 'none' ? icons[node.icon] : null;
      const style: CSSProperties = {
        left: `${node.x}%`, top: `${node.y}%`, width: `${node.width}%`, height: `${node.height}%`,
        fontFamily: `'${node.fontFamily || props.fontFamily}', sans-serif`,
        fontSize: `${(node.fontSize || 12) / 3.6}cqw`, fontWeight: node.fontWeight || 400,
        color: node.color || '#ffffff', textAlign: node.align || 'left',
        ...(!button && id !== 'mascot' ? { display: 'flex', flexDirection: 'column' as const, justifyContent: node.verticalAlign === 'center' ? 'center' : node.verticalAlign === 'bottom' ? 'flex-end' : 'flex-start' } : {}),
        background: node.gradient ? `linear-gradient(135deg, ${node.gradient})` : node.background,
        borderRadius: `${(node.radius || 0) / 3.6}cqw`,
      };
      return <div key={id} style={style}
        className={`canvas-node ${id === 'mascot' ? 'canvas-mascot' : button ? 'canvas-cta' : 'canvas-text'} ${props.editable ? 'draggable' : ''} ${props.editable && props.selected === id ? 'selected' : ''}`}
        role={props.editable ? 'button' : undefined} tabIndex={props.editable ? 0 : undefined}
        aria-label={props.editable ? `Chỉnh ${id}` : undefined}
        onPointerDown={event => {
          if (!props.editable || event.button !== 0 || !canvas.current) return;
          event.preventDefault(); event.currentTarget.setPointerCapture(event.pointerId);
          props.onSelect?.(id); props.onInteractionStart?.();
          const rect = canvas.current.getBoundingClientRect();
          drag.current = { id, x: event.clientX, y: event.clientY, node: { ...node }, width: rect.width, height: rect.height };
        }}
        onPointerMove={event => {
          const current = drag.current;
          if (!current || current.id !== id) return;
          const next = snapPosition(current.node,
            current.node.x + (event.clientX - current.x) / current.width * 100,
            current.node.y + (event.clientY - current.y) / current.height * 100, props.snap && !event.altKey);
          props.onChange?.({ ...props.design, nodes: { ...props.design.nodes, [id]: next } });
        }}
        onPointerUp={() => { drag.current = null; props.onInteractionEnd?.(); }} onPointerCancel={() => { drag.current = null; props.onInteractionEnd?.(); }}
        onKeyDown={event => {
          if (!props.editable) return;
          if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); props.onSelect?.(id); }
          const movement: Record<string, [number, number]> = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] };
          const delta = movement[event.key];
          if (!delta) return;
          event.preventDefault(); props.onSelect?.(id);
          const step = event.shiftKey ? 5 : 1;
          props.onChange?.({ ...props.design, nodes: { ...props.design.nodes, [id]: snapPosition(node, node.x + delta[0] * step, node.y + delta[1] * step, false) } });
        }}>
        {id === 'mascot' ? <img src={props.mascot} alt="Mascot banner" draggable={false}
          style={{ transform: node.flip ? 'scaleX(-1)' : undefined }}
          onError={event => { if (!event.currentTarget.src.endsWith('/image_character.png')) event.currentTarget.src = '/image_character.png'; }} />
          : button ? <><span>{text}</span>{Icon && <Icon size="1em" />}</>
          : text.split('\n').map((line, index) => <div key={index} style={{ color: node.lineColors?.[index] || node.color }}>{line || '\u00a0'}</div>)}
      </div>;
    })}
    {props.editable && active && activeVisible && <div className="canvas-selection" style={{ left: `${active.x}%`, top: `${active.y}%`, width: `${active.width}%`, height: `${active.height}%` }}>
      {['nw', 'ne', 'sw', 'se'].map(corner => <button key={corner} type="button" className={`canvas-resize-handle ${corner}`} aria-label={`Co giãn ${props.selected} góc ${corner}`}
        onPointerDown={event => {
          if (event.button !== 0) return;
          event.preventDefault(); event.stopPropagation(); event.currentTarget.setPointerCapture(event.pointerId);
          props.onInteractionStart?.(); resize.current = { corner, x: event.clientX, y: event.clientY, node: { ...active } };
        }}
        onPointerMove={event => {
          const start = resize.current;
          if (!start || !canvas.current || !props.selected) return;
          const rect = canvas.current.getBoundingClientRect();
          const dx = (event.clientX - start.x) / rect.width * 100;
          const dy = (event.clientY - start.y) / rect.height * 100;
          const quantize = (n: number) => props.snap && !event.altKey ? Math.round(n / 2) * 2 : n;
          const left = start.corner.includes('w') ? Math.max(0, Math.min(start.node.x + start.node.width - 5, quantize(start.node.x + dx))) : start.node.x;
          const top = start.corner.includes('n') ? Math.max(0, Math.min(start.node.y + start.node.height - 5, quantize(start.node.y + dy))) : start.node.y;
          const right = start.corner.includes('e') ? Math.min(100, Math.max(left + 5, quantize(start.node.x + start.node.width + dx))) : start.node.x + start.node.width;
          const bottom = start.corner.includes('s') ? Math.min(100, Math.max(top + 5, quantize(start.node.y + start.node.height + dy))) : start.node.y + start.node.height;
          props.onChange?.({ ...props.design, nodes: { ...props.design.nodes, [props.selected]: { ...start.node, x: left, y: top, width: right - left, height: bottom - top } } });
        }}
        onPointerUp={() => { resize.current = null; props.onInteractionEnd?.(); }}
        onPointerCancel={() => { resize.current = null; props.onInteractionEnd?.(); }} />)}
    </div>}
  </div>;
}

export function CanvasInspector({ design, selected, text, fonts, onChange }: {
  design: BannerDesign; selected: string; text: string; fonts: string[]; onChange: (design: BannerDesign) => void;
}) {
  const node = design.nodes[selected];
  if (!node) return null;
  const update = (patch: Partial<CanvasNode>) => {
    const next = { ...node, ...patch };
    onChange({ ...design, nodes: { ...design.nodes, [selected]: snapPosition(next, next.x, next.y, false) } });
  };
  return <div className="canvas-inspector">
    <strong>Định dạng: {({ title: 'Tiêu đề', badge: 'Tag', subtitle: 'Mô tả', mascot: 'Mascot' } as Record<string, string>)[selected] || `Nút ${Number(selected.slice(6)) + 1}`}</strong>
    <div className="canvas-tool-grid">
      {(['x', 'y', 'width', 'height'] as const).map(field => <label key={field}>
        {({ x: 'Vị trí X (%)', y: 'Vị trí Y (%)', width: 'Rộng (%)', height: 'Cao (%)' })[field]}
        <input type="number" min={field === 'width' || field === 'height' ? 5 : 0} max={100}
          value={node[field]} onChange={e => update({ [field]: Math.max(field === 'width' || field === 'height' ? 5 : 0, Math.min(100, Number(e.target.value))) })} />
      </label>)}
    </div>
    {selected === 'mascot' ? <>
      <label>Kích thước mascot ({Math.round(node.width / 30 * 100)}%)
        <input type="range" min={25} max={250} step={5} value={node.width / 30 * 100} onChange={e => {
          const ratio = Number(e.target.value) / 100;
          update({ width: 30 * ratio, height: Math.min(100, 86 * ratio) });
        }} />
      </label>
      <label className="canvas-toggle"><input type="checkbox" checked={node.flip || false} onChange={e => update({ flip: e.target.checked })} />Lật ảnh ngang</label>
    </> : <>
      <div className="canvas-tool-grid">
        <label>Font<select value={node.fontFamily || ""} onChange={e => update({ fontFamily: e.target.value || undefined })}><option value="">Font mặc định ({fonts[0]})</option>{fonts.map(font => <option key={font}>{font}</option>)}</select></label>
        <label>Cỡ chữ<input type="number" min={8} max={48} value={node.fontSize || 12} onChange={e => update({ fontSize: Math.max(8, Math.min(48, Number(e.target.value))) })} /></label>
        <label>Độ đậm<select value={node.fontWeight || 400} onChange={e => update({ fontWeight: Number(e.target.value) })}>{[400, 500, 600, 700, 800, 900].map(weight => <option key={weight} value={weight}>{weight}</option>)}</select></label>
        <label>Căn chữ<select value={node.align || 'left'} onChange={e => update({ align: e.target.value as CanvasNode['align'] })}><option value="left">Trái</option><option value="center">Giữa</option><option value="right">Phải</option></select></label>
        {!selected.startsWith('button') && <label>Căn dọc<select value={node.verticalAlign || 'top'} onChange={e => update({ verticalAlign: e.target.value as CanvasNode['verticalAlign'] })}><option value="top">Trên</option><option value="center">Giữa</option><option value="bottom">Dưới</option></select></label>}
        <label>Màu chữ<CanvasColor value={node.color || '#ffffff'} onChange={color => update({ color })} /></label>
      </div>
      {!selected.startsWith('button') && text.includes('\n') && <div className="canvas-tool-grid">{text.split('\n').map((_, index) => <label key={index}>Màu dòng {index + 1}
        <input type="color" value={node.lineColors?.[index] || node.color || '#ffffff'} onChange={e => {
          const colors = [...(node.lineColors || [])]; colors[index] = e.target.value; update({ lineColors: colors });
        }} />
      </label>)}</div>}
      {selected.startsWith('button') && <div className="canvas-tool-grid">
        <label>Nền nút<select value={node.gradient ? 'gradient' : node.background === 'transparent' ? 'outline' : 'solid'} onChange={e => update({ gradient: e.target.value === 'gradient' ? '#2563eb,#7c3aed' : undefined, background: e.target.value === 'outline' ? 'transparent' : '#ffffff' })}><option value="solid">Màu thuần</option><option value="gradient">Gradient</option><option value="outline">Viền trong suốt</option></select></label>
        <label>Màu nền<input type="color" value={/^#[0-9a-f]{6}$/i.test(node.background || '') ? node.background : '#ffffff'} onChange={e => update({ background: e.target.value, gradient: undefined })} /></label>
        {node.gradient && <label>Hai màu Gradient<input value={node.gradient} pattern="#[0-9a-fA-F]{6},#[0-9a-fA-F]{6}" onChange={e => update({ gradient: e.target.value })} /></label>}
        <label>Bo góc<select value={node.radius ?? 20} onChange={e => update({ radius: Number(e.target.value) })}><option value={0}>Vuông</option><option value={8}>Bo nhẹ 8px</option><option value={20}>Viên thuốc</option></select></label>
        <label>Icon<select value={node.icon || 'none'} onChange={e => update({ icon: e.target.value as CanvasNode['icon'] })}><option value="none">Không có</option><option value="phone">Điện thoại</option><option value="arrow">Mũi tên</option><option value="cart">Giỏ hàng</option><option value="external">Liên kết</option></select></label>
      </div>}
    </>}
  </div>;
}

function CanvasColor({ value, onChange }: { value: string; onChange: (color: string) => void }) {
  const colors = [['#ffffff', 'Trắng'], ['#111827', 'Đen'], ['#facc15', 'Vàng gold'], ['#2563eb', 'Xanh dương'], ['#10b981', 'Xanh lá']];
  return <span className="canvas-color-control">
    <span className="canvas-color-value"><input type="color" aria-label="Chọn màu chữ" value={/^#[0-9a-f]{6}$/i.test(value) ? value : '#ffffff'} onChange={e => onChange(e.target.value)} /><span>{value.toUpperCase()}</span></span>
    <span className="canvas-color-swatches">{colors.map(([color, name]) => <button type="button" key={color} title={name} aria-label={`Màu ${name}`} aria-pressed={value.toLowerCase() === color} style={{ background: color }} onClick={() => onChange(color)} />)}</span>
  </span>;
}
