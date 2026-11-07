.pragma library

// The settings search: one entry per row (and per keyboard shortcut), scored the way iNiR's SettingsSearchRegistry does
// (snowarch/inir): every word of the query has to match somewhere; a title that starts with it beats one that contains
// it, which beats the hint, the group, the page and the option names.

// pages: [{ name, groups: [{ title, rows: [{ label, hint, opts }] }] }], binds: [{ name, key }]
function buildIndex(pages, binds) {
    const out = []
    for (let p = 0; p < pages.length; p++) {
        const pg = pages[p]
        for (let g = 0; g < (pg.groups ?? []).length; g++) {
            const grp = pg.groups[g]
            for (let r = 0; r < grp.rows.length; r++) {
                const row = grp.rows[r]
                if (!row.label || row.t === "overview") continue
                const opts = (row.opts ?? []).map(o => typeof o === "object" ? String(o.l) : String(o)).join(" ")
                out.push({ id: "p" + p + "g" + g + "r" + r, page: p, pageName: pg.name, group: grp.title, label: row.label,
                    hint: row.hint ?? "", words: opts })
            }
        }
    }
    for (const b of (binds ?? []))
        out.push({ id: "bind:" + b.key, page: pages.findIndex(x => x.name === "Controls"), pageName: "Controls", group: "Keyboard shortcuts",
            label: b.name, hint: b.key.replace("Mod", "Super"), words: b.key })
    return out
}

function search(index, query) {
    const terms = String(query ?? "").toLowerCase().split(/\s+/).filter(t => t.length > 0)
    if (terms.length === 0) return []
    const out = []
    for (const e of index) {
        const label = e.label.toLowerCase(), hint = e.hint.toLowerCase(), group = (e.group ?? "").toLowerCase()
        const page = e.pageName.toLowerCase(), words = (e.words ?? "").toLowerCase()
        let score = 0, hit = 0
        for (const t of terms) {
            const l = label.indexOf(t), h = hint.indexOf(t), g = group.indexOf(t), p = page.indexOf(t), w = words.indexOf(t)
            if (l < 0 && h < 0 && g < 0 && p < 0 && w < 0) continue
            hit++
            if (l === 0) score += 1000; else if (l > 0) score += 500 - Math.min(l, 100)
            if (h === 0) score += 300; else if (h > 0) score += 150 - Math.min(h, 50)
            if (g >= 0) score += 100
            if (p >= 0) score += 60
            if (w >= 0) score += 200
        }
        if (hit === terms.length) out.push({ entry: e, score: score })
    }
    out.sort((a, b) => b.score - a.score)
    return out.slice(0, 40).map(x => x.entry)
}

// The text as StyledText with every word of the query in bold and the given colour (a "#rrggbb" string).
function mark(text, query, color) {
    const esc = x => x.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    const low = String(text).toLowerCase()
    const spans = []
    for (const t of String(query ?? "").toLowerCase().split(/\s+/).filter(t => t.length > 0)) {
        let at = low.indexOf(t)
        while (at >= 0) { spans.push([at, at + t.length]); at = low.indexOf(t, at + t.length) }
    }
    spans.sort((a, b) => a[0] - b[0])
    const merged = []
    for (const s of spans) {
        if (merged.length > 0 && s[0] <= merged[merged.length - 1][1]) merged[merged.length - 1][1] = Math.max(merged[merged.length - 1][1], s[1])
        else merged.push([s[0], s[1]])
    }
    let out = "", pos = 0
    for (const m of merged) {
        out += esc(text.slice(pos, m[0])) + '<font color="' + color + '"><b>' + esc(text.slice(m[0], m[1])) + "</b></font>"
        pos = m[1]
    }
    return out + esc(text.slice(pos))
}
