#!/usr/bin/env python3
"""Deterministically generates outlined-nested.pdf: a minimal 3-page PDF whose
/Outlines tree exercises the OutlineReader contract (P1-02/ADR-013) —
nesting, an XYZ destination carrying an explicit zoom, and a structural
heading with no destination. Synthetic content only (Constitution Art. 15).

Rerun from the repo root to reproduce byte-for-byte:
    python3 Fixtures/pdf-corpus/synthetic/generate_outlined.py
Expected values live in Fixtures/pdf-corpus/manifest.json (row id
"synthetic-outlined-nested"); update that row if this file changes.
"""

import os

OUT = os.path.join(os.path.dirname(__file__), "outlined-nested.pdf")

# Object numbers:
# 1 Catalog, 2 Pages, 3-5 Page 0-2, 6-8 Content streams,
# 9 Outlines root, 10 "Chapter 1", 11 "Section 1.1", 12 "Unlinked Heading",
# 13 Font
PAGE = (b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]"
        b" /Resources << /Font << /F1 13 0 R >> >> /Contents %d 0 R >>")
objects = {
    1: b"<< /Type /Catalog /Pages 2 0 R /Outlines 9 0 R /PageMode /UseOutlines >>",
    2: b"<< /Type /Pages /Kids [3 0 R 4 0 R 5 0 R] /Count 3 >>",
    3: PAGE % 6,
    4: PAGE % 7,
    5: PAGE % 8,
    13: b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    9: b"<< /Type /Outlines /First 10 0 R /Last 12 0 R /Count 3 >>",
    # XYZ dest: left top zoom -- zoom 1.5 on the child is the value the
    # OutlineReader zoom-target test pins.
    10: (b"<< /Title (Chapter 1) /Parent 9 0 R /Next 12 0 R"
         b" /First 11 0 R /Last 11 0 R /Count 1"
         b" /Dest [3 0 R /XYZ 0 792 null] >>"),
    11: (b"<< /Title (Section 1.1) /Parent 10 0 R"
         b" /Dest [5 0 R /XYZ 0 792 1.5] >>"),
    12: b"<< /Title (Unlinked Heading) /Parent 9 0 R /Prev 10 0 R >>",
}
for num, page_label in ((6, b"Page 1"), (7, b"Page 2"), (8, b"Page 3")):
    stream = b"BT /F1 12 Tf 72 720 Td (" + page_label + b") Tj ET"
    objects[num] = (b"<< /Length %d >>\nstream\n" % len(stream)) + stream + b"\nendstream"

body = b"%PDF-1.4\n"
offsets = {}
for num in sorted(objects):
    offsets[num] = len(body)
    body += b"%d 0 obj\n" % num + objects[num] + b"\nendobj\n"

xref_offset = len(body)
count = len(objects) + 1
xref = b"xref\n0 %d\n0000000000 65535 f \n" % count
for num in sorted(objects):
    xref += b"%010d 00000 n \n" % offsets[num]
trailer = (b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n"
           % (count, xref_offset))

with open(OUT, "wb") as f:
    f.write(body + xref + trailer)
print("wrote", OUT)
