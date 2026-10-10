"""Generate the one-page OSC 2026 project proposal PDF."""

from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.cidfonts import UnicodeCIDFont
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    KeepTogether,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "output" / "pdf" / "MedSeal-MBT-project-proposal.pdf"
PURPLE = colors.HexColor("#6F46FF")
INK = colors.HexColor("#18212F")
MUTED = colors.HexColor("#5E6878")
PANEL = colors.HexColor("#F5F3FF")
GRID = colors.HexColor("#666666")
HEADER_BG = colors.HexColor("#E8E8E8")
LINK_BLUE = colors.HexColor("#0000EE")


def section(title: str, body: str, styles: dict[str, ParagraphStyle]):
    return KeepTogether(
        [
            Paragraph(title, styles["section"]),
            Spacer(1, 1.2 * mm),
            Paragraph(body, styles["body"]),
        ]
    )


def link(text: str, styles: dict[str, ParagraphStyle]):
    return Paragraph(
        f'<font color="#0000EE"><u>{text}</u></font>',
        styles["meta"],
    )


def cell(text: str, styles: dict[str, ParagraphStyle]):
    return Paragraph(text, styles["meta"])


def build() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    # Embed the local macOS CJK font when available, so readers do not need
    # a separate Adobe language pack. No standalone font file is distributed.
    songti = Path("/System/Library/Fonts/Supplemental/Songti.ttc")
    if songti.exists():
        font_name = "MedSealCJK"
        pdfmetrics.registerFont(TTFont(font_name, str(songti), subfontIndex=6))
    else:
        font_name = "STSong-Light"
        pdfmetrics.registerFont(UnicodeCIDFont(font_name))
    base = getSampleStyleSheet()
    styles = {
        "title": ParagraphStyle(
            "title",
            parent=base["Title"],
            fontName=font_name,
            fontSize=20,
            leading=24,
            textColor=PURPLE,
            alignment=TA_CENTER,
            spaceAfter=2 * mm,
        ),
        "subtitle": ParagraphStyle(
            "subtitle",
            parent=base["Normal"],
            fontName=font_name,
            fontSize=9.5,
            leading=13,
            textColor=MUTED,
            alignment=TA_CENTER,
        ),
        "section": ParagraphStyle(
            "section",
            parent=base["Heading2"],
            fontName=font_name,
            fontSize=11.5,
            leading=14,
            textColor=PURPLE,
            spaceBefore=2.6 * mm,
        ),
        "body": ParagraphStyle(
            "body",
            parent=base["BodyText"],
            fontName=font_name,
            fontSize=8.7,
            leading=12.5,
            textColor=INK,
            wordWrap="CJK",
        ),
        "meta": ParagraphStyle(
            "meta",
            parent=base["BodyText"],
            fontName=font_name,
            fontSize=8.1,
            leading=10.7,
            textColor=INK,
            wordWrap="CJK",
        ),
        "basic": ParagraphStyle(
            "basic",
            parent=base["Heading2"],
            fontName=font_name,
            fontSize=12.5,
            leading=15,
            textColor=INK,
            spaceAfter=1.8 * mm,
        ),
    }
    doc = SimpleDocTemplate(
        str(OUTPUT),
        pagesize=A4,
        leftMargin=15 * mm,
        rightMargin=15 * mm,
        topMargin=12 * mm,
        bottomMargin=12 * mm,
        title="MedSeal-MBT 项目申报书",
        author="001-Elsa",
        subject="2026 MoonBit 国产基础软件开源大赛项目申报",
    )
    story = [
        Paragraph("MedSeal-MBT 项目申报书", styles["title"]),
        Paragraph(
            "面向关联医学影像数据集的一致性脱敏与验证工具 · 0.2.0 候选版", styles["subtitle"]
        ),
        Spacer(1, 3.2 * mm),
    ]
    meta = [
        [cell("项目", styles), cell("内容", styles)],
        [cell("项目名称", styles), cell("MedSeal-MBT（关联医学影像数据集一致性脱敏与验证）", styles)],
        [cell("参赛者", styles), cell("韩枕", styles)],
        [cell("邮箱", styles), link("766903826@qq.com", styles)],
        [cell("手机号", styles), cell("17889572851", styles)],
        [cell("GitHub 仓库链接", styles), link("https://github.com/001-Elsa/MedSeal-MBT", styles)],
        [cell("Gitlink 仓库链接", styles), link("https://gitlink.org.cn/Hzhhhh/MedSeal-MBT", styles)],
        [cell("Mooncakes 包", styles), link("https://mooncakes.io/docs/001-Elsa/medseal", styles)],
        [cell("项目方向", styles), cell("MoonBit 医学影像开发工具 / 数据集转换与完整性验证", styles)],
        [cell("项目类型", styles), cell("围绕实际开发需求制作的开发工具（原创 MoonBit 项目）", styles)],
    ]
    table = Table(meta, colWidths=[45 * mm, 130 * mm])
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), HEADER_BG),
                ("TEXTCOLOR", (0, 0), (-1, -1), INK),
                ("FONTNAME", (0, 0), (-1, -1), font_name),
                ("FONTSIZE", (0, 0), (-1, -1), 8.1),
                ("LEADING", (0, 0), (-1, -1), 10.7),
                ("TEXTCOLOR", (0, 0), (-1, 0), INK),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("BOX", (0, 0), (-1, -1), 0.7, GRID),
                ("INNERGRID", (0, 0), (-1, -1), 0.55, GRID),
                ("LEFTPADDING", (0, 0), (-1, -1), 4),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4),
                ("TOPPADDING", (0, 0), (-1, -1), 3),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
            ]
        )
    )
    story.extend(
        [
            Paragraph("基本信息", styles["basic"]),
            table,
            section(
                "项目简介",
                "MedSeal-MBT 在原有 MoonBit DICOM 解析、校验与单文件清理工具上深化，面向同一患者的多影像、多检查和对象引用关系，实现数据集内一致的身份替换、UID 重映射与日期平移。输出包含新 DICOM 文件、无原值和原路径的动作审计，以及可独立复检的 SHA-256 清单。",
                styles,
            ),
            section(
                "项目方向与适用场景",
                "适用于科研样本准备、教学演示、医学影像软件联调与合成数据集处理。相比仅替换单文件患者字段，本项目重点保留数据集内部患者分组、Study/Series 层级、同患者对象引用和日期间隔，同时检查输入变化、输出结构与文件完整性。核心转换由 MoonBit 实现，可离线运行。",
                styles,
            ),
            section(
                "核心功能",
                "1. plan 两遍处理预检：有界读取、身份冲突、重复 SOP、跨患者引用与未知 UID 角色检查。<br/>2. batch 共享患者别名与分角色 UID 映射；每患者独立日期偏移，保留同患者日期间隔。<br/>3. research-v1 版本化策略；递归清理私有字段，重建 File Meta 并清零 preamble。<br/>4. 暂存后重解析，比较保留字段及 Pixel Data；复检输入快照后发布到全新输出目录。<br/>5. verify 核对 DICOM/审计哈希、输出文件集合与对象关系；保留原有单文件 CLI。",
                styles,
            ),
            section(
                "项目性质与开源合规",
                "延续原仓库与已发布 0.1.1，原创实现采用 Apache-2.0，依赖与样本来源有单独说明。pydicom 仅用于独立合成样本验证，不参与运行时转换。0.2.0 源码已按功能更新至 GitHub；CI 证据单独记录。原深化方案尚有未完成项，详见 PLAN_AUDIT.md；GitLink 同步与 Mooncakes 新版发布尚未执行。",
                styles,
            ),
            section(
                "质量与边界",
                "验证覆盖多后端自动化测试与 pydicom 独立互操作检查，包括 1,000 个合成对象、2 位患者、998 条引用。支持 Part 10 / Explicit VR Little Endian、ASCII/UTF-8 与 CT/MR/Secondary Capture 元数据子集；不宣称完整 IOD 或保密配置符合性。不检测像素内身份信息，不保证完全匿名化或法规合规；清单校验不提供数字签名。",
                styles,
            ),
            Spacer(1, 3 * mm),
            Paragraph(
                "联系方式：766903826@qq.com　|　Consistent DICOM collection de-identification and verification in MoonBit.",
                styles["subtitle"],
            ),
        ]
    )
    doc.build(story)
    print(OUTPUT)


if __name__ == "__main__":
    build()
