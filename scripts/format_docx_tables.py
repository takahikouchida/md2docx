#!/usr/bin/env python3
"""Adjust Word table geometry to the page and the amount of cell content."""

import sys
import unicodedata
import zipfile
from pathlib import Path
from tempfile import NamedTemporaryFile
from xml.etree import ElementTree as ET

W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
NS = {"w": W}
ET.register_namespace("w", W)


def qn(name: str) -> str:
    return f"{{{W}}}{name}"


def text_width(text: str) -> int:
    """Approximate rendered width; CJK/full-width glyphs count double."""
    return sum(2 if unicodedata.east_asian_width(c) in "WFA" else 1 for c in text)


def set_child(parent: ET.Element, tag: str, **attrs: str) -> ET.Element:
    child = parent.find(f"w:{tag}", NS)
    if child is None:
        child = ET.SubElement(parent, qn(tag))
    for key, value in attrs.items():
        child.set(qn(key), value)
    return child


def page_content_width(root: ET.Element) -> int:
    sect = root.find(".//w:sectPr", NS)
    if sect is None:
        return 9026  # A4 with ordinary margins
    size = sect.find("w:pgSz", NS)
    margin = sect.find("w:pgMar", NS)
    page = int(size.get(qn("w"), "11906")) if size is not None else 11906
    left = int(margin.get(qn("left"), "1440")) if margin is not None else 1440
    right = int(margin.get(qn("right"), "1440")) if margin is not None else 1440
    return max(4000, page - left - right)


def allocate_widths(scores: list[int], total: int) -> list[int]:
    count = len(scores)
    minimum = min(900, total // count)
    available = max(0, total - minimum * count)
    weight_total = sum(scores) or count
    widths = [minimum + round(available * score / weight_total) for score in scores]
    widths[-1] += total - sum(widths)
    return widths


def format_tables(document_xml: bytes) -> tuple[bytes, int]:
    root = ET.fromstring(document_xml)
    total_width = page_content_width(root)
    changed = 0

    for table in root.findall(".//w:tbl", NS):
        rows = table.findall("w:tr", NS)
        if not rows:
            continue
        cells_by_row = [row.findall("w:tc", NS) for row in rows]
        column_count = max(map(len, cells_by_row), default=0)
        if column_count == 0:
            continue

        scores = []
        for column in range(column_count):
            lengths = []
            for cells in cells_by_row:
                if column < len(cells):
                    text = "".join(cells[column].itertext()).strip()
                    lengths.append(text_width(text))
            # Cap long prose so one cell cannot consume almost the whole table.
            scores.append(max(4, min(40, max(lengths, default=4))))
        widths = allocate_widths(scores, total_width)

        properties = table.find("w:tblPr", NS)
        if properties is None:
            properties = ET.Element(qn("tblPr"))
            table.insert(0, properties)
        set_child(properties, "tblW", w=str(total_width), type="dxa")
        set_child(properties, "tblLayout", type="fixed")
        set_child(properties, "tblInd", w="0", type="dxa")
        margins = properties.find("w:tblCellMar", NS)
        if margins is None:
            margins = ET.SubElement(properties, qn("tblCellMar"))
        for side, value in (("top", "80"), ("left", "100"), ("bottom", "80"), ("right", "100")):
            set_child(margins, side, w=value, type="dxa")

        grid = table.find("w:tblGrid", NS)
        if grid is None:
            grid = ET.Element(qn("tblGrid"))
            table.insert(1, grid)
        for child in list(grid):
            grid.remove(child)
        for width in widths:
            ET.SubElement(grid, qn("gridCol"), {qn("w"): str(width)})

        for cells in cells_by_row:
            for index, cell in enumerate(cells):
                properties = cell.find("w:tcPr", NS)
                if properties is None:
                    properties = ET.Element(qn("tcPr"))
                    cell.insert(0, properties)
                set_child(properties, "tcW", w=str(widths[index]), type="dxa")
                set_child(properties, "vAlign", val="center")
        changed += 1

    return ET.tostring(root, encoding="utf-8", xml_declaration=True), changed


def main() -> None:
    path = Path(sys.argv[1])
    with zipfile.ZipFile(path, "r") as source:
        document, count = format_tables(source.read("word/document.xml"))
        with NamedTemporaryFile(dir=path.parent, suffix=".docx", delete=False) as tmp:
            temp_path = Path(tmp.name)
        with zipfile.ZipFile(temp_path, "w") as target:
            for item in source.infolist():
                data = document if item.filename == "word/document.xml" else source.read(item.filename)
                target.writestr(item, data)
    temp_path.replace(path)
    print(f"Tables resized: {count}")


if __name__ == "__main__":
    main()
