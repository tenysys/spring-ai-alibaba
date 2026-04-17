from __future__ import annotations

from pathlib import Path
from xml.sax.saxutils import escape
import re
import zipfile


BASE_DIR = Path(__file__).resolve().parent
MD_PATH = BASE_DIR / "数据库运行设计.md"
DOCX_PATH = BASE_DIR / "数据库运行设计_优化版.docx"
TMP_DOCX_PATH = BASE_DIR / "database_runtime_design_tmp.docx"


def clean_inline(text: str) -> str:
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r"\1（\2）", text)
    text = text.replace("`", "")
    text = text.replace("**", "")
    text = text.replace("__", "")
    return text.strip()


def parse_md(lines: list[str]) -> list[tuple]:
    blocks: list[tuple] = []
    i = 0
    while i < len(lines):
        raw = lines[i].rstrip("\n")
        stripped = raw.strip()

        if not stripped:
            blocks.append(("blank",))
            i += 1
            continue

        m = re.match(r"^(#{1,6})\s+(.+)$", stripped)
        if m:
            blocks.append(("heading", len(m.group(1)), clean_inline(m.group(2))))
            i += 1
            continue

        if stripped.startswith("|"):
            table_lines = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                table_lines.append(lines[i].strip())
                i += 1

            rows = []
            for line in table_lines:
                if re.match(r"^\|(?:\s*:?-+:?\s*\|)+$", line):
                    continue
                cells = [clean_inline(x.strip()) for x in line.strip("|").split("|")]
                rows.append(cells)
            if rows:
                blocks.append(("table", rows))
            continue

        m = re.match(r"^[-*]\s+(.+)$", stripped)
        if m:
            blocks.append(("para", f"• {clean_inline(m.group(1))}"))
            i += 1
            continue

        m = re.match(r"^(\d+\.)\s+(.+)$", stripped)
        if m:
            blocks.append(("para", f"{m.group(1)} {clean_inline(m.group(2))}"))
            i += 1
            continue

        blocks.append(("para", clean_inline(stripped)))
        i += 1

    return blocks


def p_style(style: str, text: str) -> str:
    return (
        "<w:p>"
        f"<w:pPr><w:pStyle w:val=\"{style}\"/></w:pPr>"
        f"<w:r><w:t xml:space=\"preserve\">{escape(text)}</w:t></w:r>"
        "</w:p>"
    )


def blank_p() -> str:
    return "<w:p/>"


def tbl(rows: list[list[str]]) -> str:
    cols = max(len(r) for r in rows)
    grid = "".join("<w:gridCol w:w=\"1800\"/>" for _ in range(cols))
    trs = []
    for r_idx, row in enumerate(rows):
        tcs = []
        for c_idx in range(cols):
            value = row[c_idx] if c_idx < len(row) else ""
            shade = (
                "<w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"D9E2F3\"/>"
                if r_idx == 0
                else ""
            )
            bold_open = "<w:b/>" if r_idx == 0 else ""
            tcs.append(
                "<w:tc>"
                "<w:tcPr><w:tcW w:w=\"1800\" w:type=\"dxa\"/></w:tcPr>"
                "<w:p>"
                f"<w:pPr>{shade}</w:pPr>"
                "<w:r>"
                f"<w:rPr>{bold_open}</w:rPr>"
                f"<w:t xml:space=\"preserve\">{escape(value)}</w:t>"
                "</w:r>"
                "</w:p>"
                "</w:tc>"
            )
        trs.append("<w:tr>" + "".join(tcs) + "</w:tr>")
    return (
        "<w:tbl>"
        "<w:tblPr>"
        "<w:tblStyle w:val=\"TableGrid\"/>"
        "<w:tblW w:w=\"0\" w:type=\"auto\"/>"
        "<w:tblBorders>"
        "<w:top w:val=\"single\" w:sz=\"4\" w:space=\"0\" w:color=\"auto\"/>"
        "<w:left w:val=\"single\" w:sz=\"4\" w:space=\"0\" w:color=\"auto\"/>"
        "<w:bottom w:val=\"single\" w:sz=\"4\" w:space=\"0\" w:color=\"auto\"/>"
        "<w:right w:val=\"single\" w:sz=\"4\" w:space=\"0\" w:color=\"auto\"/>"
        "<w:insideH w:val=\"single\" w:sz=\"4\" w:space=\"0\" w:color=\"auto\"/>"
        "<w:insideV w:val=\"single\" w:sz=\"4\" w:space=\"0\" w:color=\"auto\"/>"
        "</w:tblBorders>"
        "</w:tblPr>"
        f"<w:tblGrid>{grid}</w:tblGrid>"
        + "".join(trs)
        + "</w:tbl>"
    )


