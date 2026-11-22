import SnowCore
import SpriteKit

/// Draws the snow lying on one ledge on the GPU: the visible height of every column goes into a
/// one-pixel-tall texture and a fragment shader turns it into a soft, shaded snow bank.
final class PileNode: SKSpriteNode {
    /// Snow overlaps the ledge line by this much so it sits on the window edge.
    static let baseInset: CGFloat = 2
    /// Height encoding: one texture step is 0.1pt, so 255 → 25.5pt.
    static let unitsPerPoint: Float = 10

    private static let blank: SKTexture = {
        let t = SKTexture(data: Data([255, 255, 255, 255]), size: CGSize(width: 1, height: 1))
        return t
    }()

    private static let source = """
    void main() {
        vec2 uv = v_tex_coord;
        float h = texture2D(u_heights, vec2(uv.x, 0.5)).r * 25.5;
        float y = uv.y * u_size - u_base;
        float present = step(0.3, h);
        float a = clamp((h - y) * u_px + 0.5, 0.0, 1.0) * present;
        float t = clamp((y + u_base) / (h + u_base + 0.001), 0.0, 1.0);
        vec3 col = mix(vec3(0.80, 0.86, 0.93), vec3(1.0), smoothstep(0.0, 0.75, t));
        float depth = h - y;
        float ridge = (1.0 - smoothstep(0.35, 1.0, depth)) * 0.55;
        float shine = smoothstep(0.9, 1.3, depth) * (1.0 - smoothstep(1.6, 2.3, depth));
        col = mix(col, vec3(0.60, 0.69, 0.82), ridge);
        col = mix(col, vec3(1.0), shine * 0.8);
        gl_FragColor = vec4(col * a, a);
    }
    """

    let kind: LedgeKind
    var dirty = true
    private var lastRender: TimeInterval = 0
    private let heightsUniform = SKUniform(name: "u_heights", texture: PileNode.blank)
    private let sizeUniform = SKUniform(name: "u_size", float: 1)
    private var bytes: [UInt8] = []

    init(kind: LedgeKind) {
        self.kind = kind
        super.init(texture: PileNode.blank, color: .white, size: CGSize(width: 1, height: 1))
        anchorPoint = .zero
        zPosition = 5
        isHidden = true
        let shader = SKShader(source: PileNode.source, uniforms: [
            heightsUniform, sizeUniform,
            SKUniform(name: "u_base", float: Float(PileNode.baseInset)),
            SKUniform(name: "u_px", float: Float(Textures.scale)),
        ])
        self.shader = shader
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func place(_ spec: LedgeSpec) {
        position = CGPoint(x: spec.x0, y: spec.y - PileNode.baseInset)
        let h = CGFloat(spec.maxHeight) + PileNode.baseInset + 3
        if size.width != spec.width || size.height != h {
            size = CGSize(width: spec.width, height: h)
            sizeUniform.floatValue = Float(h)
        }
    }

    func refresh(pile: SnowPile, vis: Visibility, now: TimeInterval, force: Bool = false) {
        guard dirty, force || now - lastRender >= 1.0 / 30 else { return }
        dirty = false
        lastRender = now
        let n = pile.columnCount
        if bytes.count != n * 4 { bytes = [UInt8](repeating: 255, count: n * 4) }
        var any = false
        for c in 0..<n {
            let v = vis.visibleHeight(column: c, height: pile.heights[c])
            let units = UInt8(max(0, min(255, (v * PileNode.unitsPerPoint).rounded())))
            if units > 3 { any = true }
            bytes[c * 4] = units
            bytes[c * 4 + 1] = units
            bytes[c * 4 + 2] = units
        }
        isHidden = !any
        guard any else { return }
        let tex = SKTexture(data: Data(bytes), size: CGSize(width: n, height: 1))
        tex.filteringMode = .linear
        heightsUniform.textureValue = tex
    }
}