def build_document(blocks: list[tuple]) -> str:
    body = []
    for block in blocks:
        kind = block[0]
        if kind == "blank":
            body.append(blank_p())
        elif kind == "heading":
            _, level, text = block
            style = "Title" if level == 1 else f"Heading{min(level - 1, 3)}"
            body.append(p_style(style, text))
        elif kind == "table":
            body.append(tbl(block[1]))
            body.append(blank_p())
        else:
            body.append(p_style("Normal", block[1]))

    sect = (
        "<w:sectPr>"
        "<w:pgSz w:w=\"11906\" w:h=\"16838\"/>"
        "<w:pgMar w:top=\"1440\" w:right=\"1800\" w:bottom=\"1440\" w:left=\"1800\" "
        "w:header=\"851\" w:footer=\"992\" w:gutter=\"0\"/>"
        "</w:sectPr>"
    )

    return (
        "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        "<w:document xmlns:wpc=\"http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas\" "
        "xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\" "
        "xmlns:o=\"urn:schemas-microsoft-com:office:office\" "
        "xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" "
        "xmlns:m=\"http://schemas.openxmlformats.org/officeDocument/2006/math\" "
        "xmlns:v=\"urn:schemas-microsoft-com:vml\" "
        "xmlns:wp14=\"http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing\" "
        "xmlns:wp=\"http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing\" "
        "xmlns:w10=\"urn:schemas-microsoft-com:office:word\" "
        "xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" "
        "xmlns:w14=\"http://schemas.microsoft.com/office/word/2010/wordml\" "
        "xmlns:wpg=\"http://schemas.microsoft.com/office/word/2010/wordprocessingGroup\" "
        "xmlns:wpi=\"http://schemas.microsoft.com/office/word/2010/wordprocessingInk\" "
        "xmlns:wne=\"http://schemas.microsoft.com/office/word/2006/wordml\" "
        "xmlns:wps=\"http://schemas.microsoft.com/office/word/2010/wordprocessingShape\" "
        "mc:Ignorable=\"w14 wp14\">"
        "<w:body>"
        + "".join(body)
        + sect
        + "</w:body></w:document>"
    )


STYLES_XML = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:eastAsia="宋体"/>
        <w:sz w:val="24"/>
      </w:rPr>
    </w:rPrDefault>
    <w:pPrDefault>
      <w:pPr>
        <w:spacing w:after="120" w:line="360" w:lineRule="auto"/>
      </w:pPr>
    </w:pPrDefault>
  </w:docDefaults>
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:qFormat/>
    <w:rPr>
      <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:eastAsia="宋体"/>
      <w:sz w:val="24"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Title">
    <w:name w:val="Title"/>
    <w:basedOn w:val="Normal"/>
    <w:qFormat/>
    <w:pPr>
      <w:jc w:val="center"/>
      <w:spacing w:after="240"/>
    </w:pPr>
    <w:rPr>
      <w:rFonts w:ascii="SimHei" w:hAnsi="SimHei" w:eastAsia="黑体"/>
      <w:b/>
      <w:sz w:val="36"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/>
    <w:basedOn w:val="Normal"/>
    <w:qFormat/>
    <w:pPr>
      <w:spacing w:before="240" w:after="180"/>
    </w:pPr>
    <w:rPr>
      <w:rFonts w:ascii="SimHei" w:hAnsi="SimHei" w:eastAsia="黑体"/>
      <w:b/>
      <w:sz w:val="32"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading2">
    <w:name w:val="heading 2"/>
    <w:basedOn w:val="Normal"/>
    <w:qFormat/>
    <w:pPr>
      <w:spacing w:before="180" w:after="120"/>
    </w:pPr>
    <w:rPr>
      <w:rFonts w:ascii="SimHei" w:hAnsi="SimHei" w:eastAsia="黑体"/>
      <w:b/>
      <w:sz w:val="28"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading3">
    <w:name w:val="heading 3"/>
    <w:basedOn w:val="Normal"/>
    <w:qFormat/>
    <w:pPr>
      <w:spacing w:before="120" w:after="120"/>
    </w:pPr>
    <w:rPr>
      <w:rFonts w:ascii="SimHei" w:hAnsi="SimHei" w:eastAsia="黑体"/>
      <w:b/>
      <w:sz w:val="24"/>
    </w:rPr>
  </w:style>
</w:styles>
"""


CONTENT_TYPES_XML = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>
"""


RELS_XML = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
"""


DOC_RELS_XML = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>
"""


def main() -> None:
    lines = MD_PATH.read_text(encoding="utf-8-sig").splitlines()
    blocks = parse_md(lines)
    document_xml = build_document(blocks)

    if TMP_DOCX_PATH.exists():
        TMP_DOCX_PATH.unlink()

    with zipfile.ZipFile(TMP_DOCX_PATH, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("[Content_Types].xml", CONTENT_TYPES_XML)
        zf.writestr("_rels/.rels", RELS_XML)
        zf.writestr("word/document.xml", document_xml)
        zf.writestr("word/styles.xml", STYLES_XML)
        zf.writestr("word/_rels/document.xml.rels", DOC_RELS_XML)

    if DOCX_PATH.exists():
        DOCX_PATH.unlink()
    TMP_DOCX_PATH.replace(DOCX_PATH)


if __name__ == "__main__":
    main()
